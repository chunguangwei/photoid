import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/theme/app_theme.dart';
import 'package:photoid/pages/photo_finder_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/demo_task.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photoid/services/photo_finder_demo.dart';
import 'package:photoid/services/photo_finder_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'real local detector, original fingerprint, corrupt and unknown inputs, cleanup',
      (tester) async {
    final root =
        await (await getTemporaryDirectory()).createTemp('finder_native_');
    final g = NativeFinderGateway();
    String? session;
    try {
      final paths = await writeFinderDemo(root);
      paths.add(
          (await File('${root.path}/corrupt.jpg').writeAsString('invalid'))
              .path);
      paths.add(
          (await File('${root.path}/unsupported.gif').writeAsString('invalid'))
              .path);
      // JPEG bytes with HEIC extension exercise the conversion branch independently
      // of device HEIC encoder availability; genuine HEIC codec QA is separate.
      paths.add((await File('${root.path}/wide.heic')
              .writeAsBytes(img.encodeJpg(img.Image(width: 8000, height: 300))))
          .path);
      final listing = await g.call('openDemo', {'paths': paths});
      session = listing['session'] as String;
      final values = <String, Map>{};
      for (final raw in listing['entries']) {
        final data =
            await g.call('analyze', {'session': session, 'id': raw['id']});
        values[raw['name'] as String] = {...Map.from(raw), ...Map.from(data)};
      }
      expect((values['portrait.jpg']!['faces'] as List).length, 1);
      expect((values['two_portraits.jpg']!['faces'] as List).length, 2);
      expect((values['no_portrait.jpg']!['faces'] as List), isEmpty);
      expect(values['corrupt.jpg']!['skip'], 'unreadable');
      expect(values['unsupported.gif']!['skip'], 'unsupported');
      final wide = values['wide.heic']!;
      final converted = await g.call('materialize', {
        'session': session,
        'id': wide['id'],
        'fingerprint': wide['fingerprint']
      });
      final convertedImage =
          img.decodeJpg(await File(converted['path'] as String).readAsBytes())!;
      expect(convertedImage.width, 8000);
      expect(convertedImage.height, 300);
      final portrait = values['portrait.jpg']!;
      final args = {
        'session': session,
        'id': portrait['id'],
        'fingerprint': portrait['fingerprint']
      };
      final copy = await g.call('materialize', args);
      expect(await File(copy['path'] as String).readAsBytes(),
          await File(paths.first).readAsBytes());
      await File(paths.first).writeAsBytes(await File(paths[1]).readAsBytes());
      await expectLater(
          g.call('materialize', args),
          throwsA(isA<PlatformException>()
              .having((e) => e.code, 'code', 'changed')));
      final thumbnail = File(portrait['thumbnailPath'] as String);
      expect(await thumbnail.exists(), true);
      await g.call('close', {'session': session});
      expect(await thumbnail.exists(), false);
      await expectLater(
          g.call('analyze', args),
          throwsA(isA<PlatformException>()
              .having((e) => e.code, 'code', 'closed')));
      session = null;
    } finally {
      if (session != null) await g.call('close', {'session': session});
      await root.delete(recursive: true);
    }
  });
  testWidgets(
      'production finder UI runs actual sample analysis and captures review evidence',
      (tester) async {
    if (Platform.isIOS && binding.lifecycleState != AppLifecycleState.resumed) {
      markTestSkipped('Unlock iPhone and bring the app to foreground before native UI capture.');
      return;
    }
    final temp = await getTemporaryDirectory();
    final root = await temp.createTemp('finder_ui_');
    final captures = await Directory('${temp.path}/finder_review_captures')
        .create(recursive: true);
    final store = ApplicationTaskStore(root);
    try {
      final task = await DemoTask.open(store, 'en');
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      for (final locale in ['en', 'zh']) {
        await tester.pumpWidget(MaterialApp(
            key: ValueKey(locale),
            debugShowCheckedModeBanner: false,
            locale: Locale(locale),
            theme: photoIdTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PhotoFinderPage(taskId: task.id, store: store)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('finder-manual')), findsOneWidget);
        final setupImage = await binding.takeScreenshot('finder-setup-$locale');
        await File('${captures.path}/finder-setup-$locale.png')
            .writeAsBytes(setupImage);
        final demo = find.text(locale == 'en' ? 'Try sample photos' : '体验示例照片');
        await tester.scrollUntilVisible(demo, 300,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(demo);
        await tester.pumpAndSettle();
        // File IO/native detection continue asynchronously between rendered frames.
        for (var n = 0;
            n < 120 &&
                find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
            n++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await tester.pumpAndSettle();
        }
        expect(find.byType(LinearProgressIndicator), findsNothing);
        final result = find.byKey(const ValueKey('finder-result-portrait.jpg'));
        await tester.scrollUntilVisible(result, 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        final resultImage =
            await binding.takeScreenshot('finder-results-$locale');
        expect(resultImage, isNot(orderedEquals(setupImage)),
            reason:
                'Native captures must reflect a changed visible screen, not a cached launch screen.');
        await File('${captures.path}/finder-results-$locale.png')
            .writeAsBytes(resultImage);
        final crops =
            find.descendant(of: result, matching: find.byType(ExpansionTile));
        await tester.ensureVisible(crops);
        await tester.pumpAndSettle();
        await tester.tap(crops);
        await tester.pumpAndSettle();
        final cropNote = find.text(locale == 'en'
            ? 'Approximate crop from face location; not a full-head or official framing assessment. Final framing stays editable.'
            : '根据人脸位置估计裁剪区域，并非完整头部检测或机构构图评估，最终仍可手动调整。');
        await tester.ensureVisible(cropNote);
        await tester.pumpAndSettle();
        await File('${captures.path}/finder-crops-$locale.png')
            .writeAsBytes(await binding.takeScreenshot('finder-crops-$locale'));
        expect(find.byKey(const ValueKey('finder-result-portrait.jpg')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await root.delete(recursive: true);
    }
  });
}
