import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photoid/services/requirements_ocr.dart';
import 'package:photoid/services/requirements_parser.dart';
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/demo_task.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'bundled native OCR reads English and Chinese fixtures without remote recognition',
      (tester) async {
    final root = await (await getTemporaryDirectory())
        .createTemp('requirements_native_');
    try {
      for (final locale in ['en', 'zh']) {
        final asset = locale == 'zh'
            ? 'assets/demo/requirements-zh.png'
            : 'assets/demo/requirements.png';
        final bytes = await rootBundle.load(asset);
        final file = await File('${root.path}/$locale.png').writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        final text = await RequirementsOcr.recognize(file.path);
        expect(text, contains('480'));
        expect(text, contains('640'));
        expect(text, contains('300'));
        expect(text, contains('400'));
        final parsed = parseRequirements(text);
        expect(parsed.dimensions.any((d) => d.width == 480 && d.height == 640),
            true,
            reason: text);
        expect(parsed.sizes.any((s) => s.min == 20 && s.max == 100), true,
            reason: text);
        final task = await DemoTask.open(
            ApplicationTaskStore(Directory('${root.path}/$locale')), locale);
        expect(task.isDemo, true);
        expect(task.outputs.length, 2);
        expect(task.complete, false);
      }
    } finally {
      await root.delete(recursive: true);
    }
  });
}
