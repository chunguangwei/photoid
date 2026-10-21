import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/models/photo_spec.dart';
import 'photo_file_inspection_test.dart' show requirement;

void main() {
  late Directory dir;
  late ApplicationTaskStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('photoid_tasks_');
    store = ApplicationTaskStore(dir);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Uint8List jpeg() =>
      Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 140)));
  test('delivery snapshot blocks mutations until its work completes', () async {
    final t = await store.create(name: 'Task');
    final entered = Completer<void>();
    final release = Completer<void>();
    final snapshot = store.withTaskSnapshot(t.id, (task) async {
      entered.complete();
      await release.future;
      return task.name;
    });
    await entered.future;
    var changed = false;
    final mutation = store
        .updateMetadata(t.id,
            name: 'Changed', notes: '', sourceReference: '', verifiedDate: '')
        .then((_) => changed = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(changed, isFalse);
    release.complete();
    expect(await snapshot, 'Task');
    await mutation;
    expect((await store.get(t.id)).name, 'Changed');
  });
  test(
      'replacing evidence uses a new image path to avoid stale cached screenshots',
      () async {
    final t = await store.create(name: 'Task');
    final first = await store.setEvidence(t.id, jpeg());
    final second = await store.setEvidence(t.id, jpeg());
    expect(
        store.evidenceFile(first).path, isNot(store.evidenceFile(second).path));
    expect(await store.evidenceFile(second).exists(), isTrue);
  });
  test('task metadata, source and multiple requirements survive reopening',
      () async {
    final task = await store.create(
        name: 'Autumn application',
        notes: 'JPEG only',
        sourceReference: 'https://example.com/rules',
        verifiedDate: '2026-10-21');
    await store.setSource(task.id, jpeg());
    await Future.wait([
      store.addOutput(task.id, requirement(), 'one'),
      store.addOutput(task.id, requirement(), 'two')
    ]);
    final reopened = await ApplicationTaskStore(dir).get(task.id);
    expect(reopened.outputs.length, 2);
    expect(reopened.notes, 'JPEG only');
    expect(reopened.verifiedDate, '2026-10-21');
    expect(await store.sourceFile(reopened).readAsBytes(), jpeg());
  });
  test('renaming requirements and replacing source invalidate completed output',
      () async {
    final t = await store.create(name: 'Task');
    await store.setSource(t.id, jpeg());
    final withOutput = await store.addOutput(t.id, requirement(), 'one');
    final output = withOutput.outputs.single;
    await store.saveOutput(t.id, output.id, jpeg(), requirement());
    expect((await store.get(t.id)).outputs.single.ready, isTrue);
    await store.updateOutput(t.id, output.id, requirement(), 'renamed');
    expect((await store.get(t.id)).outputs.single.ready, isFalse);
    await store.saveOutput(t.id, output.id, jpeg(), requirement());
    await store.setSource(t.id, jpeg());
    expect((await store.get(t.id)).outputs.single.ready, isFalse);
  });
  test('unsafe, duplicate names and more than five outputs are rejected',
      () async {
    final t = await store.create(name: 'Task');
    await expectLater(
        store.addOutput(t.id, requirement(), '../evil'), throwsArgumentError);
    await store.addOutput(t.id, requirement(), 'One');
    await expectLater(
        store.addOutput(t.id, requirement(), 'one'), throwsArgumentError);
    for (var i = 1; i < 5; i++) {
      await store.addOutput(t.id, requirement(), 'photo_$i');
    }
    await expectLater(
        store.addOutput(t.id, requirement(), 'six'), throwsStateError);
    await expectLater(store.get('../other'), throwsArgumentError);
  });
  test('changed background or noncompliant bytes cannot complete a requirement',
      () async {
    final t = await store.create(name: 'Task');
    await store.setSource(t.id, jpeg());
    final next = await store.addOutput(t.id, requirement(), 'one');
    await expectLater(
        store.saveOutput(
            t.id, next.outputs.single.id, Uint8List(4), requirement()),
        throwsStateError);
    final changed = requirement()
        .copyWith(background: const SpecBackground('other', 1, 2, 3));
    await expectLater(
        store.saveOutput(t.id, next.outputs.single.id, jpeg(), changed),
        throwsStateError);
  });
  test(
      'corrupt single task is isolated and deleting task preserves external original',
      () async {
    final original = File('${dir.path}/external.jpg');
    await original.writeAsBytes(jpeg());
    final t = await store.create(name: 'Good');
    await store.setSource(t.id, await original.readAsBytes());
    await Directory('${dir.path}/tasks/bad').create(recursive: true);
    await File('${dir.path}/tasks/bad/task.json')
        .writeAsString(jsonEncode({'broken': true}));
    expect((await store.list()).map((t) => t.name), ['Good']);
    await store.delete(t.id);
    expect(await original.exists(), isTrue);
    expect(await store.list(), isEmpty);
  });
}
