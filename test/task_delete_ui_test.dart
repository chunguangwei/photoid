import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/application_tasks_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'application_workflow_test.dart' show host, settleFiles;
import 'photo_file_inspection_test.dart' show requirement;

void main() {
  Future<(Directory, ApplicationTaskStore, String)> seeded(
      WidgetTester tester) async {
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    final t = (await tester.runAsync(() => store.create(name: 'ToDelete')))!;
    await tester.runAsync(() => store.addOutput(t.id, requirement(), 'photo'));
    return (dir, store, t.id);
  }

  testWidgets('long press a task row deletes it after confirm',
      (tester) async {
    final (_, store, _) = await seeded(tester);
    await tester.pumpWidget(host(ApplicationTasksPage(store: store)));
    await settleFiles(tester);
    await tester.longPress(find.text('ToDelete'));
    await settleFiles(tester);
    // Cancel keeps the record.
    await tester.tap(find.text('Cancel'));
    await settleFiles(tester);
    expect(((await tester.runAsync(store.list))!), hasLength(1));
    await tester.longPress(find.text('ToDelete'));
    await settleFiles(tester);
    await tester.tap(find.text('Delete task'));
    await settleFiles(tester);
    expect(((await tester.runAsync(store.list))!), isEmpty);
    expect(find.text('ToDelete'), findsNothing);
  });
  testWidgets('visible trash icon on the row deletes after confirm',
      (tester) async {
    final (_, store, id) = await seeded(tester);
    await tester.pumpWidget(host(ApplicationTasksPage(store: store)));
    await settleFiles(tester);
    await tester.tap(find.byKey(Key('task-delete-$id')));
    await settleFiles(tester);
    await tester.tap(find.text('Delete task'));
    await settleFiles(tester);
    expect(((await tester.runAsync(store.list))!), isEmpty);
  });
  testWidgets('detail page trash still deletes', (tester) async {
    final (_, store, _) = await seeded(tester);
    await tester.pumpWidget(host(ApplicationTasksPage(store: store)));
    await settleFiles(tester);
    await tester.tap(find.text('ToDelete'));
    await settleFiles(tester);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await settleFiles(tester);
    await tester.tap(find.text('Confirm'));
    await settleFiles(tester);
    expect(((await tester.runAsync(store.list))!), isEmpty);
  });
}
