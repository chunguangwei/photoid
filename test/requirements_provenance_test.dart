import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/models/application_task.dart';
import 'photo_file_inspection_test.dart' show requirement;

void main() {
  late Directory dir;
  late ApplicationTaskStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('provenance_');
    store = ApplicationTaskStore(dir);
  });
  tearDown(() async => dir.delete(recursive: true));
  Uint8List jpeg() =>
      Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 140)));
  test('legacy outputs have no source; evidence and spec changes invalidate',
      () async {
    var t = await store.create(name: 'Task');
    t = await store.setEvidence(t.id, jpeg());
    t = await store.addOutput(t.id, requirement(), 'main');
    expect(t.outputs.single.requirementSource, isNull);
    t = await store.confirmOutputSource(
        t.id, t.outputs.single.id, 'Width 100px',
        expectedEvidenceRevision: 1, expectedRevision: 0);
    expect(t.outputs.single.requirementSource!.confirmed, true);
    t = await store.updateOutput(
        t.id, t.outputs.single.id, requirement(), 'renamed');
    expect(t.outputs.single.requirementSource!.confirmed, true);
    t = await store.updateOutput(t.id, t.outputs.single.id,
        requirement().copyWith(maxFileKb: 200), 'renamed');
    expect(t.outputs.single.requirementSource!.confirmed, false);
    t = await store.setEvidence(t.id, jpeg());
    expect(t.outputs.single.requirementSource!.confirmed, false);
    await expectLater(
        store.confirmOutputSource(t.id, t.outputs.single.id, 'old',
            expectedEvidenceRevision: 1, expectedRevision: 2),
        throwsStateError);
  });
  test('confirmation rejects changed output and no screenshot', () async {
    var t = await store.create(name: 'Task');
    t = await store.addOutput(t.id, requirement(), 'main');
    await expectLater(
        store.confirmOutputSource(t.id, t.outputs.single.id, 'text',
            expectedEvidenceRevision: 0, expectedRevision: 0),
        throwsStateError);
    expect(
        ApplicationTask.fromJson(t.toJson()).outputs.single.requirementSource,
        isNull);
  });
  test('confirmation cannot claim evidence that is missing on disk', () async {
    var t = await store.create(name: 'Task');
    t = await store.setEvidence(t.id, jpeg());
    t = await store.addOutput(t.id, requirement(), 'main');
    await store.evidenceFile(t).delete();
    await expectLater(
        store.confirmOutputSource(t.id, t.outputs.single.id, 'Width 100px',
            expectedEvidenceRevision: 1, expectedRevision: 0),
        throwsStateError);
    await expectLater(
        store.addConfirmedOutput(t.id, requirement(), 'extra', 'Width 100px',
            expectedEvidenceRevision: 1),
        throwsStateError);
  });
  test('broken demo assets rebuild without deleting the damaged user task',
      () async {
    Future<ApplicationTask> make() => store.createDemo(
        name: 'Demo',
        notes: 'Fictional',
        source: jpeg(),
        evidence: jpeg(),
        outputs: [(requirement(), 'main')]);
    final first = await make();
    await store.sourceFile(first).writeAsBytes([]);
    final next = await make();
    expect(next.id, isNot(first.id));
    expect((await store.list()).length, 2);
  });
  test(
      'mid-transaction demo write failure rolls back staging and preserves user tasks',
      () async {
    final user = await store.create(name: 'User task');
    var writes = 0;
    final failing =
        ApplicationTaskStore(dir, demoAssetWriter: (file, bytes) async {
      if (++writes == 2) throw const FileSystemException('disk full');
      await file.writeAsBytes(bytes);
    });
    await expectLater(
        failing.createDemo(
            name: 'Demo',
            notes: '',
            source: jpeg(),
            evidence: jpeg(),
            outputs: [(requirement(), 'main')]),
        throwsA(isA<FileSystemException>()));
    expect((await store.list()).map((t) => t.id), [user.id]);
    expect(
        await Directory('${dir.path}/tasks')
            .list()
            .where((e) => e.path.contains('.demo_'))
            .length,
        0);
    expect((await store.create(name: 'After failure')).name, 'After failure');
  });
  test('demo is ordinary, incomplete, idempotent and rebuilt after deletion',
      () async {
    final user = await store.create(name: 'User');
    Future<ApplicationTask> make() => store.createDemo(
        name: 'Demo',
        notes: 'Fictional',
        source: jpeg(),
        evidence: jpeg(),
        outputs: [(requirement(), 'main'), (requirement(), 'profile')]);
    final a = await make();
    final b = await make();
    expect(a.id, b.id);
    expect(a.isDemo, true);
    expect(a.complete, false);
    expect(a.outputs.length, 2);
    await store.delete(a.id);
    expect((await make()).id, isNot(a.id));
    expect((await store.get(user.id)).name, 'User');
    await expectLater(
        store.createDemo(
            name: 'Broken',
            notes: '',
            source: Uint8List(0),
            evidence: jpeg(),
            outputs: [(requirement(), 'main')]),
        throwsArgumentError);
    expect((await store.list()).length, 2);
  });
}
