import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_spec.dart';

/// 流水线处理步骤（UI 层据此映射 l10n 键，文案改动不影响翻译）。
enum PipelineStep { preparing, reading, segmenting, compositing, framing, compressing }

class PipelineException implements Exception {
  PipelineException(this.code);
  final String code;
  @override
  String toString() => code;
}

class PipelineResult {
  PipelineResult({
    required this.jpgBytes,
    required this.originalBytes,
    required this.processed,
    required this.original,
    required this.composited,
    required this.compositedJpg,
    required this.autoCrop,
  });

  /// 最终交付的 jpg 字节（已按规格压缩，自动构图）
  final Uint8List jpgBytes;

  /// 原图预览字节（归一化后、工作分辨率）
  final Uint8List originalBytes;

  /// 处理后的成片（规格像素，自动构图）
  final img.Image processed;

  /// 归一化后的原图（工作分辨率，用于原图/效果对比）
  final img.Image original;

  /// 换底后的完整工作图（交互裁剪编辑器的底图）
  final img.Image composited;

  /// composited 的 JPEG 预览字节（编辑器显示用）
  final Uint8List compositedJpg;

  /// 自动构图裁剪框（composited 坐标系），编辑器的初始变换
  final Rect autoCrop;
}

/// 处理流水线：EXIF 归一化 → 抠图 → 底色合成 → 人脸构图裁剪 → 二分压缩。
/// 全流程端侧执行，无网络请求。
class ImagePipeline {
  ImagePipeline({this.onProgress});

  final void Function(PipelineStep step)? onProgress;

  /// 工作图最长边。输出只有几百像素，1440 足够且保证合成速度。
  static const _maxWorkSide = 1440;

  Future<PipelineResult> run(String sourcePath, PhotoSpec spec,
      {bool flipHorizontal = false}) async {
    // 1. 解码 + 按 EXIF 旋转归一化（image 包不保证自动应用方向）
    _report(PipelineStep.reading);
    final rawBytes = await File(sourcePath).readAsBytes();
    var work = img.decodeImage(rawBytes);
    if (work == null) {
      throw PipelineException('readPhoto');
    }
    work = img.bakeOrientation(work);
    // 前置摄像头预览是镜像，takePicture 输出为传感器原始方向，需水平翻转对齐用户所见
    if (flipHorizontal) work = img.flipHorizontal(work);
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
    _report(PipelineStep.segmenting);
    final segmenter = SelfieSegmenter(
        mode: SegmenterMode.single, enableRawSizeMask: false);
    final segMask = await _withMlKitFallback(segmenter.processImage, mlFile, work);
    segmenter.close();
    if (segMask == null) {
      throw PipelineException('noPerson');
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
    // 掩码后处理（消白边三件套）：
    // 1) 置信度锐化：低 alpha 截断——半透明环带混的是原背景色（白边来源）
    // 2) 3×3 腐蚀 1px：再削一圈残留边缘
    // 3) 轻度羽化：保证边缘过渡自然
    maskImg = img.gaussianBlur(maskImg, radius: 3);
    final maskW = await compute(_refineMask, <String, Object>{
      'mask': maskImg.getBytes(),
      'width': work.width,
      'height': work.height,
    });
    _report(PipelineStep.compositing);
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
    _report(PipelineStep.framing);
    final detector = FaceDetector(
        options:
            FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
    final faces = await _withMlKitFallback(detector.processImage, mlFile, work);
    detector.close();
    if (faces.isEmpty) {
      throw PipelineException('noFace');
    }
    final face = faces.reduce((a, b) =>
        a.boundingBox.width * a.boundingBox.height >=
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b);
    final autoCrop = _cropRect(composited, face.boundingBox, spec);
    final framed = img.copyCrop(composited,
        x: autoCrop.left.round(),
        y: autoCrop.top.round(),
        width: autoCrop.width.round(),
        height: autoCrop.height.round());

    // 5. 缩放到目标像素并二分压缩到 KB 区间
    _report(PipelineStep.compressing);
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
      composited: composited,
      compositedJpg: img.encodeJpg(composited, quality: 90),
      autoCrop: autoCrop,
    );
  }

  /// 以人脸框计算构图裁剪框（不扩边）：头部（人脸框×1.5 补偿头顶）约占
  /// 照片高 62%，水平居中，顶部留白约 10%。
  /// crop 超出图像时先等比缩到图内、再平移回界内——填充优先：
  /// 已合规的照片不会被缩出一圈底色边。
  static Rect cropRectFor(
      int srcW, int srcH, Rect face, double aspect) {
    final headH = face.height * 1.5;
    var cropH = headH / 0.62;
    var cropW = cropH * aspect;
    // 画幅不能无限放大：限制在源图短边的 3 倍内，避免过度放大模糊
    final maxCrop = math.max(srcW, srcH) * 3.0;
    if (cropH > maxCrop) {
      cropH = maxCrop.toDouble();
      cropW = cropH * aspect;
    }
    // 超出图像则等比缩到能放下
    final fit = math.min(srcW / cropW, srcH / cropH);
    if (fit < 1) {
      cropW *= fit;
      cropH *= fit;
    }
    final cropWi = cropW.round().clamp(1, srcW);
    final cropHi = cropH.round().clamp(1, srcH);
    final cx = face.left + face.width / 2;
    // 先补偿头顶（face.height×0.5）再留 10% 白边
    final top = face.top - face.height * 0.5 - cropH * 0.10;
    final left = cx - cropW / 2;
    final x = left.round().clamp(0, srcW - cropWi).toDouble();
    final y = top.round().clamp(0, srcH - cropHi).toDouble();
    return Rect.fromLTWH(x, y, cropWi.toDouble(), cropHi.toDouble());
  }

  Rect _cropRect(img.Image source, Rect face, PhotoSpec spec) =>
      cropRectFor(source.width, source.height, face, spec.aspect);

  /// 二分 JPEG 质量压到 maxKb 以下（优先接近上限的最高质量）。
  /// 契约：minKb 仅尽力而为——极小像素图（如 144×192）即使 q98 也可能
  /// 达不到下限，此时输出最高可用质量；规格数据的下限须符合可达性。
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

  void _report(PipelineStep step) => onProgress?.call(step);

  /// 双通路执行 ML Kit 任务：NV21 为主，PlatformException 时回退 fromFile。
  /// 背景：fromFilePath 在部分机型 NPE（不挂 MediaImage）；NV21 在华为等
  /// 无 GMS/受限设备上又报 internal error——两路互备覆盖两类故障。
  Future<T> _withMlKitFallback<T>(
      Future<T> Function(InputImage input) task,
      File file,
      img.Image work) async {
    if (!Platform.isAndroid) return task(InputImage.fromFile(file));
    try {
      return await task(await _inputImage(file, work));
    } on PlatformException {
      return task(InputImage.fromFile(file));
    }
  }

  /// 构造 NV21 输入图像（仅 Android）。
  Future<InputImage> _inputImage(File file, img.Image work) async {
    final nv21 = await compute(rgbaToNv21, <String, Object>{
      'rgba': work.getBytes(order: img.ChannelOrder.rgba),
      'width': work.width,
      'height': work.height,
    });
    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(work.width.toDouble(), work.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: work.width,
      ),
    );
  }
}

