import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/photo_finder_page.dart';
import 'package:photoid/pages/application_task_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/photo_finder_session.dart';
import 'package:photoid/services/demo_task.dart';
import 'application_workflow_test.dart' show host, settleFiles;

class EmptyGateway implements FinderGateway {
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) async =>
      method == 'chooseFiles'
          ? {'session': 'test', 'visited': 0, 'entries': []}
          : null;
}

class CandidateGateway implements FinderGateway {
  CandidateGateway(this.path);
  final String path;
  final calls = <String>[];
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) async {
    calls.add(method);
    if (method == 'chooseFiles') {
      return {
        'session': 'candidate',
        'visited': 1,
        'entries': [
          {
            'id': 'one',
            'name': 'source.jpg',
            'relativePath': 'local/source.jpg'
          }
        ]
      };
    }
    if (method == 'analyze') {
      return {
        'width': 1000,
        'height': 1400,
        'faces': [],
        'fingerprint': 'test'
      };
    }
    if (method == 'materialize') return {'path': path};
    return null;
  }
}

void main() {
  testWidgets(
      'finder manual action returns to existing Files Photos Camera chooser',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    final task = (await tester.runAsync(() => DemoTask.open(store, 'en')))!;
    await tester
        .pumpWidget(host(ApplicationTaskPage(taskId: task.id, store: store)));
    await settleFiles(tester);
    final finder = find.byKey(const Key('task-photo-finder'));
    await tester.scrollUntilVisible(finder, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settleFiles(tester);
    await tester.tap(find.byKey(const Key('finder-manual')));
    await settleFiles(tester);
    await tester.tap(find.text('Confirm'));
    await settleFiles(tester);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.byType(PhotoFinderPage), findsNothing);
  });

  for (final stale in [false, true]) {
    testWidgets(
        'uncertain candidate stays selectable; stale=$stale blocks adoption',
        (tester) async {
      final dir =
          (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
      addTearDown(() => dir.delete(recursive: true));
      final store = ApplicationTaskStore(dir);
      final task = (await tester.runAsync(() => DemoTask.open(store, 'en')))!;
      final asset = await rootBundle.load('assets/demo/portrait.jpg');
      final source = (await tester.runAsync(() =>
          File('${dir.path}/candidate.jpg').writeAsBytes(asset.buffer
              .asUint8List(asset.offsetInBytes, asset.lengthInBytes))))!;
      final gateway = CandidateGateway(source.path);
      await tester.pumpWidget(host(Builder(
          builder: (ctx) => Scaffold(
              body: FilledButton(
                  onPressed: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => PhotoFinderPage(
                              taskId: task.id,
                              store: store,
                              gateway: gateway))),
                  child: const Text('Open finder'))))));
      await tester.tap(find.text('Open finder'));
      await settleFiles(tester);
      await tester.scrollUntilVisible(
          find.byKey(const Key('finder-files')), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('finder-files')));
      await settleFiles(tester);
      final candidate = find.byKey(const ValueKey('finder-result-source.jpg'));
      await tester.scrollUntilVisible(candidate, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              'No face detected — cannot determine suitability'),
          findsOneWidget);
      if (stale) {
        await tester.runAsync(() => store.setSource(
            task.id,
            asset.buffer
                .asUint8List(asset.offsetInBytes, asset.lengthInBytes)));
      }
      final use = find.text('Use this photo');
      await tester.ensureVisible(use);
      await tester.tap(use);
      await settleFiles(tester);
      if (stale) {
        expect(
            find.text(
                'Task requirements or source changed. Exit and search again before using a result.'),
            findsOneWidget);
        expect(gateway.calls, isNot(contains('materialize')));
      } else {
        expect(
            find.text(
                'Replacing the source resets all completed versions. Your system photo is not deleted.'),
            findsOneWidget);
        await tester.tap(find.text('Confirm'));
        await settleFiles(tester, until: find.text('Open finder'));
        expect(find.byType(PhotoFinderPage), findsNothing);
        final updated = (await tester.runAsync(() => store.get(task.id)))!;
        expect(updated.sourceRevision, task.sourceRevision + 1);
        expect(updated.outputs.every((o) => !o.ready), isTrue);
        expect(gateway.calls, contains('close'));
      }
    });
  }

  testWidgets('manual entry stays available; no requirements prevents scanning',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    final task = (await tester.runAsync(() => store.create(name: 'Empty')))!;
    await tester.pumpWidget(host(PhotoFinderPage(
        taskId: task.id, store: store, gateway: EmptyGateway())));
    await settleFiles(tester);
    expect(find.byKey(const Key('finder-manual')), findsOneWidget);
    final button =
        tester.widget<OutlinedButton>(find.byKey(const Key('finder-folder')));
    expect(button.onPressed, isNull);
  });
  for (final lang in ['zh', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('finder setup fits small screen $lang dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final dir =
            (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
        addTearDown(() => dir.delete(recursive: true));
        final store = ApplicationTaskStore(dir);
        final task = (await tester.runAsync(() => DemoTask.open(store, lang)))!;
        await tester.pumpWidget(host(
            MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: PhotoFinderPage(
                    taskId: task.id, store: store, gateway: EmptyGateway())),
            lang: lang,
            dark: dark));
        await settleFiles(tester);
        expect(find.byKey(const Key('finder-manual')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
