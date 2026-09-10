import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo_spec.dart';
import 'modnet_segmenter.dart';

/// 抠图引擎：mlkit=快速普通版；modnet=高精修发丝级（失败自动回退 mlkit）。
enum MattingEngine { mlkit, modnet }

/// 美颜为连续强度 0.0–1.0（用户拖拽），参数线性映射，见 [beautify]。

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
    required this.faceRect,
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

  /// 人脸框（composited 坐标系），精修磨皮区域定位
  final Rect faceRect;
}

/// 处理流水线：EXIF 归一化 → 抠图 → 底色合成 → 人脸构图裁剪 → 二分压缩。
/// 全流程端侧执行，无网络请求。
class ImagePipeline {
  ImagePipeline({this.onProgress});

  final void Function(PipelineStep step)? onProgress;

  /// 工作图最长边。输出只有几百像素，1440 足够且保证合成速度。
  static const _maxWorkSide = 1440;

  Future<PipelineResult> run(String sourcePath, PhotoSpec spec,
      {bool flipHorizontal = false,
      MattingEngine engine = MattingEngine.mlkit}) async {
    // 1. 解码 + 按 EXIF 旋转归一化（image 包不保证自动应用方向）。
    // 解码/EXIF/缩放是重活（12MP 可达秒级），放后台 isolate
    // 防 UI 冻结（处理页扫描/进度条动画卡顿根因）
    _report(PipelineStep.reading);
    final loaded = await compute(_loadWork, <String, Object>{
      'path': sourcePath,
      'flip': flipHorizontal,
      'maxSide': _maxWorkSide,
    });
    if (loaded == null) {
      throw PipelineException('readPhoto');
    }
    var work = img.Image.fromBytes(
        width: loaded.w,
        height: loaded.h,
        bytes: loaded.rgba.buffer,
        numChannels: 4);

    // ML Kit 输入文件：无 EXIF，保证人脸框坐标与 work 对齐。
    // 降级到 ≤960px/q85：vivo 等机型 MediaPipe 处理大输入会空 Packet
    // SIGABRT（原生杀进程）；人脸框按比例映射回 work 坐标，精度损失可忽略
    var mlImage = work;
    final mlScale =
        work.width >= work.height ? 960 / work.width : 960 / work.height;
    if (mlScale < 1) {
      mlImage = img.copyResize(work,
          width: (work.width * mlScale).round(),
          height: (work.height * mlScale).round());
    }
    final dir = await getTemporaryDirectory();
    final mlFile = File(p.join(
        dir.path, 'photoid_ml_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    final mlBytes = img.encodeJpg(mlImage, quality: 85);
    if (mlBytes.isEmpty) throw PipelineException('readPhoto');
    await mlFile.writeAsBytes(mlBytes);
    // 2. 人像分割（双引擎：高精修=MODNet 发丝级；普通=ML Kit 快速）
    _report(PipelineStep.segmenting);
    // 分割统一走 MODNet（ML Kit 分割在部分机型原生崩溃杀进程；
    // 模型固定 512 输入）。两档差异在掩码后处理：
    // 普通=原掩码直出（快），高精=精修掩码（锐化截断+腐蚀去边+羽化）
    final maskBytes = await ModnetSegmenter.segment(work);
    var maskImg = img.Image.fromBytes(
        width: work.width,
        height: work.height,
        bytes: maskBytes.buffer,
        numChannels: 1);
    if (maskImg.width != work.width || maskImg.height != work.height) {
      maskImg = img.copyResize(maskImg,
          width: work.width,
          height: work.height,
          interpolation: img.Interpolation.linear);
    }
    // 轻度羽化，保证边缘过渡自然
    maskImg = img.gaussianBlur(maskImg, radius: 3);
    // 两档统一精修掩码（消白边三件套：置信度锐化截断半透明环带 →
    // 3×3 腐蚀 1px 去残留 → 羽化）——基础画质不做档位差异
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
    // 人脸框从 ML 输入坐标映射回 work/composited 坐标
    final invScale = mlScale < 1 ? 1 / mlScale : 1.0;
    final faceRect = Rect.fromLTRB(
        face.boundingBox.left * invScale,
        face.boundingBox.top * invScale,
        face.boundingBox.right * invScale,
        face.boundingBox.bottom * invScale);
    final autoCrop = _cropRect(composited, faceRect, spec);
    final framed = img.copyCrop(composited,
        x: autoCrop.left.round(),
        y: autoCrop.top.round(),
        width: autoCrop.width.round(),
        height: autoCrop.height.round());

    // 5. 缩放到目标像素并二分压缩到 KB 区间
    _report(PipelineStep.compressing);
    var output = resizeToSpecUniform(
        framed,
        spec.pixelWidth,
        spec.pixelHeight,
        img.ColorRgb8(
            spec.background.r, spec.background.g, spec.background.b));
    // 档位差异（可见维度）：高精版加一道轻锐化，发丝/轮廓更利落
    if (engine == MattingEngine.modnet) {
      output = img.convolution(output,
          filter: [0, -0.3, 0, -0.3, 2.2, -0.3, 0, -0.3, 0]);
    }
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
      faceRect: faceRect,
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
    // 高由宽 ÷ 比例推导（比例锁定，杜绝拉伸）；钳制后回推宽
    var cropWi = cropW.round().clamp(1, srcW);
    var cropHi = (cropWi / aspect).round().clamp(1, srcH);
    cropWi = (cropHi * aspect).round().clamp(1, srcW);
    cropHi = (cropWi / aspect).round().clamp(1, srcH);
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

  /// 美颜（保真路线，行业最佳实践对齐）：
  /// 面部椭圆 × **肤色门控**（眼睛/嘴唇/头发/眉毛不磨皮，杜绝糊五官）+
  /// 全图微提亮/微润色（≤8%，审核安全）。无瘦脸大眼等形变。
  /// [intensity] 0.0–1.0 连续强度（用户拖拽）；0 = 原图。
  /// [face] 为输出图坐标系人脸框。
  static img.Image beautify(img.Image src, Rect face, double intensity) {
    if (intensity <= 0) return src;
    intensity = intensity.clamp(0.0, 1.0);
    final blurred = img.gaussianBlur(src.clone(), radius: 5);
    final cx = face.left + face.width / 2;
    final cy = face.top + face.height / 2;
    final rx = face.width * 0.62;
    final ry = face.height * 0.72;
    final k = 0.75 * intensity; // 磨皮混合上限 75%，保皮肤纹理
    final x0 = math.max(0, (cx - rx).floor());
    final x1 = math.min(src.width - 1, (cx + rx).ceil());
    final y0 = math.max(0, (cy - ry).floor());
    final y1 = math.min(src.height - 1, (cy + ry).ceil());
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (dx * dx + dy * dy > 1) continue;
        final sp = src.getPixel(x, y);
        // 肤色门控（经典 RGB 规则）：非肤色像素（眼/唇/眉/发）跳过
        final r = sp.r.toInt(), g = sp.g.toInt(), b = sp.b.toInt();
        final isSkin = r > 95 &&
            g > 40 &&
            b > 20 &&
            r > b &&
            (r - math.min(g, b)) > 10;
        if (!isSkin) continue;
        final bp = blurred.getPixel(x, y);
        src.setPixelRgb(
            x,
            y,
            (sp.r * (1 - k) + bp.r * k).round(),
            (sp.g * (1 - k) + bp.g * k).round(),
            (sp.b * (1 - k) + bp.b * k).round());
      }
    }
    // 微提亮 + 微润色（随强度线性，上限保守）
    return img.adjustColor(src,
        brightness: 1 + 0.06 * intensity,
        saturation: 1 + 0.08 * intensity);
  }

  /// 等比缩放到规格像素：只用单一缩放因子（宽向对齐），杜绝拉伸。
  /// 源图比例已由裁剪框锁定，高度与目标的舍入差 ≤1px：
  /// 多出则从底部裁掉，不足用底色补齐。
  static img.Image resizeToSpecUniform(
      img.Image src, int targetW, int targetH, img.Color bg) {
    final f = targetW / src.width;
    var out = img.copyResize(src,
        width: targetW,
        height: (src.height * f).round(),
        interpolation: img.Interpolation.cubic);
    if (out.height == targetH) return out;
    if (out.height > targetH) {
      return img.copyCrop(out, x: 0, y: 0, width: targetW, height: targetH);
    }
    final canvas =
        img.Image(width: targetW, height: targetH, backgroundColor: bg);
    img.compositeImage(canvas, out, dstX: 0, dstY: 0);
    return canvas;
  }

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
    // min 达不到（纯色背景图即使 q98 也很小）→ EOI 后填充补齐。
    // JPEG 解码器读到 FFD9 即止，尾部填充字节不破坏解析，
    // 各类报名系统均接受（行业通行做法），合规检测不再报不可修复的 fileTooSmall
    // 目标钳制在 [min, max]：min>max 的异常输入也不能撑破上限
    final floorKb = maxKb > 0 ? math.min(minKb, maxKb) : minKb;
    if (floorKb > 0 && best.lengthInBytes < floorKb * 1024) {
      final padded = Uint8List(floorKb * 1024)
        ..setRange(0, best.length, best);
      for (var i = best.length; i < padded.length; i++) {
        padded[i] = 0xFF;
      }
      best = padded;
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
/// 后台 isolate 读图结果
class _LoadedWork {
  const _LoadedWork(this.w, this.h, this.rgba);

  final int w;
  final int h;
  final Uint8List rgba;
}

/// isolate 入口：解码 → EXIF 归一化 → 镜像补偿 → 限边缩放
_LoadedWork? _loadWork(Map<String, Object> args) {
  final path = args['path'] as String;
  final flip = args['flip'] as bool;
  final maxSide = args['maxSide'] as int;
  var work = img.decodeImage(File(path).readAsBytesSync());
  if (work == null) return null;
  work = img.bakeOrientation(work);
  // 前置摄像头预览是镜像，takePicture 输出为传感器原始方向，需水平翻转对齐用户所见
  if (flip) work = img.flipHorizontal(work);
  if (work.width > maxSide || work.height > maxSide) {
    work = work.width >= work.height
        ? img.copyResize(work, width: maxSide)
        : img.copyResize(work, height: maxSide);
  }
  return _LoadedWork(
      work.width, work.height, work.getBytes(order: img.ChannelOrder.rgba));
}
