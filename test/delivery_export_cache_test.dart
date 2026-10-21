import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/delivery_export_cache.dart';

void main() {
  test('exports preserve bytes/names and cleanup removes only expired bundles',
      () async {
    final root = await Directory.systemTemp.createTemp('photoid_export_test_');
    try {
      final cache = DeliveryExportCache(root);
      final old = await cache.prepare(
          name: 'applicant_123',
          jpgBytes: Uint8List.fromList([1, 2, 3]),
          report: '{"bytes":3}');
      expect(await old.first.readAsBytes(), [1, 2, 3]);
      expect(old.first.path.endsWith('/applicant_123.jpg'), isTrue);
      expect(old.last.path.endsWith('/applicant_123.checks.json'), isTrue);
      final marker = File('${old.first.parent.path}/.created');
      await marker
          .setLastModified(DateTime.now().subtract(const Duration(days: 2)));
      final fresh = await cache.prepare(
          name: 'new', jpgBytes: Uint8List(1), report: '{}');
      await cache.cleanExpired();
      expect(await old.first.exists(), isFalse);
      expect(await fresh.first.exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
