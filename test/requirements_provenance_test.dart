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
