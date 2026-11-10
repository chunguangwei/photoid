import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import 'gemma_tokenizer.dart';

/// 图像预处理/patch 展开的固定几何（image_processor 实测：resize 320×224 +
/// rescale 1/255、无 normalize、RGB；14×20=280 patch，patch=16，
/// 每 patch 16×16×3=768，行主序、patch 内像素行主序、通道交织）。
const kEmbImgWidth = 320;
const kEmbImgHeight = 224;
const kEmbPatchSize = 16;
const kEmbCols = kEmbImgWidth ~/ kEmbPatchSize; // 20
const kEmbRows = kEmbImgHeight ~/ kEmbPatchSize; // 14
const kEmbNumPatches = kEmbRows * kEmbCols; // 280
const kEmbPatchDim = kEmbPatchSize * kEmbPatchSize * 3; // 768

/// RGB 像素（行主序）→ 视觉塔 `pixel_values` [1,280,768] 的扁平布局。
///
/// [rgb] 必须恰为 `kEmbNumPatches * kEmbPatchDim`（=215040）字节：
/// 320×224 的 RGB 字节按行主序（一个像素 R,G,B 连续，同行下一像素，
/// 行末进下一行）。输出第 `row*kEmbCols+col` 个 patch 段依次装该
/// 16×16 区域逐像素的 R,G,B（把 stride-3 交织字节按 64 像素重排成
/// 连续 768 段，像素值本身不缩放——/255 在调用前完成）。
Float32List embeddingPatchLayout(Uint8List rgb) {
  if (rgb.length != kEmbNumPatches * kEmbPatchDim) {
    throw ArgumentError.value(
        rgb.length, 'rgb', 'expected ${kEmbNumPatches * kEmbPatchDim} bytes');
  }
  final out = Float32List(kEmbNumPatches * kEmbPatchDim);
  for (var imageRow = 0; imageRow < kEmbImgHeight; imageRow++) {
    final patchRow = imageRow ~/ kEmbPatchSize;
    final dotRow = imageRow % kEmbPatchSize;
    final srcRowBase = imageRow * kEmbImgWidth * 3;
    for (var imageCol = 0; imageCol < kEmbImgWidth; imageCol++) {
      final patchCol = imageCol ~/ kEmbPatchSize;
      final dotCol = imageCol % kEmbPatchSize;
      final patchBase = (patchRow * kEmbCols + patchCol) * kEmbPatchDim +
          (dotRow * kEmbPatchSize + dotCol) * 3;
      final src = srcRowBase + imageCol * 3;
      out[patchBase] = rgb[src].toDouble();
      out[patchBase + 1] = rgb[src + 1].toDouble();
      out[patchBase + 2] = rgb[src + 2].toDouble();
    }
  }
  return out;
}

/// 视觉塔 `pixel_position_ids` [1,280,2] 的扁平布局：patch i 的 (row, col)。
/// 行主序：pid[2*i]=i~/kEmbCols，pid[2*i+1]=i%kEmbCols（与真机冒烟一致）。
Int64List embeddingPatchPositionIds() {
  final pid = Int64List(kEmbNumPatches * 2);
  for (var i = 0; i < kEmbNumPatches; i++) {
    pid[2 * i] = i ~/ kEmbCols;
    pid[2 * i + 1] = i % kEmbCols;
  }
  return pid;
}

/// EmbeddingGemma 2 加强版推理会话（文本嵌入 + 图片嵌入）。
///
/// 常驻 worker isolate：spawn 一次，OrtEnv 只 init 一次，双 OrtSession
/// （文本塔 model_q4f16 + 视觉塔 vision_encoder_q4f16）与分词器建一次并
/// 复用；请求经 ReceivePort 串行处理（模式仿 modnet_segmenter.dart——
/// 插件 runAsync 裸指针曾致真机挂死，同步 run 冻结 UI）。
///
/// 张量一律 Float32List/Int64List typed data（普通 `List<double>` 会报
/// tensor(double) 类型错）；文本塔 image/video/audio_features 融合输入
/// 必传，非模态传空 [0,512]；图片走单 `<|image|>` 占位
/// `input_ids=[2,4642,258880,1]` + attention_mask 全 1 + image_features
/// n×512（视觉塔把 280 patch 聚合约 29 个 token）。
/// `sentence_embedding`（第 2 输出）已 L2 归一化，本类兜底再归一一次。
class EmbeddingSession {
  EmbeddingSession._(this._worker);

