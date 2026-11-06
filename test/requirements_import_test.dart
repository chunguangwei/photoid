import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/requirements_import_page.dart';
import 'application_workflow_test.dart' show host;

void main() {
  testWidgets('failed OCR can retry and never silently adds defaults',
      (tester) async {
    await tester.pumpWidget(host(RequirementsImportPage(
        imagePath: '/missing',
        recognize: (_) => Future.error(StateError('offline')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(find.text('Confirm and add requirements'), findsNothing);
  });
  testWidgets('ambiguous OCR requires explicit review before adding',
      (tester) async {
    await tester.pumpWidget(host(RequirementsImportPage(
        imagePath: '/missing',
        recognize: (_) async => '480×640px; 20-100KB; blue background; JPG')));
    await tester.pumpAndSettle();
    expect(find.textContaining('confirm width'), findsOneWidget);

    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, '');
    expect(fields[1].controller!.text, '');
    await tester.scrollUntilVisible(
        find.byKey(const Key('import-confirm')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(RequirementsImportPage), findsOneWidget);
    expect(find.textContaining('Complete and confirm'), findsOneWidget);
  });
  testWidgets('only short matched excerpts are proposed for export',
      (tester) async {
    await tester.pumpWidget(host(RequirementsImportPage(
        imagePath: '/missing',
        recognize: (_) async =>
            'Account: PRIVATE-123\nWidth:480px, height:640px; 20-100KB; blue background or white background; JPG')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('import-excerpt')), 250,
        scrollable: find.byType(Scrollable).first);
    final excerpt = tester
        .widget<TextFormField>(find.byKey(const Key('import-excerpt')))
        .controller!
        .text;
    expect(excerpt, contains('Width:480px'));
    expect(excerpt, contains('20-100KB'));
    expect(excerpt, isNot(contains('PRIVATE-123')));
  });
  testWidgets('confirmed import returns selected values and short excerpts',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    RequirementImportResult? result;
    await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<RequirementImportResult>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RequirementsImportPage(
                          imagePath: '/missing',
                          recognize: (_) async =>
                              'PRIVATE-123\nWidth:480px, height:640px; 20-100KB; blue background; JPG')));
            },
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('import-width')))
            .controller!
            .text,
        '480');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('import-height')))
            .controller!
            .text,
        '640');
    await tester.enterText(find.byKey(const Key('import-name')), 'main');
    await tester.tap(find.widgetWithText(ActionChip, 'blue background'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.spec!.pixelWidth, 480);
    expect(result!.spec!.minFileKb, 20);
    expect(result!.spec!.maxFileKb, 100);
    expect(result!.fileName, 'main');
    expect(result!.excerpt, isNot(contains('PRIVATE-123')));
  });
  testWidgets('failed OCR manual entry returns explicit manual intent',
      (tester) async {
    RequirementImportResult? result;
    await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<RequirementImportResult>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RequirementsImportPage(
                          imagePath: '/missing',
                          recognize: (_) =>
                              Future.error(StateError('failed')))));
            },
            child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter requirements manually'));
    await tester.pumpAndSettle();
    expect(result!.manual, true);
  });
  testWidgets('conflicting backgrounds are listed and remain unselected',
      (tester) async {
    await tester.pumpWidget(host(RequirementsImportPage(
        imagePath: '/missing',
        recognize: (_) async =>
            'Width:480px, height:640px; 20-100KB; blue background or white background; JPG')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.widgetWithText(ActionChip, 'blue background'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.widgetWithText(ActionChip, 'blue background'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'white background'), findsOneWidget);
  });
  testWidgets('late OCR after disposal cannot update UI', (tester) async {
    final result = Completer<String>();
    await tester.pumpWidget(host(RequirementsImportPage(
        imagePath: '/missing', recognize: (_) => result.future)));
    await tester.pump();
    await tester.pumpWidget(host(const SizedBox()));
    result.complete('Width:480px, height:640px');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
