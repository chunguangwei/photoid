import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/application_task.dart';
import 'application_task_store.dart';
import 'delivery_export_cache.dart';
import 'photo_file_inspection.dart';

class ApplicationDelivery {
  static Future<File> build(ApplicationTask task, ApplicationTaskStore store,
      Directory temporaryDirectory, String locale) async {
    return store.withTaskSnapshot(task.id, (snapshot) async {
      if (!snapshot.complete) {
        throw StateError('Complete all outputs before export');
      }
      final entries = <String, Uint8List>{};
      final zh = locale == 'zh';
      final readable = <String>[
        zh ? '报名文件交付清单' : 'Application photo delivery checklist',
        snapshot.name,
        if (snapshot.notes.isNotEmpty) snapshot.notes,
        if (snapshot.sourceReference.isNotEmpty)
          '${zh ? "要求来源（用户提供，未验证）" : "Requirements reference (user supplied, not verified)"}: ${snapshot.sourceReference}',
        if (snapshot.verifiedDate.isNotEmpty)
          '${zh ? "用户核对日期" : "User verification date"}: ${snapshot.verifiedDate}',
      ];
      var total = 0;
      for (final output in snapshot.outputs) {
        final file = store.outputFile(snapshot, output);
        final length = await file.length();
        total += length;
        if (length > 30 * 1024 * 1024 || total > 50 * 1024 * 1024) {
          throw StateError('Delivery exceeds size limit');
        }
        final bytes = await file.readAsBytes();
        final check =
            await compute(inspectPhotoFileWorker, (bytes, output.spec));
        if (!check.hardAllPass) throw StateError('Output failed file checks');
        entries['${output.fileName}.jpg'] = bytes;
        entries['${output.fileName}.checks.json'] = Uint8List.fromList(
            utf8.encode(const JsonEncoder.withIndent('  ').convert({
          'reportVersion': 1,
          'file': {'name': '${output.fileName}.jpg', ...check.toJson()},
          'requestedSpecification': output.spec.toJson(),
          'acceptanceGuaranteed': false,
          if (output.requirementSource != null)
            'requirementsSource': output.requirementSource!.toJson(),
        })));
        readable.add('${output.fileName}.jpg\n${check.readable(locale)}');
        final source = output.requirementSource;
        if (source != null) {
          readable.add(
              '${zh ? "要求摘录（来源未独立验证）" : "Requirements excerpt (source not independently verified)"}: ${source.excerpt}\n${source.confirmed ? (zh ? "用户已确认" : "User confirmed") : (zh ? "要求或来源已变更，需重新核对" : "Requirements or source changed; recheck required")}');
        }
      }
      // Replacing the source, changing a requirement or deleting a task during
      // generation invalidates this snapshot; never silently export old files.
      if (jsonEncode((await store.get(task.id)).toJson()) !=
          jsonEncode(snapshot.toJson())) {
        throw StateError('Task changed during export');
      }
      entries['CHECKLIST.txt'] = Uint8List.fromList(
          utf8.encode(readable.join('\n\n────────────────────\n\n')));
      final zipped = await compute(_zip, entries);
      await DeliveryExportCache(temporaryDirectory).cleanExpired();
      final root =
          Directory(p.join(temporaryDirectory.path, 'photoid_exports'));
      await root.create(recursive: true);
      final dir = await root.createTemp('bundle_');
      try {
        await File(p.join(dir.path, '.created')).writeAsString('');
        final file = await File(
                p.join(dir.path, 'photoid_${task.id.substring(0, 8)}.zip'))
            .writeAsBytes(zipped, flush: true);
        if (jsonEncode((await store.get(task.id)).toJson()) !=
            jsonEncode(snapshot.toJson())) {
          throw StateError('Task changed during export');
        }
        return file;
      } catch (_) {
        await dir.delete(recursive: true);
        rethrow;
      }
    });
  }
}

Uint8List _zip(Map<String, Uint8List> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}
