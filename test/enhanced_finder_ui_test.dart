import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/embedding_model_page.dart';
import 'package:photoid/pages/photo_finder_page.dart';
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/demo_task.dart';
import 'package:photoid/services/embedding_model_store.dart';
import 'package:photoid/services/photo_finder_session.dart';
import 'application_workflow_test.dart' show host, settleFiles;

class CandidateGateway implements FinderGateway {
  CandidateGateway(this.path);
  final String path;
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) async {
    if (method == 'chooseFiles' || method == 'choosePhotos') {
      return {
        'session': 'candidate',
        'visited': 1,
        'entries': [
          {'id': 'one', 'name': 'source.jpg', 'relativePath': 'local/source.jpg'}
        ]
      };
    }
    if (method == 'analyze') {
      return {'width': 1000, 'height': 1400, 'faces': [], 'fingerprint': 'test'};
    }
    if (method == 'materialize') return {'path': path};
    return null;
  }
}

/// 真实 store（临时目录 + 合成 manifest）驱动，行为可控且无网络。
Future<EmbeddingModelStore> fakeStore(Directory dir,
    {required bool ready}) async {
  final store = await EmbeddingModelStore.open(
      root: dir,
      manifest: const [
        EmbeddingFileSpec(
            'a.bin', 3, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
      ]);
  if (ready) await store.file('a.bin').writeAsBytes([1, 2, 3]);
  return store;
}

/// 打开 finder 并让候选批次就绪。
Future<void> openFinder(WidgetTester tester, FinderGateway gateway,
    ApplicationTaskStore store, String taskId, EmbeddingModelStore embed) async {
  await tester.pumpWidget(host(Builder(
      builder: (ctx) => Scaffold(
          body: FilledButton(
              onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => PhotoFinderPage(
                          taskId: taskId,
                          store: store,
                          gateway: gateway,
                          embeddingStore: embed)),
              ),
              child: const Text('Open finder'))))));
  await tester.tap(find.text('Open finder'));
  await settleFiles(tester);
  await tester.tap(find.text('Formats, limits & privacy'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('finder-files')), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.byKey(const Key('finder-files')));
  await settleFiles(tester);
}

void main() {
  testWidgets(
      'enhanced toggle: not installed opens download dialog, cancel hides input',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    final task = (await tester.runAsync(() => DemoTask.open(store, 'en')))!;
    final embed = (await tester.runAsync(() => fakeStore(dir, ready: false)))!;
    await openFinder(tester, CandidateGateway('${dir.path}/out.jpg'), store, task.id, embed);
    final chip = find.byKey(const Key('enhanced-toggle'));
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await settleFiles(tester);
    expect(find.text('Enable Enhanced?'), findsOneWidget);
    expect(find.byKey(const Key('enhanced-download')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settleFiles(tester);
    expect(find.byKey(const Key('enhanced-input')), findsNothing);
    expect(embed, isNotNull);
  });

  testWidgets('enhanced toggle with ready model reveals semantic search box',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    final task = (await tester.runAsync(() => DemoTask.open(store, 'en')))!;
    final embed = (await tester.runAsync(() => fakeStore(dir, ready: true)))!;
    await openFinder(tester, CandidateGateway('${dir.path}/out.jpg'), store, task.id, embed);
    await tester.tap(find.byKey(const Key('enhanced-toggle')));
    await settleFiles(tester);
    expect(embed.status, EmbeddingModelStatus.ready);
    expect(find.byKey(const Key('enhanced-input')), findsOneWidget);
    expect(find.textContaining('Semantic reference ranking'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('enhanced-input')), 'portrait');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    // 排序真的启动：进度行出现（会话在测试环境无 ONNX，open 失败落兜底）
    expect(find.text('Stop ranking'), findsOneWidget);
  });

  testWidgets('model page renders download affordance for missing model',
      (tester) async {
    final dir =
        (await tester.runAsync(() => Directory.systemTemp.createTemp()))!;
    addTearDown(() => dir.delete(recursive: true));
    final store = (await tester.runAsync(() => fakeStore(dir, ready: false)))!;
    await tester.pumpWidget(host(EmbeddingModelPage(store: store)));
    await settleFiles(tester);
    expect(find.byKey(const Key('model-download')), findsOneWidget);
  });
}
