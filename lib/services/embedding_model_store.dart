import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 模型文件清单条目。[name] 为 HF 仓库内路径（URL 后缀 + 清单名），
/// 本地一律以 basename 落盘——ORT 外部数据要求 `model_q4f16.onnx_data`
/// 与 `model_q4f16.onnx` 同名同目录，不能保留 `onnx/` 前缀。
class EmbeddingFileSpec {
  const EmbeddingFileSpec(this.name, this.bytes, this.sha256);

  /// 清单名（仓库内路径，如 `onnx/model_q4f16.onnx`）。
  final String name;

  /// 期望字节数（存在性快速校验用，状态检查不做哈希）。
  final int bytes;

  /// 期望 SHA-256（hex 小写；只在下载完成时全量校验）。
  final String sha256;

  /// 本地文件名（basename）。
  String get localName => p.basename(name);
}

/// 模型安装状态。
enum EmbeddingModelStatus {
  /// 目录内无任何清单文件/断点。
  notInstalled,

  /// 部分完成：有文件下齐或有 `.part` 断点，可续传。
  partial,

  /// 正在下载（本实例发起的传输进行中）。
  downloading,

  /// 就绪：清单文件全部存在且大小匹配（启动快速校验信任大小，
  /// SHA 全量校验只在下载完成/重下时做，status 不做大文件哈希）。
  ready,

  /// 损坏：某清单文件存在但大小与清单不符。
  corrupt,
}

/// 下载进度。[receivedBytes] 为全部清单文件**累计**值（含已完成文件），
/// UI 直接用它除以 [totalBytes] 画总进度条。
class EmbeddingModelProgress {
  const EmbeddingModelProgress({
    required this.receivedBytes,
    required this.totalBytes,
    this.activeFile,
  });

  final int receivedBytes;
  final int totalBytes;

  /// 当前正在下载的文件（本地名）；无进行中传输时为 null。
  final String? activeFile;
}

/// 「仅 Wi-Fi 下载」开启但当前非 Wi-Fi 时的专用异常：与状态类错误
/// （StateError）区分，UI 按本类型精确捕获并提示，不误报。
class EmbeddingWifiRequired implements Exception {
  const EmbeddingWifiRequired();

  @override
  String toString() => 'EmbeddingWifiRequired()';
}

/// SHA-256 分块消费的收尾 sink：close 时不抛（DigestSink 会重复关闭抛错）。
class _DigestCapture implements Sink<Digest> {
  String? value;
  @override
  void add(Digest data) => value = data.toString();
  @override
  void close() {}
}

/// EmbeddingGemma q4f16 模型（约 287MB，5 文件）的下载/校验/状态管理。
///
/// 断点续传：`.part` 临时文件 + HTTP Range 续传；逐文件 SHA-256 校验通过后
/// 原子 rename 发布（沿用 ApplicationTaskStore 的临时文件+rename 风格）；
/// 任何文件失败自动换下一源，一次会话记住可用源；全部源失败抛最后一次
/// 异常并保留进度，用户可稍后继续。执行下载来的数据，不执行下载来的代码。
class EmbeddingModelStore {
  EmbeddingModelStore._(this._root, this._manifest, this._sources);

  /// 文档目录下固定子目录名。
  static const String directoryName = 'embedding_model';

  /// 官方清单（onnx-community/embeddinggemma-2-ONNX @ main，2026-11-10
  /// 实测：hf-mirror / huggingface / modelscope 三源 X-Linked-Etag 一致，
  /// 即 SHA-256 跨源可信）。
  static const List<EmbeddingFileSpec> defaultManifest = [
    EmbeddingFileSpec('onnx/model_q4f16.onnx', 495298,
        '53feeced79582d661e30adeaa9829cea90d92b1c78347e26fd123773580f71d0'),
    EmbeddingFileSpec('onnx/model_q4f16.onnx_data', 156862464,
        'c39fbaa1fb4221f04beb82786a06b81999c514fd39e84fcd58ef79413c87fa56'),
    EmbeddingFileSpec('onnx/vision_encoder_q4f16.onnx', 150693,
        '55975fba53928162eee37e9eea2a69965c10c0411ed14c24ea149efa55a8aa68'),
    EmbeddingFileSpec('onnx/vision_encoder_q4f16.onnx_data', 97614336,
        '842f996aff092e300c966266ae0cc60771c6ca16282fee04ca83f0f159bc6b33'),
    EmbeddingFileSpec('tokenizer.json', 32170510,
        '4d777ef5bdc1aa36227abdfb77c3e49e7b9c892d16e1b6bda41c393504828be4'),
  ];

