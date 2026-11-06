import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/application_task_store.dart';
import 'package:photoid/services/delivery_overview.dart';
import 'photo_file_inspection_test.dart' show requirement;

void main() {
  test('overview measures bytes and refuses missing/corrupt stale ready',
      () async {
    final dir = await Directory.systemTemp.createTemp('overview_');
    addTearDown(() => dir.delete(recursive: true));
    final store = ApplicationTaskStore(dir);
    var t = await store.create(name: 'Task');
    final bytes =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 140)));
    t = await store.setSource(t.id, bytes);
    t = await store.addOutput(t.id, requirement(), 'main');
    expect((await inspectTaskDelivery(t, store)).single.status,
        DeliveryStatus.unprepared);
    t = await store.saveOutput(t.id, t.outputs.single.id, bytes, requirement());
    var row = (await inspectTaskDelivery(t, store)).single;
    expect(row.status, DeliveryStatus.passed);
    expect(row.inspection!.byteCount, bytes.length);
    await store.outputFile(t, t.outputs.single).writeAsBytes([1, 2, 3]);
    expect((await inspectTaskDelivery(t, store)).single.status,
        DeliveryStatus.failed);
    await store.outputFile(t, t.outputs.single).delete();
    expect((await inspectTaskDelivery(t, store)).single.status,
        DeliveryStatus.missing);
  });
}
