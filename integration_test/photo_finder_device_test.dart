import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart' show getCrc32, ZipDecoder;
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
import 'package:photoid/services/image_pipeline.dart';
import 'package:photoid/services/application_delivery.dart';
import 'package:photoid/models/photo_spec.dart';
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

  testWidgets('real HEIC, EXIF rotation and predecode resource guards',
      (tester) async {
    final root =
        await (await getTemporaryDirectory()).createTemp('finder_formats_');
    final gateway = NativeFinderGateway();
    String? session;
    try {
      final heic = await rootBundle.load('assets/demo/portrait.heic');
      final heicFile = await File('${root.path}/portrait.heic').writeAsBytes(
          heic.buffer.asUint8List(heic.offsetInBytes, heic.lengthInBytes));
      final jpeg = await rootBundle.load('assets/demo/portrait.jpg');
      final oriented = img.decodeJpg(
          jpeg.buffer.asUint8List(jpeg.offsetInBytes, jpeg.lengthInBytes))!;
      oriented.exif.imageIfd.orientation = 6;
      final rotated = await File('${root.path}/rotated.jpg')
          .writeAsBytes(img.encodeJpg(oriented));
      final bigBytes = File('${root.path}/over_30mb.jpg');
      final handle = await bigBytes.open(mode: FileMode.write);
      await handle.truncate(30 * 1024 * 1024 + 1);
      await handle.close();
      // A valid 25MP, 1-bit grayscale PNG needs only ~3MB of raw row data.
      // Metadata must reject it before the native decoder allocates pixels.
      List<int> chunk(String type, List<int> content) {
        final bytes = Uint8List.fromList([...type.codeUnits, ...content]);
        final length = ByteData(4)..setUint32(0, content.length);
        final crc = ByteData(4)..setUint32(0, getCrc32(bytes));
        return [
          ...length.buffer.asUint8List(),
          ...bytes,
          ...crc.buffer.asUint8List()
        ];
      }

      final ihdr = ByteData(13)
        ..setUint32(0, 5000)
        ..setUint32(4, 5000)
        ..setUint8(8, 1);
      final png = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        ...chunk('IHDR', ihdr.buffer.asUint8List()),
        ...chunk('IDAT', ZLibEncoder().convert(Uint8List(626 * 5000))),
        ...chunk('IEND', []),
      ]);
      final bomb = await File('${root.path}/over_24mp.png').writeAsBytes(png);
      final listing = await gateway.call('openDemo', {
        'paths': [heicFile.path, rotated.path, bigBytes.path, bomb.path]
      });
      session = listing['session'] as String;
      final results = <String, Map>{};
      for (final entry in listing['entries']) {
        results[entry['name'] as String] = {
          ...Map.from(entry),
          ...Map.from(await gateway
              .call('analyze', {'session': session, 'id': entry['id']}))
        };
      }
      final h = results['portrait.heic']!;
      expect(h['skip'], isNull);
      expect(h['width'], 800);
      expect(h['height'], 1200);
      final copied = await gateway.call('materialize',
          {'session': session, 'id': h['id'], 'fingerprint': h['fingerprint']});
      final converted =
          img.decodeJpg(await File(copied['path'] as String).readAsBytes())!;
      expect(converted.width, 800);
      expect(converted.height, 1200);
      final rotation = results['rotated.jpg']!;
      expect(rotation['skip'], isNull);
      expect(rotation['width'], 1200);
      expect(rotation['height'], 800);
      final thumb = img.decodeJpg(
          await File(rotation['thumbnailPath'] as String).readAsBytes())!;
      expect(thumb.width / thumb.height, closeTo(1.5, .01));
      expect(results['over_30mb.jpg']!['skip'], 'oversized');
      expect(results['over_24mp.png']!['skip'], 'oversized');
    } finally {
      if (session != null) await gateway.call('close', {'session': session});
      await root.delete(recursive: true);
    }
  });

  testWidgets('native editing pipeline saves reopens and verifies delivery ZIP',
      (tester) async {
    final root =
        await (await getTemporaryDirectory()).createTemp('finder_delivery_');
    try {
      final store = ApplicationTaskStore(root);
      var task = await store.create(name: 'Native delivery QA');
      final source = await rootBundle.load('assets/demo/portrait.jpg');
      task = await store.setSource(
          task.id,
          source.buffer
              .asUint8List(source.offsetInBytes, source.lengthInBytes));
      task = await store.addOutput(task.id,
          DemoTask.spec('Main', 480, 640, 0, 120, idPhotoBlue), 'main');
      task = await store.addOutput(
          task.id,
          DemoTask.spec('Profile', 300, 400, 0, 120,
              const SpecBackground('white', 255, 255, 255)),
          'profile');
      for (final output in task.outputs) {
        final result = await ImagePipeline()
            .run(store.sourceFile(task).path, output.spec)
            .timeout(const Duration(seconds: 90));
        await store.saveOutput(task.id, output.id, result.jpgBytes, output.spec,
            expectedRevision: task.tokenFor(output));
      }
      final reopened = await ApplicationTaskStore(root).get(task.id);
      expect(reopened.complete, true);
      final zip = await ApplicationDelivery.build(reopened, store, root, 'en');
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      expect(archive.files.length, 5);
      for (final output in reopened.outputs) {
        final bytes = archive.findFile('${output.fileName}.jpg')!.content;
        final delivered = img.decodeJpg(bytes)!;
        expect(delivered.width, output.spec.pixelWidth);
        expect(delivered.height, output.spec.pixelHeight);
        expect(bytes, await store.outputFile(reopened, output).readAsBytes());
      }
      expect(utf8.decode(archive.findFile('CHECKLIST.txt')!.content),
          contains('Native delivery QA'));
      expect(
          archive.files.any((f) =>
              f.name.contains('portrait') || f.name.contains('thumbnail')),
          false);
    } finally {
      await root.delete(recursive: true);
    }
  });
  testWidgets(
      'production finder UI runs actual sample analysis and captures review evidence',
      (tester) async {
    if (Platform.isIOS && binding.lifecycleState != AppLifecycleState.resumed) {
      markTestSkipped(
          'Unlock iPhone and bring the app to foreground before native UI capture.');
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