/// RGBA → NV21（BT.601 全幅转换，2×2 色度子采样）。顶层函数，供 compute 调用。
Uint8List rgbaToNv21(Map<String, Object> args) {
  final rgba = args['rgba'] as Uint8List;
  final w = args['width'] as int;
  final h = args['height'] as int;
  final ySize = w * h;
  // 色度 2×2 子采样：奇数宽/高按 ceil 分配，否则 RangeError
  final out = Uint8List(ySize + ((w + 1) ~/ 2) * ((h + 1) ~/ 2) * 2);
  for (var i = 0; i < ySize; i++) {
    final o = i * 4;
    out[i] =
        ((66 * rgba[o] + 129 * rgba[o + 1] + 25 * rgba[o + 2] + 128) >> 8) + 16;
  }
  var uv = ySize;
  for (var y = 0; y < h; y += 2) {
    for (var x = 0; x < w; x += 2) {
      final o = (y * w + x) * 4;
      final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2];
      out[uv++] = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128; // V
      out[uv++] = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128; // U
    }
  }
  return out;
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


/// 掩码精修（消白边）：锐化 alpha 曲线 → 3×3 min-filter 腐蚀 1px → 边缘保留羽化。
/// 顶层函数，供 compute 调用。
Uint8List _refineMask(Map<String, Object> args) {
  final mask = args['mask'] as Uint8List;
  final w = args['width'] as int;
  final h = args['height'] as int;
  final n = w * h;

  // 1) alpha 锐化：a' = clamp((a-0.35)/(1-0.5))，0.35 以下的半透明环归零
  final sharpened = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final a = mask[i] / 255.0;
    final s = ((a - 0.35) / 0.5).clamp(0.0, 1.0);
    sharpened[i] = (s * 255).round();
  }

  // 2) 3×3 min-filter 腐蚀一圈
  final eroded = Uint8List.fromList(sharpened);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      var m = 255;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final v = sharpened[(y + dy) * w + (x + dx)];
          if (v < m) m = v;
        }
      }
      eroded[y * w + x] = m;
    }
  }

  // 3) 羽化：仅对中间 alpha（非全 0 非全 255）做 3×3 均值，平滑边缘锯齿
  final out = Uint8List.fromList(eroded);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final c = eroded[y * w + x];
      if (c == 0 || c == 255) continue;
      var sum = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          sum += eroded[(y + dy) * w + (x + dx)];
        }
      }
      out[y * w + x] = sum ~/ 9;
    }
  }
  return out;
}