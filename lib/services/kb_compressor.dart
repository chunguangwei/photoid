import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_pipeline.dart';

/// Entire decode/orientation/JPEG loop runs in a compute isolate.
/// Return only output bytes and dimensions, not a second full decoded image.
({Uint8List bytes, int width, int height}) compressPhotoWorker(
    ({String path, int maxKb}) request) {
  if (request.maxKb < 5 || request.maxKb > 2048) {
    throw ArgumentError('KB target must be between 5 and 2048');
  }
  final decoded = img.decodeImage(File(request.path).readAsBytesSync());
  if (decoded == null) throw const FormatException('Unable to decode photo');
  final image = img.bakeOrientation(decoded);
  return (
    bytes: ImagePipeline.encodeToKbRange(image, 5, request.maxKb),
    width: image.width,
    height: image.height,
  );
}