  final SendPort _worker;
  bool _disposed = false;

  static const _textModelFile = 'model_q4f16.onnx';
  static const _visionModelFile = 'vision_encoder_q4f16.onnx';
  static const _tokenizerFile = 'tokenizer.json';

  /// 文本塔图片模板：`<bos>` + n×`<|image|>`（258880，与 image_features
  /// 行数一致）+ `<eos>`。桌面排序对拍：n 占位 8/8 top-1（margin
  /// .008–.038）vs 单占位 3/8——单占位只消费 1 行特征，其余 28 patch
  /// 聚合 token 被丢弃。
  static List<int> imageInputIds(int rows) =>
      [2, ...List.filled(rows, 258880), 1];

  static final ReceivePort _replies = ReceivePort()
    ..listen((message) {
      final list = message as List;
      final id = list[0] as int;
      final job = _pending.remove(id);
      if (job == null) return;
      if (id == -1) {
        // dispose 应答（worker 已收尾）
        job.complete(const []);
        return;
      }
      final result = list[1];
      if (result is String) {
        job.completeError(StateError(result));
      } else if (result is TransferableTypedData) {
        job.complete(result.materialize().asFloat32List());
      } else {
        job.completeError(StateError('unexpected reply: $result'));
      }
    });
  static final _pending = <int, Completer<List<double>>>{};
  static int _seq = 0;

  /// 打开会话：spawn worker，在 worker 内加载分词器 + 双 OrtSession。
  ///
  /// [modelDir] 为 EmbeddingModelStore 的模型目录（basename 落盘：
  /// 两张 .onnx 与**同名** .onnx_data 必须同目录——ORT 外部数据按
  /// 图内相对文件名解析；另含 tokenizer.json）。初始化失败抛
  /// [StateError]（失败不缓存，可重新 open）。
  static Future<EmbeddingSession> open(String modelDir) async {
    final ready = ReceivePort();
    await Isolate.spawn(
        _workerMain, [ready.sendPort, _replies.sendPort, modelDir]);
    // 首条消息 = worker 的 SendPort，或 ['err', msg]（初始化失败）。
    // 32MB 分词器 + 双会话冷建给 120s 余量。
    final first = await ready.first.timeout(
        const Duration(seconds: 120),
        onTimeout: () => <Object>['err', 'embedding worker init timeout']);
    ready.close();
    if (first is List) {
      throw StateError('EmbeddingSession worker init failed: ${first[1]}');
    }
    return EmbeddingSession._(first as SendPort);
  }

  /// 文本 → 768 维 L2 归一向量（走 model_q4f16 文本塔；
  /// image/video/audio_features 传空 [0,512]）。
  Future<List<double>> embedText(String text) =>
      _request(0, utf8.encode(text));

  /// jpg/png 字节 → 768 维 L2 归一向量。
  ///
  /// 解码用 image 包；HEIC 无纯 Dart 解码器，解不了抛 [ArgumentError]
  /// （上层应回退基础检测流程，勿当致命错误）。预处理严格按
  /// image_processor：resize 320×224（双线性）→ /255（无 normalize）→
  /// patch [1,280,768] + position ids [1,280,2] → 视觉塔 → n×512 →
  /// 文本塔单图占位融合，取 sentence_embedding。
  Future<List<double>> embedImageBytes(Uint8List bytes) => _request(1, bytes);

  /// 加强版查询前缀（官方非对称检索文案，仅文本侧使用；图片不加）。
  static String queryText(String q) => 'task: search result | query: $q';

