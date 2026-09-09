import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_spec.dart';

class CheckItem {
  const CheckItem(this.id, this.pass, {this.detail, this.fixId, this.soft = false});

  /// 稳定语义标识（UI 层据此映射 l10n 键，service 文案改动不影响翻译）。
  /// 取值：format/fileSize/decodable/pixelSize/bestSize/ratio/blueBg/
  /// faceDetected/headRatio/headCentered/eyesOpen
  final String id;
  final bool pass;

  /// 实测值，如「486KB」「480×640」「3%」
  final String? detail;

  /// 不通过时的修复建议标识：fileTooLarge/fileTooSmall/fileCorrupt/
  /// sizeOutOfRange/ratioMismatch/notBlue/noFace/headRatio/notCentered/eyesClosed
  final String? fixId;

  /// 软指标（通知未明确要求，仅供参考）：不通过不阻断保存
  final bool soft;
}

class ComplianceReport {
  ComplianceReport(this.items);
  final List<CheckItem> items;

  bool get hardAllPass => items.where((e) => !e.soft).every((e) => e.pass);
}

/// 合规检测引擎：对最终 jpg 字节逐项校验规格要求。
class ComplianceService {
  Future<ComplianceReport> check(Uint8List jpgBytes, PhotoSpec spec) async {
    final items = <CheckItem>[];

    // 1. 文件格式（流水线恒定输出 jpg）
    items.add(const CheckItem('format', true));

    // 2. 文件大小
    final kb = jpgBytes.lengthInBytes / 1024;
    final kbOk = kb >= spec.minFileKb && kb <= spec.maxFileKb;
    items.add(CheckItem(
      'fileSize',
      kbOk,
      detail: '${kb.toStringAsFixed(0)}KB',
      fixId: kb > spec.maxFileKb ? 'fileTooLarge' : 'fileTooSmall',
    ));

    // 3. 像素尺寸
    final image = img.decodeJpg(jpgBytes);
    if (image == null) {
      items.add(const CheckItem('decodable', false, fixId: 'fileCorrupt'));
      return ComplianceReport(items);
    }
    final wOk = image.width >= spec.minWidth && image.width <= spec.maxWidth;
    final hOk = image.height >= spec.minHeight && image.height <= spec.maxHeight;
    items.add(CheckItem(
      'pixelSize',
      wOk && hOk,
      detail: '${image.width}×${image.height}',
      fixId: 'sizeOutOfRange',
    ));
    items.add(CheckItem(
      'bestSize',
      image.width == spec.pixelWidth && image.height == spec.pixelHeight,
      detail: '${image.width}×${image.height}',
      soft: true,
    ));

    // 4. 高/宽比例
    final ratio = image.height / image.width;
    final ratioOk = ratio >= spec.minRatio && ratio <= spec.maxRatio;
    items.add(CheckItem(
      'ratio',
      ratioOk,
      detail: ratio.toStringAsFixed(2),
      fixId: 'ratioMismatch',
    ));

    // 5. 背景色：四角采样判蓝
    final bg = _sampleCorners(image);
    final hsv = _rgbToHsv(bg.$1, bg.$2, bg.$3);
    final isBlue = hsv.$1 >= 190 && hsv.$1 <= 260 && hsv.$2 > 0.25;
    items.add(CheckItem(
      'blueBg',
      isBlue,
      detail: 'RGB(${bg.$1},${bg.$2},${bg.$3})',
      fixId: 'notBlue',
    ));
    // 6. 人脸与头部占比（软指标：通知未明确要求）
    items.addAll(await _faceChecks(image));

    return ComplianceReport(items);
  }

  /// 四角 8% 区域均值
  (int, int, int) _sampleCorners(img.Image image) {
    final s = (image.width * 0.08).round().clamp(4, image.width ~/ 3).toInt();
    final regions = [
      (0, 0),
      (image.width - s, 0),
      (0, image.height - s),
      (image.width - s, image.height - s),
    ];
    var r = 0, g = 0, b = 0, n = 0;
    for (final (ox, oy) in regions) {
      for (var y = oy; y < oy + s; y++) {
        for (var x = ox; x < ox + s; x++) {
          final px = image.getPixel(x, y);
          r += px.r.toInt();
          g += px.g.toInt();
          b += px.b.toInt();
          n++;
        }
      }
    }
    return (r ~/ n, g ~/ n, b ~/ n);
  }

  /// H ∈ [0,360), S,V ∈ [0,1]
  (double, double, double) _rgbToHsv(int r, int g, int b) {
    final rf = r / 255, gf = g / 255, bf = b / 255;
    final max = [rf, gf, bf].reduce((a, c) => a > c ? a : c);
    final min = [rf, gf, bf].reduce((a, c) => a < c ? a : c);
    final d = max - min;
    var h = 0.0;
    if (d > 0) {
      if (max == rf) {
        h = 60.0 * (((gf - bf) / d) % 6);
      } else if (max == gf) {
        h = 60.0 * ((bf - rf) / d + 2);
      } else {
        h = 60.0 * ((rf - gf) / d + 4);
      }
    }
    if (h < 0) h += 360;
    final s = max == 0 ? 0.0 : d / max;
    return (h, s, max);
  }

  Future<List<CheckItem>> _faceChecks(img.Image image) async {
    // 小图检测不到人脸，放大 2 倍再检
    final up = img.copyResize(image, width: image.width * 2);
    final dir = await getTemporaryDirectory();
    final f = File(p.join(
        dir.path, 'photoid_check_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await f.writeAsBytes(img.encodeJpg(up, quality: 90));
    final detector = FaceDetector(
        options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableClassification: true));
    try {
      final faces = await detector.processImage(InputImage.fromFile(f));
      if (faces.isEmpty) {
        return [
          const CheckItem('faceDetected', false,
              fixId: 'noFace', soft: true),
        ];
      }
      final face = faces.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >=
                  b.boundingBox.width * b.boundingBox.height
              ? a
              : b);
      // 放大坐标换回原始坐标
      final box = face.boundingBox;
      final headH = box.height / 2 * 1.5; // ×1.5 补偿头顶
      final headRatio = headH / image.height;
      final centerDev =
          ((box.left / 2 + box.width / 4) - image.width / 2).abs() /
              image.width;
      final ratioOk = headRatio >= 0.45 && headRatio <= 0.85;
      final centerOk = centerDev <= 0.08;
      final leftEye = face.leftEyeOpenProbability;
      final rightEye = face.rightEyeOpenProbability;
      final eyesOk = leftEye == null ||
          rightEye == null ||
          (leftEye > 0.4 && rightEye > 0.4);
      return [
        CheckItem('headRatio', ratioOk,
            detail: '${(headRatio * 100).toStringAsFixed(0)}%',
            fixId: 'headRatio',
            soft: true),
        CheckItem('headCentered', centerOk,
            detail: '${(centerDev * 100).toStringAsFixed(0)}%',
            fixId: 'notCentered',
            soft: true),
        CheckItem('eyesOpen', eyesOk, fixId: 'eyesClosed', soft: true),
      ];
    } finally {
      detector.close();
      f.delete().ignore();
    }
  }
}
