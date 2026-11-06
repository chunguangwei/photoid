import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/photo_spec.dart';
import 'photo_file_inspection.dart';

class RequirementsOcr {
  static const _channel = MethodChannel('photoid/requirements_ocr');
  static Future<String> recognize(String path) async {
    final file = File(path);
    if (await file.length() > 30 * 1024 * 1024) {
      throw ArgumentError('Image exceeds limit');
    }
    final bytes = await file.readAsBytes();
    final check =
        await compute(inspectPhotoFileWorker, (bytes, studentPhotoSpec));
    if (check.width == null) throw ArgumentError('Unreadable image');
    final text =
        await _channel.invokeMethod<String>('recognize', {'path': path});
    if (text == null || text.length > 100000) {
      throw StateError('Invalid recognition result');
    }
    return text;
  }
}
