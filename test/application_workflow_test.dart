import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/theme/app_theme.dart';
import 'package:photoid/pages/application_tasks_page.dart';
import 'package:photoid/pages/application_task_page.dart';
import 'package:photoid/pages/photo_check_page.dart';
import 'package:photoid/pages/custom_spec_page.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photoid/services/application_task_store.dart';
import 'photo_file_inspection_test.dart' show requirement;

Widget host(Widget child, {String lang = 'en', bool dark = false}) =>
    MaterialApp(
        locale: Locale(lang),
        theme: photoIdTheme(Brightness.light),
        darkTheme: photoIdTheme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child);
Future<void> settleFiles(WidgetTester tester, {Finder? until}) async {
  for (var i = 0; i < 500; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 20));
    if ((until == null || until.evaluate().isNotEmpty) &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame) {
      return;
    }
  }
  fail('Filesystem-backed UI did not settle');
}

void main() {
  late Directory dir;
  late ApplicationTaskStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('task_ui_');
    store = ApplicationTaskStore(dir);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  testWidgets('create a named task and reopen it from local list',
      (tester) async {
    await tester.pumpWidget(host(ApplicationTasksPage(store: store)));
    await settleFiles(tester);
    await tester.tap(find.byKey(const Key('new-task')));
    await settleFiles(tester);
    await tester.enterText(
        find.byKey(const Key('task-name')), 'Fall enrollment');
    await tester.tap(find.byKey(const Key('save-task-details')));
    await settleFiles(tester, until: find.text('Fall enrollment'));
    expect(find.text('Fall enrollment'), findsOneWidget);
    expect((await tester.runAsync(() => store.list()))!.single.name,
        'Fall enrollment');
    await tester.pageBack();
    await settleFiles(tester, until: find.text('Fall enrollment'));
    expect(find.text('Fall enrollment'), findsOneWidget);
  });
  testWidgets(
      'editing persisted requirements restores a valid background selection',
      (tester) async {
    final persisted = PhotoSpec.fromJson(requirement().toJson());
    await tester.pumpWidget(
        host(CustomSpecPage(returnSpec: true, initialSpec: persisted)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'existing ID Photo action still brings the specification list into view',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'PhotoID',
        packageName: 'photoid',
        version: '1.1.0',
        buildNumber: '49',
        buildSignature: '');
    await tester.pumpWidget(host(const HomePage()));
    await tester.pumpAndSettle();
    final action = find.text('ID Photo');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    final heading = find.text('Common specifications');
    expect(heading, findsOneWidget);
    expect(tester.getTopLeft(heading).dy, inInclusiveRange(0, 150));
  });
  for (final lang in ['en', 'zh']) {
    for (final dark in [false, true]) {
      testWidgets('new pages $lang dark=$dark fit small phone at 130%',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final t = (await tester.runAsync(() => store.create(
            name: 'An application with a long descriptive title')))!;
        await tester.runAsync(
            () => store.addOutput(t.id, requirement(), 'applicant_123'));
        for (final page in [
          ApplicationTasksPage(store: store),
          ApplicationTaskPage(taskId: t.id, store: store),
          const PhotoCheckPage()
        ]) {
          await tester.pumpWidget(host(
              MediaQuery(
                  data:
                      const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                  child: page),
              lang: lang,
              dark: dark));
          await settleFiles(tester);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
