import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/photo_finder_page.dart';
import 'package:photoid/pages/photo_spec_picker_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'application_workflow_test.dart' show host, settleFiles;

void main() {
  testWidgets(
      'finder opens directly, chooses a preset and does not create a task on cancellation',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    await tester.pumpWidget(host(PhotoFinderPage(store: store)));
    await settleFiles(tester);
    expect(find.byKey(const Key('finder-size')), findsOneWidget);
    expect(find.text('Try sample photos'), findsNothing);
    expect(find.text('Try a demo task'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('finder-photos')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const Key('finder-size')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSpecPickerPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-one_inch')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('finder-photos')))
            .onPressed,
        isNotNull);
    expect((await tester.runAsync(() => store.list()))!, isEmpty);
  });
}