  /// 关闭会话：结束 worker isolate。主 isolate 进程内的 OrtEnv 在
  /// worker 里，随 worker 退出释放。dispose 后本实例不可再用。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final done = Completer<List<double>>();
    _pending[-1] = done;
    _worker.send([-1]);
    await done.future
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);
  }

  Future<List<double>> _request(int kind, Uint8List payload) {
    if (_disposed) throw StateError('EmbeddingSession already disposed');
    final id = ++_seq;
    final job = Completer<List<double>>();
    _pending[id] = job;
    _worker.send([
      id,
      kind,
      TransferableTypedData.fromList([payload]),
    ]);
    return job.future;
  }

  /// worker isolate 主循环：env/分词器/双会话各建一次，串行处理请求。
  /// 初始化失败回传 ['err', msg]——否则主 isolate 会死等 ready.first。
  static void _workerMain(List<dynamic> init) {
    final readyToMain = init[0] as SendPort;
    final replyToMain = init[1] as SendPort;
    final modelDir = init[2] as String;

    late final GemmaTokenizer tokenizer;
    late final OrtSession vision;
    late final OrtSession text;
    try {
      OrtEnv.instance.init();
      tokenizer = GemmaTokenizer.fromJsonFile('$modelDir/$_tokenizerFile');
      final opts = OrtSessionOptions();
      vision = OrtSession.fromFile(File('$modelDir/$_visionModelFile'), opts);
      text = OrtSession.fromFile(File('$modelDir/$_textModelFile'), opts);
    } catch (e) {
      readyToMain.send(['err', '$e']);
      return;
    }

    final tasks = ReceivePort();
    readyToMain.send(tasks.sendPort);

    tasks.listen((msg) {
      final list = msg as List;
      final id = list[0] as int;
      if (id == -1) {
        // dispose：会话不再复用，释放后结束 worker（isolate 自然退出）。
        replyToMain.send([-1, '']);
        tasks.close();
        vision.release();
        text.release();
        OrtEnv.instance.release();
        return;
      }
      try {
        final kind = list[1] as int;
        final bytes =
            (list[2] as TransferableTypedData).materialize().asUint8List();
        final vector = kind == 0
            ? _embedTextSync(tokenizer, text, bytes)
            : _embedImageSync(vision, text, bytes);
        replyToMain.send([
          id,
          TransferableTypedData.fromList([Float32List.fromList(vector)])
        ]);
      } catch (e, s) {
        replyToMain.send([id, '$e\n$s']);
      }
    });
  }

  /// 文本塔通用调用：tokens + 全 1 mask + 三路模态特征（未用的传空
  /// [0,512]）。输入张量在返回前统一释放；输出释放后仍返回拷贝值。
  static List<double> _runTextTower(OrtSession text, List<int> tokens,
      Float32List imageFeatures, int imageRows) {
    final ids = Int64List(tokens.length);
    for (var i = 0; i < tokens.length; i++) {
      ids[i] = tokens[i];
    }
    final mask = Int64List(tokens.length)..fillRange(0, tokens.length, 1);
    final idsV =
        OrtValueTensor.createTensorWithDataList(ids, [1, tokens.length]);
    final maskV =
        OrtValueTensor.createTensorWithDataList(mask, [1, tokens.length]);
    final imgV = imageRows > 0
        ? OrtValueTensor.createTensorWithDataList(
            imageFeatures, [imageRows, 512])
        : OrtValueTensor.createTensorWithDataList(Float32List(0), [0, 512]);
    final emptyVideo =
        OrtValueTensor.createTensorWithDataList(Float32List(0), [0, 512]);
    final emptyAudio =
        OrtValueTensor.createTensorWithDataList(Float32List(0), [0, 512]);
    final out = text.run(OrtRunOptions(), {
      'input_ids': idsV,
      'attention_mask': maskV,
      'image_features': imgV,
      'video_features': emptyVideo,
      'audio_features': emptyAudio,
    });
    try {
      // sentence_embedding：图契约的稳定第二输出（冒烟按 out[1] 取值）。
      final emb = (out[1]! as OrtValueTensor).value as List;
      final row = (emb.first as List).cast<num>();
      if (row.length != 768) {
        throw StateError('sentence_embedding length ${row.length} != 768');
      }
      return _l2Normalize(List<double>.generate(768, (i) => row[i].toDouble()));
    } finally {
      idsV.release();
      maskV.release();
      imgV.release();
      emptyVideo.release();
      emptyAudio.release();
      for (final o in out) {
        o?.release();
      }
    }
  }

  static List<double> _embedTextSync(
      GemmaTokenizer tokenizer, OrtSession text, Uint8List utf8Bytes) {
    final tokens = tokenizer.encode(utf8.decode(utf8Bytes));
    return _runTextTower(text, tokens, Float32List(0), 0);
  }

  static List<double> _embedImageSync(
      OrtSession vision, OrtSession text, Uint8List encoded) {
    final decoded = img.decodeImage(encoded);
    if (decoded == null) {
      // HEIC 等 image 包不支持的格式：抛 ArgumentError，上层走基础检测兜底。
      throw ArgumentError(
          'undecodable image bytes (HEIC has no pure-Dart decoder; caller '
          'should fall back to basic detection)');
    }
    // image_processor：仅 resize 320×224 + /255（mean 0/std 1，无 normalize）。
    final resized =
        decoded.width == kEmbImgWidth && decoded.height == kEmbImgHeight
            ? decoded
            : img.copyResize(decoded,
                width: kEmbImgWidth,
                height: kEmbImgHeight,
                interpolation: img.Interpolation.linear);
    // getBytes(order: rgb)：行主序 R,G,B 交织（丢弃 alpha，恰 w*h*3 字节）。
    final rgb = resized.getBytes(order: img.ChannelOrder.rgb);
    // 布局重排后 /255 归一（与 HF do_rescale=1/255 等价）。
    final pixels = _rescalePatches(embeddingPatchLayout(rgb));
    final pid = embeddingPatchPositionIds();

    final pxV = OrtValueTensor.createTensorWithDataList(
        pixels, [1, kEmbNumPatches, kEmbPatchDim]);
    final pidV = OrtValueTensor.createTensorWithDataList(
        pid, [1, kEmbNumPatches, 2]);
    try {
      final featsOrt =
          (vision.run(OrtRunOptions(), {
            'pixel_values': pxV,
            'pixel_position_ids': pidV
          })[0]! as OrtValueTensor);
      final feats = featsOrt.value as List;
      featsOrt.release(); // value 已是深拷贝的嵌套 Dart List，原生侧即刻释放
      // 视觉塔把 280 patch 聚合为约 29 个 512 维 token。
      final n = feats.length;
      final rows = Float32List(n * 512);
      for (var row = 0; row < n; row++) {
        final r = (feats[row] as List).cast<num>();
        for (var c = 0; c < 512; c++) {
          rows[row * 512 + c] = r[c].toDouble();
        }
      }
      if (!rows.every((e) => e.isFinite)) {
        throw StateError('vision encoder produced non-finite features');
      }
      // n 占位融合（与特征行数一致；单占位丢特征，桌面 8/8 vs 3/8 实证）。
      return _runTextTower(text, imageInputIds(n), rows, n);
    } finally {
      pxV.release();
      pidV.release();
    }
  }

  /// uint8 0-255 → float 0-1（image_processor do_rescale=1/255）。
  static Float32List _rescalePatches(Float32List raw) {
    for (var i = 0; i < raw.length; i++) {
      raw[i] = raw[i] / 255.0;
    }
    return raw;
  }

  /// 兜底 L2 归一（sentence_embedding 自带归一，量化边缘再归一无副作用）。
  static List<double> _l2Normalize(List<double> v) {
    var norm = 0.0;
    for (final e in v) {
      norm += e * e;
    }
    norm = math.sqrt(norm);
    if (norm == 0 || !norm.isFinite) return v;
    return [for (final e in v) e / norm];
  }
}
