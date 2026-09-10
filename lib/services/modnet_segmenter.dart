import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// MODNet 发丝级抠图（hivision_modnet，HivisionIDPhotos 自训练，MIT）。
///
/// 常驻 worker isolate：spawn 一次，OrtEnv/Session 各建一次并复用，
/// 任务经 ReceivePort 串行处理——UI/动画全程不冻结，无每次推理
/// 重建 env/线程池的泄漏，也不存在并发双 isolate 抢内存。
/// （插件 runAsync 的裸指针机制曾致真机永久挂死；同步 run 冻结 UI。）
class ModnetSegmenter {
  ModnetSegmenter._();

  static const _modelAsset = 'assets/models/hivision_modnet.onnx';

  /// 模型固定输入 512×512（真机实证：非 512 报 invalid dimensions）
  static const inputSize = 512;

  static SendPort? _worker;
  static Future<SendPort>? _starting; // spawn memo：并发调用共享一次启动
  static int _seq = 0;
  static final _pending = <int, _Job>{};

  /// 对 [work] 图做人像分割，返回与 work 同尺寸的灰度掩码（0-255）。
  static Future<Uint8List> segment(img.Image work) => segmentRgba(
      Uint8List.fromList(work.getBytes(order: img.ChannelOrder.rgba)),
      work.width,
      work.height);

  /// 直接以 RGBA 缓冲区分割（流水线主路径）：避免主 isolate 再做一次
  /// `getBytes` 通道转换（1440² 图约 6MB 拷贝），RGB 抽取放到 worker 内完成。
  static Future<Uint8List> segmentRgba(Uint8List rgba, int w, int h) async {
    final worker = await _ensureWorker();
    final id = ++_seq;
    final job = _Job(id);
    _pending[id] = job;
    worker.send([id, w, h, TransferableTypedData.fromList([rgba])]);
    debugPrint('MODNet segment queued (${w}x$h)');
    return job.future;
  }

  /// 预热：提前 spawn worker、落盘 26MB 模型并建好 ONNX 会话。
  ///
  /// 首次分割的等待里有相当一部分是模型落盘 + session 构建（真机上可达
  /// 数秒）。在启动页空闲期预热后，用户进到处理页时模型已就绪，
  /// 体感等待时间大幅缩短。失败静默——真正处理时还会再试一次并给出提示。
  static Future<void> warmUp() async {
    try {
      await _ensureWorker();
    } catch (e) {
      debugPrint('MODNet warmUp failed (will retry on demand): $e');
    }
  }

  static Future<SendPort> _ensureWorker() {
    final existing = _worker;
    if (existing != null) return Future.value(existing);
    // 失败即清（modelFile 异常/session 失败都不能缓存失败的 Future，
    // 否则变成永久闭锁）
    return _starting ??= _spawnWorker().catchError((Object e) {
      _starting = null;
      throw e;
    });
  }

  static Future<SendPort> _spawnWorker() async {
    final ready = ReceivePort();
    final replies = ReceivePort();
    final modelPath = await _ensureModelFile();
    await Isolate.spawn(_workerMain, [ready.sendPort, replies.sendPort, modelPath]);
    // 第一条消息 = SendPort 或 ['err', msg]（worker 初始化失败）
    final first = await ready.first
        .timeout(const Duration(seconds: 30), onTimeout: () => ['err', 'worker init timeout']);
    if (first is List) {
      throw StateError('MODNet worker init failed: ${first[1]}');
    }
    _worker = first as SendPort;
    replies.listen((msg) {
      final list = msg as List;
      final job = _pending.remove(list[0] as int);
      if (job == null) return;
      if (list[1] is String) {
        job.completeError(StateError(list[1] as String));
      } else {
        final data = list[1] as TransferableTypedData;
        job.complete(data.materialize().asUint8List());
      }
    });
    return _worker!;
  }

