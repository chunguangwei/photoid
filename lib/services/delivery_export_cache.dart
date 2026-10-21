import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Own the export copies instead of leaking plugin-generated UUID folders.
/// Keep recent exports so Android receivers can finish reading after sharing.
class DeliveryExportCache {
  DeliveryExportCache(Directory temporaryDirectory)
      : _root = Directory(p.join(temporaryDirectory.path, 'photoid_exports'));
  final Directory _root;

  Future<List<File>> prepare(
      {required String name,
      required Uint8List jpgBytes,
      required String report}) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(name)) {
      throw ArgumentError('Invalid export file name');
    }
    await _root.create(recursive: true);
    final dir = await _root.createTemp('bundle_');
    final jpeg = File(p.join(dir.path, '$name.jpg'));
    final checks = File(p.join(dir.path, '$name.checks.json'));
    await File(p.join(dir.path, '.created')).writeAsString('');
    await jpeg.writeAsBytes(jpgBytes, flush: true);
    await checks.writeAsString(report, flush: true);
    return [jpeg, checks];
  }

  Future<void> cleanExpired() async {
    if (!await _root.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is! Directory ||
          !p.basename(entity.path).startsWith('bundle_')) {
        continue;
      }
      final marker = File(p.join(entity.path, '.created'));
      final created = await marker.exists()
          ? await marker.lastModified()
          : (await entity.stat()).modified;
      if (created.isBefore(cutoff)) await entity.delete(recursive: true);
    }
  }
}
