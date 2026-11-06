import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/application_task_store.dart';
import 'photo_file_inspection_test.dart' show requirement;

void main() {
  test('stale imported screenshot cannot add any output', () async {
    final dir = await Directory.systemTemp.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    var t = await store.create(name: 'Task');
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 100, height: 140)));
    t = await store.setEvidence(t.id, bytes);
    t = await store.setEvidence(t.id, bytes);
    await expectLater(
        store.addConfirmedOutput(t.id, requirement(), 'main', 'Width 100px',
            expectedEvidenceRevision: 1),
        throwsStateError);
    expect((await store.get(t.id)).outputs, isEmpty);
    final next = await store.addConfirmedOutput(
        t.id, requirement(), 'main', 'Width 100px',
        expectedEvidenceRevision: 2);
    expect(next.outputs.single.requirementSource!.confirmed, true);
  });
}