  /// 源站模板：`{path}` 占位符替换为清单名。顺序即优先级（国内镜像优先，
  /// 沿用 UpdateService 的镜像回退语义）。ModelScope 于 2026-11-10 实测
  /// `resolve/master/<path>` 返回 200 且 X-Linked-Etag 与 SHA-256 一致，
  /// 纳入候选；其用 master 分支名（非 main）。
  static const List<String> defaultSources = [
    'https://hf-mirror.com/onnx-community/embeddinggemma-2-ONNX/resolve/main/{path}',
    'https://huggingface.co/onnx-community/embeddinggemma-2-ONNX/resolve/main/{path}',
    'https://modelscope.cn/models/onnx-community/embeddinggemma-2-ONNX/resolve/master/{path}',
  ];

  final Directory _root;
  final List<EmbeddingFileSpec> _manifest;
  final List<String> _sources;

  bool _downloading = false;
  bool _paused = false;

  /// 一次会话记住可用源：上次成功的源优先尝试。
  int? _preferredSource;

  /// 进行中的客户端（pause 时 close 即中止传输，package:http 的取消方式）。
  http.Client? _activeClient;

  static final Map<String, Future<void>> _pending = {};

  /// 打开（不触发任何网络/哈希操作）。[root] 默认 `<documents>/embedding_model`；
  /// [manifest]/[sources] 可注入（测试用合成清单 + loopback 假源）。
  static Future<EmbeddingModelStore> open(
      {Directory? root,
      List<EmbeddingFileSpec>? manifest,
      List<String>? sources}) async {
    final dir = root ??
        Directory(p.join((await getApplicationDocumentsDirectory()).path,
            directoryName));
    await dir.create(recursive: true);
    return EmbeddingModelStore._(
        dir, manifest ?? defaultManifest, sources ?? defaultSources);
  }

  /// 模型落盘目录绝对路径（EmbeddingSession.open 直接消费）。
  String get directoryPath => p.absolute(_root.path);

  /// 清单总字节数（常量）。
  int get totalBytes => _manifest.fold(0, (a, s) => a + s.bytes);

  /// 已落盘清单文件的实际字节合计（损坏文件按实际大小计）。
  int get installedBytes => _manifest.fold(0, (a, s) {
        final f = file(s.name);
        return a + (f.existsSync() ? f.lengthSync() : 0);
      });

  /// 快速状态检查：只查存在性 + 大小，不对大文件做哈希。
  EmbeddingModelStatus get status {
    if (_downloading) return EmbeddingModelStatus.downloading;
    var complete = 0;
    var hasPart = false;
    for (final s in _manifest) {
      final f = file(s.name);
      if (f.existsSync()) {
        if (f.lengthSync() != s.bytes) return EmbeddingModelStatus.corrupt;
        complete++;
      } else if (File('${f.path}.part').existsSync()) {
        hasPart = true;
      }
    }
    if (complete == _manifest.length) return EmbeddingModelStatus.ready;
    if (complete > 0 || hasPart) return EmbeddingModelStatus.partial;
    return EmbeddingModelStatus.notInstalled;
  }

  /// 清单内文件的落盘位置；[name] 接受清单名或 basename，清单外抛错。
  File file(String name) {
    for (final s in _manifest) {
      if (s.name == name || s.localName == name) {
        return File(p.join(_root.path, s.localName));
      }
    }
    throw ArgumentError('Not in model manifest: $name');
  }

  /// 开始/继续下载（[status] 为 ready 时直接返回）。
  ///
  /// 断点续传：`.part` + Range；逐文件 SHA-256 校验通过后原子 rename；
  /// 任何文件失败换下一源；全部源失败抛最后一次异常且保留进度。
  ///
  /// [wifiOnly] 为文档性参数：仓库无 connectivity_plus 依赖且不为它加依赖，
  /// 端上无法判定网络类型——Wi-Fi 开关由 UI 持久化偏好，网络不可用时按
  /// 现有失败路径（本方法抛异常）处理。若将来接入网络类型判定，非 Wi-Fi
  /// 时抛 [EmbeddingWifiRequired]（UI 已按该类型捕获）。
  Future<void> startDownload({
    void Function(EmbeddingModelProgress)? onProgress,
    bool wifiOnly = false,
  }) async {
    if (_downloading) return; // 幂等：不并行发起第二个传输
    _downloading = true;
    _paused = false;
    try {
      for (final s in _manifest) {
        if (_paused) return;
        Object? lastError;
        for (final idx in _sourceOrder()) {
          if (_paused) return;
          try {
            await _fetchFile(s, idx, onProgress);
            _preferredSource = idx;
            lastError = null;
            break;
          } catch (e) {
            if (_paused) return; // 暂停导致的 abort：正常收尾
            lastError = e; // 换源重试，进度（.part）保留
          }
        }
        if (lastError != null) throw lastError;
      }
    } finally {
      _downloading = false;
      _activeClient = null;
    }
  }

  /// 取消进行中的传输，保留 `.part` 断点（startDownload 正常返回）。
  Future<void> pauseDownload() async {
    if (!_downloading) return;
    _paused = true;
    // package:http 无 abort API：close 即中止在途请求（流报 RequestAborted）
    _activeClient?.close();
  }

