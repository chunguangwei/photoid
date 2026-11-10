// 验收 #3 记录：iPhone 13 真机逐图嵌入吞吐（图像前向计时 → 500 张外推）。
// 模型来源同 enhanced_golden_test：优先下载，失败回退 devicectl 推送。
// 运行：flutter test integration_test/enhanced_throughput_test.dart -d <device>
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:photoid/services/embedding_model_store.dart';
import 'package:photoid/services/embedding_session.dart';
import 'package:path_provider/path_provider.dart';

Future<EmbeddingModelStore> _readyStore() async {
  final store = await EmbeddingModelStore.open();
  if (store.status == EmbeddingModelStatus.ready) return store;
  try {
    await store.startDownload();
  } catch (e) {
    debugPrint('bench: download failed ($e); waiting for pushed files');
  }
  if (store.status == EmbeddingModelStatus.ready) return store;
  final docs = await getApplicationDocumentsDirectory();
  final root = await EmbeddingModelStore.open(root: docs);
  for (var i = 0; i < 240 && root.status != EmbeddingModelStatus.ready; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  expect(root.status, EmbeddingModelStatus.ready,
      reason: 'neither download nor push delivered the model pack');
  return root;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iPhone 13 image embedding throughput (bench)', (tester) async {
    final sw = Stopwatch()..start();
    final store = await _readyStore();
    final session = await EmbeddingSession.open(store.directoryPath);
    addTearDown(session.dispose);
    final openMs = sw.elapsedMilliseconds;
    final bytes =
        (await rootBundle.load('assets/demo/portrait.jpg')).buffer.asUint8List();
    // 预热一次（含首图惰性路径），随后 10 张计时。
    await session.embedImageBytes(bytes);
    final per = <int>[];
    for (var i = 0; i < 10; i++) {
      final t = Stopwatch()..start();
      await session.embedImageBytes(bytes);
      per.add(t.elapsedMilliseconds);
    }
    per.sort();
    final median = per[per.length ~/ 2], mean = per.reduce((a, b) => a + b) ~/ per.length;
    debugPrint('bench: open=${openMs}ms per-image median=${median}ms '
        'mean=${mean}ms min=${per.first}ms max=${per.last}ms '
        'est500=${(median * 500 / 1000).round()}s');
    expect(median, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
