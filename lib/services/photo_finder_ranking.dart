import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/application_task.dart';
import 'photo_finder_models.dart';

FinderCandidate evaluatePhoto(
    FinderAnalysis a, List<ApplicationOutput> outputs) {
  if (a.skip != null) {
    return FinderCandidate(a, FinderGroup.unknown, [a.skip!], [], 0, 0);
  }
  if (a.width <= 0 || a.height <= 0) {
    return FinderCandidate(a, FinderGroup.unknown, ['unreadable'], [], 0, 0);
  }
  if (outputs.isEmpty) {
    return FinderCandidate(
        a, FinderGroup.unknown, ['noRequirements'], [], 0, 0);
  }
  if (a.faces.isEmpty) {
    return FinderCandidate(
        a, FinderGroup.unknown, ['noFaceDetected'], [], 0, 0);
  }
  final faces = a.faces
      .where((f) =>
          f.width > 0 &&
          f.height > 0 &&
          [f.left, f.top, f.width, f.height].every((v) => v.isFinite))
      .toList();
  if (faces.isEmpty) {
    return FinderCandidate(a, FinderGroup.unknown, ['unreadable'], [], 0, 0);
  }
  faces.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
  final f = faces.first;
  final reasons = <String>[];
  if (faces.length != a.faces.length ||
      f.left < 0 ||
      f.top < 0 ||
      f.left + f.width > 1 ||
      f.top + f.height > 1) {
    reasons.add('detectionUnknown');
  }
  if (faces.length > 1) reasons.add('multipleFaces');
  if (f.yaw == null ||
      f.roll == null ||
      !f.yaw!.isFinite ||
      !f.roll!.isFinite) {
    reasons.add('poseUnknown');
  } else if (f.yaw!.abs() > 15 || f.roll!.abs() > 12) {
    reasons.add('turnedFace');
  }
  if (math.min(f.width * a.width, f.height * a.height) < 160) {
    reasons.add('smallFace');
  }
  if (a.sharpness == null ||
      a.brightness == null ||
      !a.sharpness!.isFinite ||
      !a.brightness!.isFinite) {
    reasons.add('qualityUnknown');
  } else {
    if (a.sharpness! < 45) reasons.add('softImage');
    if (a.brightness! < 45 || a.brightness! > 220) reasons.add('exposure');
  }
  final crops = <FinderCrop>[];
  for (final o in outputs.take(5)) {
    final ratio = o.spec.pixelWidth / o.spec.pixelHeight;
    var h = (f.height * 2).clamp(.05, 1.0), w = h * a.height / a.width * ratio;
    if (w > 1) {
      h /= w;
      w = 1;
    }
    final x = (f.left + f.width / 2 - w / 2).clamp(0.0, 1 - w);
    final y = (f.top + f.height / 2 - h * .42).clamp(0.0, 1 - h);
    final pw = (w * a.width).floor(), ph = (h * a.height).floor();
    crops.add(FinderCrop(o.fileName, x, y, w, h, pw, ph,
        pw >= o.spec.pixelWidth && ph >= o.spec.pixelHeight));
  }
  if (crops.any((c) =>
      c.left > f.left + 1e-6 ||
      c.top > f.top + 1e-6 ||
      c.left + c.width < f.left + f.width - 1e-6 ||
      c.top + c.height < f.top + f.height - 1e-6)) {
    reasons.add('cropFraming');
  }
  final coverage = crops.where((c) => c.fits).length;
  if (coverage < crops.length) reasons.add('cropPixels');
  final group = coverage < crops.length
      ? FinderGroup.pixels
      : reasons.isNotEmpty
          ? FinderGroup.manual
          : FinderGroup.priority;
  if (group == FinderGroup.priority) reasons.add('singleFrontal');
  return FinderCandidate(
      a,
      group,
      reasons,
      crops,
      coverage,
      coverage * 1000 +
          (faces.length == 1 ? 100 : 0) -
          reasons.length * 10 +
          math.min(f.width * a.width, 2000) / 100);
}

/// Quality is measured on a bounded thumbnail, not inferred by a generative model.
(double, double)? finderImageQuality((Uint8List, List<FinderFace>) input) {
  final (bytes, faces) = input;
  final d = img.findDecoderForData(bytes);
  final info = d?.startDecode(bytes);
  if (info == null || info.width * info.height > 1280 * 1280) return null;
  final image = d!.decodeFrame(0);
  if (image == null || image.width < 3 || image.height < 3) return null;
  double sum = 0, squares = 0, brightness = 0;
  var count = 0;
  double gray(int x, int y) {
    final p = image.getPixel(x, y);
    return .299 * p.r + .587 * p.g + .114 * p.b;
  }

  // Face-region measurements avoid a sharp background masking a blurred portrait.
  if (faces.length != 1) return null;
  final f = faces.single;
  if (![f.left, f.top, f.width, f.height].every((v) => v.isFinite)) return null;
  final x0 = (f.left * image.width).round().clamp(1, image.width - 2);
  final x1 =
      ((f.left + f.width) * image.width).round().clamp(1, image.width - 2);
  final y0 = (f.top * image.height).round().clamp(1, image.height - 2);
  final y1 =
      ((f.top + f.height) * image.height).round().clamp(1, image.height - 2);
  for (var y = y0; y < y1; y += 3) {
    for (var x = x0; x < x1; x += 3) {
      final center = gray(x, y);
      final lap = gray(x - 1, y) +
          gray(x + 1, y) +
          gray(x, y - 1) +
          gray(x, y + 1) -
          4 * center;
      sum += lap;
      squares += lap * lap;
      brightness += center;
      count++;
    }
  }
  if (count == 0) return null;
  return (
    math.max(0, squares / count - math.pow(sum / count, 2)),
    brightness / count
  );
}
