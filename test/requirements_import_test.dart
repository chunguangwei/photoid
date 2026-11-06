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
