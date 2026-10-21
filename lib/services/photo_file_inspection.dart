import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/photo_spec.dart';

class FilePropertyCheck {
  const FilePropertyCheck(this.id, this.passed, this.expected, this.actual);
  final String id;
  final bool passed;
  final String expected;
  final String actual;
  Map<String, Object> toJson() => {
        'id': id,
        'passed': passed,
        'expected': expected,
        'actual': actual,
      };
  String label(String locale) {
    const labels = {
      'format': ['JPEG format', 'JPEG 格式'],
      'decodable': ['Readable image', '图片可读取'],
      'fileSize': ['File size', '文件大小'],
      'pixelSize': ['Pixel dimensions', '像素尺寸'],
      'ratio': ['Height / width', '高宽比'],
    };
    return labels[id]?[locale == 'zh' ? 1 : 0] ?? id;
  }
}

class PhotoFileInspection {
  const PhotoFileInspection(
      {required this.byteCount,
      required this.format,
      required this.checks,
      this.width,
      this.height});
  final int byteCount;
  final int? width;
  final int? height;
  final String format;
  final List<FilePropertyCheck> checks;
  bool get hardAllPass => checks.isNotEmpty && checks.every((c) => c.passed);
  Map<String, Object?> toJson() => {
        'bytes': byteCount,
        'format': format,
        'width': width,
        'height': height,
        'passed': hardAllPass,
        'checks': checks.map((c) => c.toJson()).toList(),
        'acceptanceGuaranteed': false,
      };
  String readable(String locale) {
    final zh = locale == 'zh';
    return [
      for (final c in checks)
        '${c.passed ? (zh ? "符合" : "PASS") : (zh ? "未符合" : "FAIL")} · ${c.label(locale)}\n'
            '${zh ? "要求" : "Required"}: ${c.expected}\n${zh ? "实际" : "Actual"}: ${c.actual}',
      zh
          ? '仅检查文件属性，不验证身份、人像、底色或接收机构是否接受。'
          : 'File properties only. Identity, portrait, background and institutional acceptance are not verified.',
    ].join('\n\n');
  }
}

/// Inspect the selected bytes. Never transcode or change them.
/// Suitable for compute() through [inspectPhotoFileWorker].
PhotoFileInspection inspectPhotoFile(Uint8List bytes, PhotoSpec spec) {
  if (bytes.length > 30 * 1024 * 1024) {
    throw ArgumentError('Image exceeds 30 MB');
  }
  final isJpeg = bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  String format = isJpeg ? 'JPEG' : 'Other';
  img.Image? image;
  var tooLarge = false;
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info != null && info.width > 0 && info.height > 0) {
      if (info.width * info.height > 24000000) {
        tooLarge = true;
      } else {
        image = decoder!.decodeFrame(0);
      }
      if (!isJpeg && decoder is img.PngDecoder) format = 'PNG';
    }
  } catch (_) {
    image = null;
  }
  if (tooLarge) throw ArgumentError('Image exceeds 24 megapixels');
  final kb = bytes.length / 1024;
  final checks = <FilePropertyCheck>[
    FilePropertyCheck('format', isJpeg, 'JPEG', format),
    FilePropertyCheck(
        'fileSize',
        kb >= spec.minFileKb && (spec.maxFileKb == 0 || kb <= spec.maxFileKb),
        '${spec.minFileKb}–${spec.maxFileKb == 0 ? "∞" : spec.maxFileKb} KB',
        '${kb.toStringAsFixed(2)} KB (${bytes.length} bytes)'),
    FilePropertyCheck(
        'decodable', image != null, '✓', image == null ? '×' : '✓'),
  ];
  if (image != null) {
    final w = image.width, h = image.height;
    checks.add(FilePropertyCheck(
        'pixelSize',
        w >= spec.minWidth &&
            w <= spec.maxWidth &&
            h >= spec.minHeight &&
            h <= spec.maxHeight,
        '${spec.minWidth}–${spec.maxWidth} × ${spec.minHeight}–${spec.maxHeight} px',
        '$w × $h px'));
    final ratio = h / w;
    checks.add(FilePropertyCheck(
        'ratio',
        ratio >= spec.minRatio && ratio <= spec.maxRatio,
        '${spec.minRatio.toStringAsFixed(3)}–${spec.maxRatio.toStringAsFixed(3)}',
        ratio.toStringAsFixed(3)));
  }
  return PhotoFileInspection(
      byteCount: bytes.length,
      format: format,
      width: image?.width,
      height: image?.height,
      checks: checks);
}

PhotoFileInspection inspectPhotoFileWorker((Uint8List, PhotoSpec) request) =>
    inspectPhotoFile(request.$1, request.$2);
