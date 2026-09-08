import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_spec.dart';

class PipelineException implements Exception {
  PipelineException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PipelineResult {
  PipelineResult({
    required this.jpgBytes,
    required this.originalBytes,
    required this.processed,
    required this.original,
  });

  /// 最终交付的 jpg 字节（已按规格压缩）
  final Uint8List jpgBytes;

  /// 原图预览字节（归一化后、工作分辨率）
  final Uint8List originalBytes;

  /// 处理后的成片（规格像素）
  final img.Image processed;

  /// 归一化后的原图（工作分辨率，用于原图/效果对比）
  final img.Image original;
}

/// 处理流水线：EXIF 归一化 → 抠图 → 底色合成 → 人脸构图裁剪 → 二分压缩。
/// 全流程端侧执行，无网络请求。
class ImagePipeline {
  ImagePipeline({this.onProgress});

  final void Function(String step)? onProgress;

  /// 工作图最长边。输出只有几百像素，1440 足够且保证合成速度。
  static const _maxWorkSide = 1440;

  Future<PipelineResult> run(String sourcePath, PhotoSpec spec) async {
    // 1. 解码 + 按 EXIF 旋转归一化（image 包不保证自动应用方向）
    _report('正在读取照片…');
    final rawBytes = await File(sourcePath).readAsBytes();
    var work = img.decodeImage(rawBytes);
    if (work == null) {
      throw PipelineException('无法读取该照片，请换一张 JPG/PNG 图片');
    }
    work = img.bakeOrientation(work);
    if (work.width > _maxWorkSide || work.height > _maxWorkSide) {
      work = work.width >= work.height
          ? img.copyResize(work, width: _maxWorkSide)
          : img.copyResize(work, height: _maxWorkSide);
    }

    // ML Kit 输入文件：与 work 像素一致、无 EXIF，保证掩码/人脸框坐标对齐
    final dir = await getTemporaryDirectory();
    final mlFile = File(p.join(
        dir.path, 'photoid_ml_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await mlFile.writeAsBytes(img.encodeJpg(work, quality: 92));

    // 2. 人像分割
    _report('正在智能抠图…');
    final segmenter = SelfieSegmenter(
        mode: SegmenterMode.single, enableRawSizeMask: false);
    final segMask =
        await segmenter.processImage(InputImage.fromFile(mlFile));
    segmenter.close();
    if (segMask == null) {
      throw PipelineException('抠图失败，未识别到人物，请使用单人正脸照片');
    }

    // 掩码 → 灰度字节，缩放到工作图尺寸并羽化边缘
    final conf = segMask.confidences;
    var maskBytes = Uint8List(segMask.width * segMask.height);
    for (var i = 0; i < maskBytes.length; i++) {
      maskBytes[i] = (conf[i].clamp(0.0, 1.0) * 255).round();
    }
    var maskImg = img.Image.fromBytes(
        width: segMask.width,
        height: segMask.height,
        bytes: maskBytes.buffer,
        numChannels: 1);
    if (maskImg.width != work.width || maskImg.height != work.height) {
      maskImg = img.copyResize(maskImg,
          width: work.width,
          height: work.height,
          interpolation: img.Interpolation.linear);
    }
    maskImg = img.gaussianBlur(maskImg, radius: 3);
    final maskW = maskImg.getBytes();

    // 3. 底色合成（isolate 内做逐像素混合）
    _report('正在合成${spec.background.name}…');
    final outBytes = await compute(_composite, <String, Object>{
      'rgba': work.getBytes(order: img.ChannelOrder.rgba),
      'width': work.width,
      'height': work.height,
      'mask': maskW,
      'bg': Uint8List.fromList(
          [spec.background.r, spec.background.g, spec.background.b]),
    });
    final composited = img.Image.fromBytes(
        width: work.width,
        height: work.height,
        bytes: outBytes.buffer,
        numChannels: 4);

    // 4. 人脸检测 + 自动构图裁剪
    _report('正在检测人脸并构图…');
    final detector = FaceDetector(
        options:
            FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
    final faces = await detector.processImage(InputImage.fromFile(mlFile));
    detector.close();
    if (faces.isEmpty) {
      throw PipelineException('未检测到正脸，请重新拍摄：正对镜头、面部无遮挡');
    }
    final face = faces.reduce((a, b) =>
        a.boundingBox.width * a.boundingBox.height >=
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b);
    final framed = _frame(composited, face.boundingBox, spec);

    // 5. 缩放到目标像素并二分压缩到 KB 区间
    _report('正在压缩导出…');
    final output = img.copyResize(framed,
        width: spec.pixelWidth,
        height: spec.pixelHeight,
        interpolation: img.Interpolation.cubic);
    final jpg = encodeToKbRange(output, spec.minFileKb, spec.maxFileKb);

    mlFile.delete().ignore();
    return PipelineResult(
      jpgBytes: jpg,
      originalBytes: img.encodeJpg(work, quality: 88),
      processed: output,
      original: work,
    );
  }

  /// 以人脸框构图：头部（人脸框×1.5 补偿头顶）约占照片高 62%，
  /// 水平居中，顶部留白约 10%。画幅不足处用底色补齐。
  img.Image _frame(img.Image source, Rect face, PhotoSpec spec) {
    final bg = img.ColorRgb8(
        spec.background.r, spec.background.g, spec.background.b);
    final headH = face.height * 1.5;
    var cropH = headH / 0.62;
    var cropW = cropH * spec.aspect;
    // 画幅不能无限放大：限制在源图短边的 3 倍内，避免过度放大模糊
    final maxCrop = math.max(source.width, source.height) * 3.0;
    if (cropH > maxCrop) {
      cropH = maxCrop.toDouble();
      cropW = cropH * spec.aspect;
    }
    final cropWi = cropW.round();
    final cropHi = cropH.round();
    final cx = face.left + face.width / 2;
    final top = face.top - cropH * 0.10;
    final left = cx - cropW / 2;

    // 先向四周扩边（底色填充），再正坐标裁剪，避免越界
    final pad = cropHi;
    final canvas = img.Image(width: source.width + pad * 2, height: source.height + pad * 2);
    img.fill(canvas, color: bg);
    img.compositeImage(canvas, source, dstX: pad, dstY: pad);
    final cropX = (pad + left).round().clamp(0, canvas.width - cropWi).toInt();
    final cropY = (pad + top).round().clamp(0, canvas.height - cropHi).toInt();
    return img.copyCrop(canvas,
        x: cropX, y: cropY, width: cropWi, height: cropHi);
  }

  /// 二分 JPEG 质量，输出落在 [minKb, maxKb] 内（优先接近上限以下的最高质量）。
  static Uint8List encodeToKbRange(img.Image image, int minKb, int maxKb) {
    Uint8List best = img.encodeJpg(image, quality: 85);
    var lo = 20, hi = 98;
    for (var i = 0; i < 10 && lo <= hi; i++) {
      final q = (lo + hi) ~/ 2;
      final out = img.encodeJpg(image, quality: q);
      final kb = out.lengthInBytes / 1024;
      if (kb > maxKb) {
        hi = q - 1;
      } else {
        if (out.lengthInBytes >= best.lengthInBytes ||
            best.lengthInBytes / 1024 > maxKb) {
          best = out;
        }
        if (kb >= maxKb * 0.92) break; // 已接近上限
        lo = q + 1;
      }
    }
    // 仍超上限（极端情况）→ 降到目标质量以下重编码由调用方保证尺寸合理
    var guard = 0;
    while (best.lengthInBytes / 1024 > maxKb && guard++ < 6) {
      best = img.encodeJpg(image, quality: math.max(10, 85 - guard * 12));
    }
    return best;
  }

  void _report(String step) => onProgress?.call(step);
}

/// 逐像素 alpha 混合：out = fg·a + bg·(1-a)。顶层函数，供 compute 调用。
Uint8List _composite(Map<String, Object> args) {
  final rgba = args['rgba'] as Uint8List;
  final mask = args['mask'] as Uint8List;
  final bg = args['bg'] as Uint8List;
  final out = Uint8List(rgba.length);
  final br = bg[0], bgG = bg[1], bb = bg[2];
  for (var px = 0; px < mask.length; px++) {
    final i = px * 4;
    final a = mask[px];
    final inv = 255 - a;
    out[i] = (rgba[i] * a + br * inv) ~/ 255;
    out[i + 1] = (rgba[i + 1] * a + bgG * inv) ~/ 255;
    out[i + 2] = (rgba[i + 2] * a + bb * inv) ~/ 255;
    out[i + 3] = 255;
  }
  return out;
}