  /// 删除全部模型文件与断点（先暂停进行中的传输）。
  Future<void> delete() async {
    await pauseDownload();
    await _serial(() async {
      for (final s in _manifest) {
        final f = file(s.name);
        if (f.existsSync()) await f.delete();
        final part = File('${f.path}.part');
        if (part.existsSync()) await part.delete();
      }
    });
  }

  /// 源尝试顺序：上次成功的源优先（一次会话记住可用源）。
  List<int> _sourceOrder() {
    final all = List.generate(_sources.length, (i) => i);
    final pref = _preferredSource;
    if (pref == null || pref >= _sources.length) return all;
    return [pref, ...all.where((i) => i != pref)];
  }

  /// 单个文件的下载（含断点续传/SHA 校验/原子发布），失败抛异常换源。
  Future<void> _fetchFile(EmbeddingFileSpec spec, int sourceIdx,
      void Function(EmbeddingModelProgress)? onProgress) async {
    final target = file(spec.name);
    final part = File('${target.path}.part');
    // 大小匹配的既有文件在此处（下载完成路径）做一次全量 SHA：
    // 不过就整文件重下；status getter 永不做这一步。
    if (target.existsSync()) {
      if (target.lengthSync() == spec.bytes &&
          await _shaOf(target) == spec.sha256) {
        return;
      }
      await target.delete();
    }
    var base = part.existsSync() ? part.lengthSync() : 0;
    if (base > spec.bytes) {
      await part.delete();
      base = 0;
    }
    if (base == spec.bytes) {
      if (await _shaOf(part) == spec.sha256) {
        await _serial(() => part.rename(target.path));
        return;
      }
      await part.delete();
      base = 0;
    }
    final url = _sources[sourceIdx].replaceAll('{path}', spec.name);
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      if (base > 0) req.headers['Range'] = 'bytes=$base-';
      _activeClient = client;
      final resp =
          await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await resp.stream.drain<void>();
        await part.delete(); // 断点失效，下次整文件重来
        throw FormatException('Range not satisfiable: $url');
      }
      if (resp.statusCode != HttpStatus.partialContent &&
          resp.statusCode != HttpStatus.ok) {
        await resp.stream.drain<void>();
        throw FormatException('HTTP ${resp.statusCode}: $url');
      }
      // 200 = 源不支持 Range：截断 .part 从头收
      final append = resp.statusCode == HttpStatus.partialContent;
      if (!append) base = 0;
      final received = [base];
      void emit() => onProgress?.call(EmbeddingModelProgress(
            receivedBytes: _completedBytes + received[0],
            totalBytes: totalBytes,
            activeFile: spec.localName,
          ));
      emit();
      final raf = await part
          .open(mode: append ? FileMode.append : FileMode.write);
      try {
        try {
          await for (final chunk in resp.stream) {
            if (_paused) break;
            await raf.writeFrom(chunk);
            received[0] += chunk.length;
            emit();
          }
        } catch (_) {
          if (!_paused) rethrow; // 断流：保留 .part，换源后 Range 续传
        }
      } finally {
        await raf.close();
      }
      if (_paused) return;
      if (received[0] != spec.bytes) {
        throw FormatException(
            'Incomplete download (${received[0]}/${spec.bytes}): $url');
      }
      if (await _shaOf(part) != spec.sha256) {
        await part.delete(); // 内容不可信，下一源整文件重下
        throw FormatException('SHA-256 mismatch: ${spec.name} from $url');
      }
      await _serial(() => part.rename(target.path)); // 原子发布
      // 完成后改名使 _completedBytes 已含本文件，直接取累计值，避免重复计
      onProgress?.call(EmbeddingModelProgress(
          receivedBytes: _completedBytes, totalBytes: totalBytes));
    } catch (_) {
      if (_paused) return;
      rethrow;
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      client.close();
    }
  }

  /// 已下齐文件的期望字节合计（进度基准）。
  int get _completedBytes => _manifest.fold(0, (a, s) {
        final f = file(s.name);
        return a +
            (f.existsSync() && f.lengthSync() == s.bytes ? s.bytes : 0);
      });

  /// 分块 SHA-256（150MB 文件不全量入内存）。
  static Future<String> _shaOf(File f) async {
    final capture = _DigestCapture();
    final input = sha256.startChunkedConversion(capture);
    await for (final chunk in f.openRead()) {
      input.add(chunk);
    }
    input.close();
    return capture.value!;
  }

  /// 串行文件系统变更（同 ApplicationTaskStore 的 _serial 风格）。
  Future<T> _serial<T>(Future<T> Function() action) {
    final key = _root.path;
    final next = (_pending[key] ?? Future<void>.value()).then((_) => action());
    late final Future<void> barrier;
    void release() {
      if (identical(_pending[key], barrier)) _pending.remove(key);
    }

    barrier = next.then<void>((_) => release(),
        onError: (Object _, StackTrace __) => release());
    _pending[key] = barrier;
    return next;
  }
}
