import 'package:flutter/foundation.dart';
import '../models/application_task.dart';
import 'application_task_store.dart';
import 'photo_file_inspection.dart';

enum DeliveryStatus { unprepared, missing, failed, passed }

class DeliveryOverviewItem {
  const DeliveryOverviewItem(this.output, this.status, [this.inspection]);
  final ApplicationOutput output;
  final DeliveryStatus status;
  final PhotoFileInspection? inspection;
}

Future<List<DeliveryOverviewItem>> inspectTaskDelivery(
        ApplicationTask task, ApplicationTaskStore store) =>
    store.withTaskSnapshot(task.id, (snapshot) async {
      final rows = <DeliveryOverviewItem>[];
      for (final o in snapshot.outputs) {
        if (!o.ready) {
          rows.add(DeliveryOverviewItem(o, DeliveryStatus.unprepared));
          continue;
        }
        final file = store.outputFile(snapshot, o);
        if (!await file.exists()) {
          rows.add(DeliveryOverviewItem(o, DeliveryStatus.missing));
          continue;
        }
        try {
          if (await file.length() > 30 * 1024 * 1024) {
            throw StateError('File exceeds limit');
          }
          final check = await compute(
              inspectPhotoFileWorker, (await file.readAsBytes(), o.spec));
          rows.add(DeliveryOverviewItem(
              o,
              check.hardAllPass ? DeliveryStatus.passed : DeliveryStatus.failed,
              check));
        } catch (_) {
          rows.add(DeliveryOverviewItem(o, DeliveryStatus.failed));
        }
      }
      return rows;
    });
