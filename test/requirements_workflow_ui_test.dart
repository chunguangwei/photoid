import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/application_tasks_page.dart';
import 'package:photoid/pages/application_task_page.dart';
import 'package:photoid/pages/splash_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/demo_task.dart';
import 'application_workflow_test.dart' show host, settleFiles;

void main() {
  testWidgets('preparation history does not offer an example task',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    await tester.pumpWidget(host(ApplicationTasksPage(store: store)));
    await settleFiles(tester);
    expect(find.text('Try a demo task'), findsNothing);
    expect((await tester.runAsync(() => store.list()))!, isEmpty);
  });
  testWidgets('startup finishes brand motion and shows home without countdown',
      (tester) async {
    await tester.pumpWidget(host(const SplashPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Skip'), findsNothing);
    expect(find.text('AI photo finder'), findsOneWidget);
  });
  for (final lang in ['zh', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('task workflow at 320pt 130% $lang dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final dir =
            (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
        addTearDown(() => dir.delete(recursive: true));
        final store = ApplicationTaskStore(dir);
        final t = await tester.runAsync(() => DemoTask.open(store, lang));
        await tester.pumpWidget(host(
            MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: ApplicationTaskPage(taskId: t!.id, store: store)),
            lang: lang,
            dark: dark));
        await settleFiles(tester);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
