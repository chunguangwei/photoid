// 验收 #1：真机全管线对拍——下载好的 q4f16 模型 + 纯 Dart 分词/预处理，
// 对 assets/demo/portrait.jpg 与两个 golden 查询生成向量，
// 与桌面 ORT 基准（test/fixtures/embedding_golden.json）余弦 ≥ 0.999。
// 前置：模型未装时测试自动下载（或在 App「我的→图片处理模型」先行下载）。
// 运行：flutter test integration_test/enhanced_golden_test.dart -d <device>
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:photoid/services/embedding_model_store.dart';
import 'package:photoid/services/embedding_session.dart';
import 'package:path_provider/path_provider.dart';

double _cos(List<double> a, List<double> b) {
  var d = 0.0;
  for (var i = 0; i < a.length; i++) {
    d += a[i] * b[i];
  }
  return d;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('on-device embeddings match desktop golden (cos >= 0.999)',
      (tester) async {
    final store = await EmbeddingModelStore.open();
    if (store.status != EmbeddingModelStatus.ready) {
      // 自给：未装则下载（验收 #2 顺带覆盖真机三源/续传路径）。
      debugPrint('golden: downloading model (${store.installedBytes}/'
          '${store.totalBytes}) …');
      try {
        await store.startDownload(
            onProgress: (p) => debugPrint(
                'golden: ${p.receivedBytes}/${p.totalBytes} ${p.activeFile}'));
      } catch (e) {
        debugPrint('golden: download failed ($e); waiting for pushed files');
      }
    }
    if (store.status != EmbeddingModelStatus.ready) {
      // 网络受限时回退：等 devicectl 把 5 个模型文件推到 Documents 根
      // （按精确字节数判定完整性，存在≠完整），再指认该目录。
      final docs = await getApplicationDocumentsDirectory();
      final root = await EmbeddingModelStore.open(root: docs);
      for (var i = 0;
          i < 240 && root.status != EmbeddingModelStatus.ready;
          i++) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      expect(root.status, EmbeddingModelStatus.ready,
          reason: 'neither download nor push delivered the model pack');
      return _verify(root);
    }
    await _verify(store);
  }, timeout: const Timeout(Duration(minutes: 45)));
}

Future<void> _verify(EmbeddingModelStore store) async {
    final golden = jsonDecode(
        await rootBundle.loadString('test/fixtures/embedding_golden.json'));
    final session = await EmbeddingSession.open(store.directoryPath);
    addTearDown(session.dispose);

    final q1 = await session
        .embedText(EmbeddingSession.queryText('a business portrait photo of a person'));
    final q2 =
        await session.embedText(EmbeddingSession.queryText('蓝天白云'));
    final bytes = (await rootBundle.load('assets/demo/portrait.jpg'))
        .buffer
        .asUint8List();
    final portrait = await session.embedImageBytes(bytes);

    for (final e in {
      'q1': (q1, (golden['q1'] as List).cast<num>()),
      'q2': (q2, (golden['q2'] as List).cast<num>()),
      'portrait': (portrait, (golden['portrait'] as List).cast<num>()),
    }.entries) {
      final got = e.value.$1, want = e.value.$2;
      expect(got.length, 768);
      final cos = _cos(got, [for (final x in want) x.toDouble()]);
      expect(cos, greaterThanOrEqualTo(0.999),
          reason: '${e.key} cosine $cos vs desktop fp32 golden');
    }
    // 语义关系保持：人像与人像查询的相似度显著高于蓝天查询。
    final c1 = _cos(portrait, q1), c2 = _cos(portrait, q2);
    expect(c1 - c2, greaterThan(0.01),
        reason: 'portrait-vs-portrait-query margin collapsed: $c1 vs $c2');
}
