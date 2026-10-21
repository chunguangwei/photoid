import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/application_delivery.dart';
import 'photo_file_inspection_test.dart' show requirement;

void main() {
  late Directory dir;
  late ApplicationTaskStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('delivery_');
    store = ApplicationTaskStore(dir);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Uint8List jpeg() =>
      Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 140)));
  test('ZIP contains unchanged JPEGs, readable checklist and accurate JSON',
      () async {
    final t = await store.create(name: 'Autumn task', notes: 'School upload');
    await store.setSource(t.id, jpeg());
    final next = await store.addOutput(t.id, requirement(), 'applicant');
    await store.saveOutput(t.id, next.outputs.single.id, jpeg(), requirement());
    final zip = await ApplicationDelivery.build(
        await store.get(t.id), store, dir, 'en');
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(archive.findFile('applicant.jpg')!.content, jpeg());
    final report = jsonDecode(
        utf8.decode(archive.findFile('applicant.checks.json')!.content)) as Map;
    expect(report['file']['bytes'], jpeg().length);
    expect(report['acceptanceGuaranteed'], false);
    final checklist = utf8.decode(archive.findFile('CHECKLIST.txt')!.content);
    expect(checklist, contains('Autumn task'));
    expect(checklist, contains('100 × 140'));
    expect(checklist, contains('not verified'));
  });
  test('missing files and unfinished outputs cannot be exported', () async {
    final t = await store.create(name: 'Task');
    await store.setSource(t.id, jpeg());
    final next = await store.addOutput(t.id, requirement(), 'applicant');
    await expectLater(
        ApplicationDelivery.build(next, store, dir, 'en'), throwsStateError);
    final done = await store.saveOutput(
        t.id, next.outputs.single.id, jpeg(), requirement());
    await store.outputFile(done, done.outputs.single).delete();
    await expectLater(ApplicationDelivery.build(done, store, dir, 'en'),
        throwsA(isA<Exception>()));
  });
  test('export rechecks actual bytes instead of trusting saved ready flag',
      () async {
    final t = await store.create(name: 'Task');
    await store.setSource(t.id, jpeg());
    final next = await store.addOutput(t.id, requirement(), 'applicant');
    final done = await store.saveOutput(
        t.id, next.outputs.single.id, jpeg(), requirement());
    await store.outputFile(done, done.outputs.single).writeAsBytes([1, 2, 3]);
    await expectLater(
        ApplicationDelivery.build(done, store, dir, 'zh'), throwsStateError);
  });
  test('stale editor cannot save after source changes', () async {
    final t = await store.create(name: 'Task');
    await store.setSource(t.id, jpeg());
    final next = await store.addOutput(t.id, requirement(), 'applicant');
    final o = next.outputs.single;
    await store.setSource(t.id, jpeg());
    await expectLater(
        store.saveOutput(t.id, o.id, jpeg(), o.spec,
            expectedRevision: next.tokenFor(o)),
        throwsStateError);
  });
}
