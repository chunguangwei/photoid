import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/kb_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'real isolate compression preserves pixel dimensions and obeys KB maximum',
      () async {
    final dir = await Directory.systemTemp.createTemp('photoid_kb_test_');
    try {
      final file = File('${dir.path}/source.jpg');
      await file
          .writeAsBytes(img.encodeJpg(img.Image(width: 400, height: 600)));
      final result =
          await compute(compressPhotoWorker, (path: file.path, maxKb: 20));
      expect(result.bytes.length, inInclusiveRange(5 * 1024, 20 * 1024));
      expect((result.width, result.height), (400, 600));
      final decoded = img.decodeJpg(result.bytes)!;
      expect((decoded.width, decoded.height), (400, 600));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
