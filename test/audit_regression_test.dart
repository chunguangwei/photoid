import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/main.dart';
import 'package:photoid/theme/app_theme.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/pages/custom_spec_page.dart';
import 'package:photoid/pages/home_page.dart';
import 'package:photoid/pages/kb_tool_page.dart';
import 'package:photoid/pages/settings_page.dart';
import 'package:photoid/pages/spec_detail_page.dart';
import 'package:photoid/services/custom_spec_store.dart';
import 'package:photoid/services/image_pipeline.dart';
import 'package:photoid/services/spec_library.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'PhotoID',
        packageName: 'photoid',
        version: '0.8.5',
        buildNumber: '47',
        buildSignature: '');
  });

  test('English passport search finds built-in specifications', () async {
    final specs = await SpecLibrary.search('passport');
    expect(specs, isNotEmpty);
    expect(
        specs.every((s) => (s.nameEn ?? '').toLowerCase().contains('passport')),
        isTrue);
  });

  test('one corrupt custom specification preserves the other entries',
      () async {
    SharedPreferences.setMockInitialValues({
      'custom_specs': jsonEncode([
        studentPhotoSpec.toJson(),
        {'id': 'broken'}
      ]),
    });
    expect((await CustomSpecStore.load()).map((s) => s.id),
        contains(studentPhotoSpec.id));
  });

  test('zero KB ceiling preserves normal JPEG quality', () {
    final image = img.Image(width: 120, height: 160);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, x * 2, y, (x * y) % 256);
      }
    }
    final bytes = ImagePipeline.encodeToKbRange(image, 0, 0);
    expect(bytes.length,
        greaterThanOrEqualTo(img.encodeJpg(image, quality: 85).length));
  });

  test(
      'impossible JPEG ceiling fails explicitly instead of returning oversized bytes',
      () {
    final image = img.Image(width: 480, height: 640);
    expect(() => ImagePipeline.encodeToKbRange(image, 0, 1),
        throwsA(isA<StateError>()));
  });

  test('invalid KB ranges are rejected before encoding', () {
    final image = img.Image(width: 50, height: 50);
    expect(() => ImagePipeline.encodeToKbRange(image, -1, 10),
        throwsArgumentError);
    expect(() => ImagePipeline.encodeToKbRange(image, 20, 10),
        throwsArgumentError);
  });

  testWidgets('privacy policy is accessible from settings', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsPage(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'https://chunguangwei.github.io/photoid/privacy-policy'),
        findsOneWidget);
  });

  testWidgets('unsupported system language falls back to English',
      (tester) async {
    await tester.pumpWidget(const PhotoIdApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
        app.localeResolutionCallback!(const Locale('fr'), app.supportedLocales),
        const Locale('en'));
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in ['en', 'zh']) {
    for (final dark in [false, true]) {
      for (final (name, page) in <(String, Widget)>[
        ('home', const HomePage()),
        ('detail', const SpecDetailPage(spec: studentPhotoSpec)),
        ('custom', const CustomSpecPage()),
        ('kb', const KbToolPage()),
        ('settings', const SettingsPage()),
      ]) {
        testWidgets('$name $locale dark=$dark fits a 320px phone at 130% text',
            (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: photoIdTheme(dark ? Brightness.dark : Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: page,
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
