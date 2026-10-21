// Run explicitly: flutter test test/tools/capture_audit.dart
// Local review renders, never App Store screenshots. No native camera/AI claims.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/pages/custom_spec_page.dart';
import 'package:photoid/pages/home_page.dart';
import 'package:photoid/pages/application_tasks_page.dart';
import 'package:photoid/pages/application_task_page.dart';
import 'package:photoid/pages/photo_check_page.dart';
import 'package:photoid/services/application_task_store.dart';
import '../application_workflow_test.dart' show settleFiles;
import 'package:photoid/pages/kb_tool_page.dart';
import 'package:photoid/pages/settings_page.dart';
import 'package:photoid/pages/spec_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photoid/theme/app_theme.dart';

void main() {
  testWidgets('render static pages for visual inspection', (tester) async {
    final oldDisableShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = oldDisableShadows);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'PhotoID',
        packageName: 'photoid',
        version: '0.8.5',
        buildNumber: '47',
        buildSignature: '');
    // Use real glyphs instead of the square Ahem test font. Kept local to macOS.
    for (final (family, path) in [
      ('AuditSans', '/System/Library/Fonts/Supplemental/Arial.ttf'),
      ('AuditCJK', '/System/Library/Fonts/Supplemental/Arial Unicode.ttf'),
      ('Roboto', '/System/Library/Fonts/Supplemental/Arial Unicode.ttf'),
      (
        'MaterialIcons',
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      ),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
            Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
      await loader.load();
    }
    final out = Directory('build/audit-ui')..createSync(recursive: true);
    final taskDir = await tester
        .runAsync(() => Directory.systemTemp.createTemp('photoid_ui_render_'));
    addTearDown(() async => taskDir!.delete(recursive: true));
    final store = ApplicationTaskStore(taskDir!);
    final task = (await tester.runAsync(() => store.create(
        name: 'Sample application',
        notes: 'Example requirements for demonstration only.')))!;
    await tester.runAsync(
        () => store.addOutput(task.id, studentPhotoSpec, 'application_photo'));
    await tester.runAsync(() => store.addOutput(task.id,
        studentPhotoSpec.copyWith(name: 'Second file'), 'profile_photo'));

    for (final locale in ['en', 'zh']) {
      for (final dark in [false, true]) {
        for (final (name, page) in <(String, Widget)>[
          ('home', const HomePage()),
          ('tasks', ApplicationTasksPage(store: store)),
          ('task', ApplicationTaskPage(taskId: task.id, store: store)),
          ('task_files', ApplicationTaskPage(taskId: task.id, store: store)),
          ('file_check', const PhotoCheckPage()),
          ('detail', const SpecDetailPage(spec: studentPhotoSpec)),
          ('custom', const CustomSpecPage()),
          ('kb', const KbToolPage()),
          ('settings', const SettingsPage()),
        ]) {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          final key = GlobalKey();
          await tester.pumpWidget(MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: photoIdTheme(dark ? Brightness.dark : Brightness.light)
                .copyWith(
              filledButtonTheme: FilledButtonThemeData(style: photoIdTheme(dark ? Brightness.dark : Brightness.light).filledButtonTheme.style?.copyWith(textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily:'AuditCJK',fontSize:14,fontWeight:FontWeight.w600)))),
              outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(textStyle:const TextStyle(fontFamily:'AuditCJK',fontSize:14,fontWeight:FontWeight.w600))),
              textButtonTheme: TextButtonThemeData(style:TextButton.styleFrom(textStyle:const TextStyle(fontFamily:'AuditCJK',fontSize:14,fontWeight:FontWeight.w600))),
              textTheme: photoIdTheme(dark ? Brightness.dark : Brightness.light)
                  .textTheme
                  .apply(
                      fontFamily: 'AuditSans',
                      fontFamilyFallback: const ['AuditCJK']),
            ),
            home: RepaintBoundary(key: key, child: page),
          ));
          await settleFiles(tester);
          if (name == 'task_files') {
            await tester.scrollUntilVisible(
                find.byKey(const Key('add-output')), 200, scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/${name}_${locale}_${dark ? 'dark' : 'light'}.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
    debugDisableShadows = oldDisableShadows;
    tester.view.reset();
  });
}