  /// 模型落盘（幂等）：asset → 应用文档目录，供 worker isolate 按路径建会话。
  static Future<String> _ensureModelFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'hivision_modnet.onnx'));
    if (!await file.exists() || await file.length() < 1024 * 1024) {
      final model = await rootBundle.load(_modelAsset);
      await file.writeAsBytes(model.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  /// worker isolate 主循环：建会话一次，串行处理分割任务。
  /// 初始化失败回传 ['err', msg]——否则主 isolate 会死等 ready.first。
  static void _workerMain(List<dynamic> init) {
    final readyToMain = init[0] as SendPort;
    final replyToMain = init[1] as SendPort;
    final modelPath = init[2] as String;

    late final OrtSession session;
    late final String inputName;
    try {
      OrtEnv.instance.init();
      session = OrtSession.fromFile(File(modelPath), OrtSessionOptions());
      inputName = session.inputNames.first;
    } catch (e) {
      readyToMain.send(['err', '$e']);
      return;
    }

    final tasks = ReceivePort();
    readyToMain.send(tasks.sendPort);

    tasks.listen((msg) {
      final list = msg as List;
      final id = list[0] as int;
      try {
        final mask = _infer(
            session, inputName, list[1] as int, list[2] as int,
            (list[3] as TransferableTypedData).materialize().asUint8List());
        replyToMain.send([id, TransferableTypedData.fromList([mask])]);
      } catch (e) {
        replyToMain.send([id, '$e']);
      }
    });
  }

  /// 预处理 → 推理 → work 尺寸灰度掩码（全在 worker isolate 内）。
  /// 输入为 RGBA 缓冲区，直接按 512×512 双线性重采样进模型，
  /// 省掉一次全尺寸 Image 构造与通道转换。
  static Uint8List _infer(
      OrtSession session, String inputName, int w, int h, Uint8List rgba) {
    const size = inputSize;
    final plane = size * size;

    // RGBA → 512×512 CHW float，归一化到 [-1,1]（双线性，无中间 Image 分配）
    final input = Float32List(3 * plane);
    final sx = w / size, sy = h / size;
    for (var y = 0; y < size; y++) {
      final fy = ((y + 0.5) * sy - 0.5).clamp(0.0, h - 1.0);
      final y0 = fy.floor();
      final y1 = y0 + 1 < h ? y0 + 1 : h - 1;
      final ay = fy - y0;
      for (var x = 0; x < size; x++) {
        final fx = ((x + 0.5) * sx - 0.5).clamp(0.0, w - 1.0);
        final x0 = fx.floor();
        final x1 = x0 + 1 < w ? x0 + 1 : w - 1;
        final ax = fx - x0;
        final i00 = (y0 * w + x0) * 4,
            i10 = (y0 * w + x1) * 4,
            i01 = (y1 * w + x0) * 4,
            i11 = (y1 * w + x1) * 4;
        final o = y * size + x;
        for (var c = 0; c < 3; c++) {
          final top = rgba[i00 + c] + (rgba[i10 + c] - rgba[i00 + c]) * ax;
          final bot = rgba[i01 + c] + (rgba[i11 + c] - rgba[i01 + c]) * ax;
          input[c * plane + o] = (top + (bot - top) * ay) / 255.0 * 2 - 1;
        }
      }
    }

    final inputOrt =
        OrtValueTensor.createTensorWithDataList(input, [1, 3, size, size]);
    List<OrtValue?> outputs;
    try {
      outputs = session.run(OrtRunOptions(), {inputName: inputOrt});
    } finally {
      inputOrt.release();
    }

    final outOrt = outputs.first as OrtValueTensor;
    final flat = Float32List(plane);
    var idx = 0;
    void walk(dynamic v) {
      if (v is List) {
        for (final e in v) {
          walk(e);
        }
      } else if (idx < plane) {
        flat[idx++] = (v as num).toDouble();
      }
    }

    walk(outOrt.value);
    outOrt.release();

    final maskBytes = Uint8List(plane);
    for (var i = 0; i < plane; i++) {
      maskBytes[i] = (flat[i].clamp(0.0, 1.0) * 255).round();
    }
    var maskImg = img.Image.fromBytes(
        width: size, height: size, bytes: maskBytes.buffer, numChannels: 1);
    if (maskImg.width != w || maskImg.height != h) {
      maskImg = img.copyResize(maskImg,
          width: w, height: h, interpolation: img.Interpolation.linear);
    }
    return maskImg.getBytes();
  }
}

class _Job {
  _Job(this.id);

  final int id;
  final _completer = Completer<Uint8List>();

  Future<Uint8List> get future => _completer.future;

  void complete(Uint8List v) => _completer.complete(v);

  void completeError(Object e) => _completer.completeError(e);
}
