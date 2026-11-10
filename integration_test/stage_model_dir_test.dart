// 辅助：创建 embedding_model 目录并等待推送的模型文件字节齐全，
// 然后打开 EmbeddingSession 验证就绪。配合 devicectl 推送使用。
// 运行：flutter test integration_test/stage_model_dir_test.dart -d <device>
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:photoid/services/embedding_model_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('create store dir and wait for pushed pack', (tester) async {
    final store = await EmbeddingModelStore.open();
    debugPrint('staging: dir=${store.directoryPath} status=${store.status}');
    for (var i = 0; i < 400 && store.status != EmbeddingModelStatus.ready; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    debugPrint('staging: final status=${store.status} '
        'installed=${store.installedBytes}/${store.totalBytes}');
    expect(store.status, EmbeddingModelStatus.ready);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
