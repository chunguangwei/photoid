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
import 'photo_effects.dart';

/// 抠图引擎：两档均使用 MODNet，`modnet`（高精修）额外做一道轻锐化。
enum MattingEngine { mlkit, modnet }

/// 流水线处理步骤（UI 层据此映射 l10n 键，文案改动不影响翻译）。
enum PipelineStep { preparing, reading, segmenting, compositing, framing, compressing }

class PipelineException implements Exception {
  PipelineException(this.code);
  final String code;
  @override
  String toString() => code;
}

/// 成片交付参数（裁剪框 + 规格 + 效果强度）。
///
/// 独立成类是为了让「首次出片」「用户改裁剪框」「用户改美颜/清晰度」
/// 三条路径复用同一个 isolate 入口 [deliverWorker]——主 isolate 永远
/// 不碰像素，杜绝保存/调参瞬间的 UI 冻结。
@immutable
class DeliveryRequest {
  const DeliveryRequest({
    required this.rgba,
    required this.width,
    required this.height,
    required this.crop,
    required this.faceRect,
    required this.targetWidth,
    required this.targetHeight,
    required this.bg,
    required this.minKb,
    required this.maxKb,
    this.beauty = 0,
    this.clarity = 0,
    this.sharpen = false,
  });

  /// 换底后的完整工作图（RGBA）
  final Uint8List rgba;
  final int width;
  final int height;

  /// 裁剪框（工作图坐标系，**允许越界**：越界部分用底色补齐）
  final Rect crop;

  /// 人脸框（工作图坐标系），面部精修定位用
  final Rect faceRect;
  final int targetWidth;
  final int targetHeight;

  /// 底色 RGB
  final Uint8List bg;
  final int minKb;
  final int maxKb;
  final double beauty;
  final double clarity;

  /// 高精修档的轻锐化
  final bool sharpen;
}

class PipelineResult {
  const PipelineResult({
    required this.jpgBytes,
    required this.originalBytes,
    required this.compositedJpg,
    required this.compositedRgba,
    required this.compositedWidth,
    required this.compositedHeight,
    required this.autoCrop,
    required this.faceRect,
    required this.foreground,
    required this.alpha,
  });

  /// 最终交付的 jpg 字节（已按规格压缩，自动构图）
  final Uint8List jpgBytes;

  /// 原图预览字节（归一化后、工作分辨率）
  final Uint8List originalBytes;

  /// composited 的 JPEG 预览字节（编辑器显示用）
  final Uint8List compositedJpg;

  /// 换底后的完整工作图 RGBA（交互裁剪与效果重算的像素源）
  final Uint8List compositedRgba;
  final int compositedWidth;
  final int compositedHeight;

  /// 自动构图裁剪框（composited 坐标系，可能越界 → 交付时底色补齐）
  final Rect autoCrop;

  /// 人脸框（composited 坐标系）
  final Rect faceRect;

  /// 解混后的前景 RGBA 与掩码（composited 坐标系），供换底色秒切（`recolorWorker`）
  final Uint8List foreground;
  final Uint8List alpha;

  /// 换底色后的副本：只替换合成产物，构图框与掩码原样保留
  PipelineResult withBackground(RecolorResult r) => PipelineResult(
        jpgBytes: jpgBytes,
        originalBytes: originalBytes,
        compositedJpg: r.jpg,
        compositedRgba: r.rgba,
        compositedWidth: compositedWidth,
        compositedHeight: compositedHeight,
        autoCrop: autoCrop,
        faceRect: faceRect,
        foreground: foreground,
        alpha: alpha,
      );
}

/// 处理流水线：EXIF 归一化 → 抠图 → 底色合成 → 人脸构图裁剪 → 二分压缩。
/// 全流程端侧执行，无网络请求。
///
/// 线程模型（关键约束，勿回退）：主 isolate **不做任何像素级运算**。
/// 解码/抠图/精修掩码/合成/裁剪/缩放/编码全部在后台 isolate，
/// 主 isolate 只负责调度与进度上报——处理页的扫描动效与进度条
/// 因此能保持满帧。
class ImagePipeline {
  ImagePipeline({this.onProgress});

  final void Function(PipelineStep step)? onProgress;

  /// 工作图最长边。输出只有几百像素，1440 足够且保证合成速度。
  static const _maxWorkSide = 1440;

  Future<PipelineResult> run(String sourcePath, PhotoSpec spec,
      {bool flipHorizontal = false,
      MattingEngine engine = MattingEngine.mlkit,
      double beauty = 0,
      double clarity = 0}) async {
    // 1. 解码 + EXIF 归一化 + 限边缩放 + ML Kit 输入编码（全在 isolate）
    _report(PipelineStep.reading);
    final loaded = await compute(_loadWork, <String, Object>{
      'path': sourcePath,
      'flip': flipHorizontal,
      'maxSide': _maxWorkSide,
    });
    if (loaded == null || loaded.mlJpg.isEmpty) {
      throw PipelineException('readPhoto');
    }

    // ML Kit 输入文件：无 EXIF，保证人脸框坐标与 work 对齐。
    // 降级到 ≤960px/q85：vivo 等机型 MediaPipe 处理大输入会空 Packet
    // SIGABRT（原生杀进程）；人脸框按比例映射回 work 坐标，精度损失可忽略
    final dir = await getTemporaryDirectory();
    final mlFile = File(p.join(
        dir.path, 'photoid_ml_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await mlFile.writeAsBytes(loaded.mlJpg);

    try {
      // 2. 先做人脸检测，用它把工作图**粗裁到人像 ROI**，再送 MODNet。
      //
      //    MODNet 输入固定 512×512。整张全身照直接压过去，头肩区域在
      //    512 图里可能只剩几十像素，模型分不清「黑裙子」和「草地阴影」
      //    ——表现为换底后画面里残留成片的地面/背景色块，且这些块与人
      //    连通，连通域过滤也清不掉。先按构图所需范围裁一刀，人像在
      //    512 输入里的占比能提升数倍，边缘判别质量是量级差异。
      //    代价是人脸检测与抠图由并行改串行（人脸检测通常仅百毫秒级）。
      _report(PipelineStep.segmenting);
      final rawFace = await _detectFace(mlFile, loaded);
      final roi = matteRoiFor(loaded.w, loaded.h, rawFace, spec.aspect);

      Uint8List segRgba = loaded.rgba;
      var segW = loaded.w, segH = loaded.h;
      var faceRect = rawFace;
      if (roi != null) {
        final cut = await compute(cropRgbaWorker, <String, Object>{
          'rgba': loaded.rgba,
          'width': loaded.w,
          'height': loaded.h,
          'rect': roi,
        });
        segRgba = cut;
        segW = roi.width.round();
        segH = roi.height.round();
        faceRect = rawFace.translate(-roi.left, -roi.top);
      }

      final maskBytes = await ModnetSegmenter.segmentRgba(segRgba, segW, segH);

      // 3. 掩码精修 + 前景色解混 + 换底合成 + 自动构图 + 底色补边（isolate）
      _report(PipelineStep.compositing);
      final bgRgb = Uint8List.fromList(
          [spec.background.r, spec.background.g, spec.background.b]);
      final comp = await compute(_compositeWork, <String, Object>{
        'rgba': segRgba,
        'width': segW,
        'height': segH,
        'mask': maskBytes,
        'bg': bgRgb,
        'face': faceRect,
        'aspect': spec.aspect,
      });

      // 4. 裁剪 → 规格缩放 → 效果 → 二分压缩（isolate）
      _report(PipelineStep.framing);
      final jpg = await compute(
        deliverWorker,
        DeliveryRequest(
          rgba: comp.rgba,
          width: comp.width,
          height: comp.height,
          crop: comp.autoCrop,
          faceRect: comp.faceRect,
          targetWidth: spec.pixelWidth,
          targetHeight: spec.pixelHeight,
          bg: bgRgb,
          minKb: spec.minFileKb,
          maxKb: spec.maxFileKb,
          beauty: beauty,
          clarity: clarity,
          sharpen: engine == MattingEngine.modnet,
        ),
      );
      _report(PipelineStep.compressing);

      return PipelineResult(
        jpgBytes: jpg,
        originalBytes: comp.originalJpg,
        compositedJpg: comp.jpg,
        compositedRgba: comp.rgba,
        compositedWidth: comp.width,
        compositedHeight: comp.height,
        autoCrop: comp.autoCrop,
        faceRect: comp.faceRect,
        foreground: comp.foreground,
        alpha: comp.alpha,
      );
    } finally {
      mlFile.delete().ignore();
    }
  }

  /// 计算送进抠图模型前的**人像 ROI 粗裁框**；不值得裁时返回 null。
  ///
  /// 动机见 [run] 第 2 步：MODNet 输入恒为 512×512，全身照直接压过去会让
  /// 头肩只占几十像素。这里按「构图框 × [_roiMargin]」框出人像所在区域，
  /// 使模型输入里的人像占比大幅提升。
  ///
  /// 两条保守约束：
  /// - **只裁不补**：ROI 一定钳进源图内，绝不引入源图外的区域，
  ///   避免与后续「构图允许越界 + 底色补边」的坐标语义混淆；
  /// - **收益不足就不裁**：ROI 面积超过源图 72% 时说明本就是半身构图，
  ///   裁了不改善精度，反而白白多一次全图拷贝。
  static Rect? matteRoiFor(int srcW, int srcH, Rect face, double aspect) {
    /// 构图框外扩系数：留足头顶发饰、肩膀与手臂，避免 ROI 切掉真实人体
    /// 导致掩码在边界处被硬切（那会在成片里留下直线切痕）。
    const roiMargin = 1.45;

    final base = cropRectFor(srcW, srcH, face, aspect);
    final cx = base.center.dx, cy = base.center.dy;
    final halfW = base.width * roiMargin / 2;
    final halfH = base.height * roiMargin / 2;

    final left = math.max(0.0, cx - halfW);
    final top = math.max(0.0, cy - halfH);
    final right = math.min(srcW.toDouble(), cx + halfW);
    final bottom = math.min(srcH.toDouble(), cy + halfH);
    if (right - left < 32 || bottom - top < 32) return null;

    final roi = Rect.fromLTRB(
        left.roundToDouble(), top.roundToDouble(), right.roundToDouble(), bottom.roundToDouble());
    if (roi.width * roi.height > srcW * srcH * 0.72) return null;
    return roi;
  }

  /// 人脸检测（最大脸），返回 work 坐标系人脸框；未检出抛 `noFace`。
  Future<Rect> _detectFace(File mlFile, _LoadedWork loaded) async {
    final detector = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate));
    final List<Face> faces;
    try {
      faces = await _withMlKitFallback(detector.processImage, mlFile, loaded);
    } finally {
      detector.close();
    }
    if (faces.isEmpty) throw PipelineException('noFace');
    final face = faces.reduce((a, b) =>
        a.boundingBox.width * a.boundingBox.height >=
                b.boundingBox.width * b.boundingBox.height
            ? a
            : b);
    // 人脸框从 ML 输入坐标映射回 work 坐标
    final s = loaded.mlScale < 1 ? 1 / loaded.mlScale : 1.0;
    return Rect.fromLTRB(
        face.boundingBox.left * s,
        face.boundingBox.top * s,
        face.boundingBox.right * s,
        face.boundingBox.bottom * s);
  }

  /// 以「头顶 → 下巴」的真实头部高度计算构图裁剪框。
  ///
  /// 头部占成片高度 [_headRatio]，头顶留白 [_topMarginRatio]，水平居下巴中线。
  ///
  /// **关键设计：裁剪框允许越出源图**——越界部分在交付时用底色补齐。
  /// 背景已是纯色，补边完全不可见；而旧版把框钳进图内会直接切掉头顶或
  /// 肩膀（原图人物顶天立地时必然发生），这是「人物轮廓丢失」的主因。
  /// 唯一例外是**底边不补**：身体下方悬空一块纯色会很假，
  /// 因此底边超出时整体上移，宁可少一点头顶留白。
  static Rect cropRectFor(int srcW, int srcH, Rect face, double aspect,
      {double? headTop}) {
    /// 头部（头顶→下巴）占成片高度
    const headRatio = 0.62;

    /// 头顶到画面上沿的留白，占成片高度
    const topMarginRatio = 0.11;

    final chin = face.bottom;
    // 掩码头顶不可信（未传 / 高于人脸框太多，如举手、帽饰）时退回经验值：
    // ML Kit 框上沿约在额头中部，头顶再往上约 0.55 个脸高
    final crown = (headTop != null &&
            headTop < face.top &&
            headTop > face.top - face.height * 1.3)
        ? headTop
        : face.top - face.height * 0.55;

    final headH = math.max(1.0, chin - crown);
    var cropH = headH / headRatio;
    var cropW = cropH * aspect;

    // 画幅不能超过源图太多：越界部分要靠底色补边，补太多会让人物在纯色里
    // 「悬浮」，也会把工作图撑到数倍内存。1.5 倍足够覆盖极端大头照。
    final maxW = srcW * 1.5, maxH = srcH * 1.5;
    if (cropW > maxW || cropH > maxH) {
      final f = math.min(maxW / cropW, maxH / cropH);
      cropW *= f;
      cropH *= f;
    }

    // 宽高整数化，比例由宽推导后回推，杜绝舍入造成的拉伸
    var cropWi = math.max(1, cropW.round());
    var cropHi = math.max(1, (cropWi / aspect).round());
    cropWi = math.max(1, (cropHi * aspect).round());

    // 纵向：头顶上方留 topMarginRatio 的白
    var top = crown - cropHi * topMarginRatio;
    // 底边不补色：超出源图时整体上移（不足以完全容纳时贴底）
    if (top + cropHi > srcH) top = (srcH - cropHi).toDouble();
    // 顶边可以补色，但不允许把头顶推出画面
    if (top > crown) top = crown;

    // 横向：以下巴中线居中，两侧越界由底色补齐（纯背景，不可见）
    final left = (face.left + face.width / 2) - cropWi / 2;

    return Rect.fromLTWH(
        left.roundToDouble(), top.roundToDouble(), cropWi.toDouble(), cropHi.toDouble());
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
      final padded = Uint8List(floorKb * 1024)..setRange(0, best.length, best);
      for (var i = best.length; i < padded.length; i++) {
        padded[i] = 0xFF;
      }
      best = padded;
    }
    return best;
  }

  /// 底色补边裁剪：[crop] 可越界，越界区域填 [bg]。
  /// 换底后背景是纯色，所以补边与真实背景完全无缝。
  static img.Image paddedCrop(img.Image src, Rect crop, img.ColorRgb8 bg) {
    final w = math.max(1, crop.width.round());
    final h = math.max(1, crop.height.round());
    final x = crop.left.round();
    final y = crop.top.round();
    if (x >= 0 && y >= 0 && x + w <= src.width && y + h <= src.height) {
      return img.copyCrop(src, x: x, y: y, width: w, height: h);
    }
    final canvas = _filled(w, h, bg);
    // 源图与裁剪框的交集，整块搬到画布对应位置
    final sx = math.max(0, x);
    final sy = math.max(0, y);
    final ex = math.min(src.width, x + w);
    final ey = math.min(src.height, y + h);
    if (ex > sx && ey > sy) {
      final piece =
          img.copyCrop(src, x: sx, y: sy, width: ex - sx, height: ey - sy);
      img.compositeImage(canvas, piece, dstX: sx - x, dstY: sy - y);
    }
    return canvas;
  }

  /// 建一张**真正填充了底色**的画布。
  ///
  /// 坑：`img.Image(backgroundColor:)` 只是记录属性，并不会写像素，
  /// 直接用会得到全黑底——补边/补齐区域会出现黑边。必须显式 fill。
  static img.Image _filled(int w, int h, img.Color bg) =>
      img.fill(img.Image(width: w, height: h), color: bg);

  /// 等比缩放到规格像素：只用单一缩放因子（宽向对齐），杜绝拉伸。
  /// 源图比例已由裁剪框锁定，高度与目标的舍入差 ≤1px：
  /// 多出则从底部裁掉，不足用底色补齐。
  static img.Image resizeToSpecUniform(
      img.Image src, int targetW, int targetH, img.Color bg) {
    final f = targetW / src.width;
    final out = img.copyResize(src,
        width: targetW,
        height: math.max(1, (src.height * f).round()),
        interpolation: img.Interpolation.cubic);
    if (out.height == targetH) return out;
    if (out.height > targetH) {
      return img.copyCrop(out, x: 0, y: 0, width: targetW, height: targetH);
    }
    final canvas = _filled(targetW, targetH, bg);
    img.compositeImage(canvas, out, dstX: 0, dstY: 0);
    return canvas;
  }

  void _report(PipelineStep step) => onProgress?.call(step);

  /// 双通路执行 ML Kit 任务：NV21 为主，PlatformException 时回退 fromFile。
  /// 背景：fromFilePath 在部分机型 NPE（不挂 MediaImage）；NV21 在华为等
  /// 无 GMS/受限设备上又报 internal error——两路互备覆盖两类故障。
  Future<T> _withMlKitFallback<T>(Future<T> Function(InputImage input) task,
      File file, _LoadedWork loaded) async {
    if (!Platform.isAndroid) return task(InputImage.fromFile(file));
    try {
      final nv21 = await compute(rgbaToNv21, <String, Object>{
        'rgba': loaded.rgba,
        'width': loaded.w,
        'height': loaded.h,
      });
      return await task(InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(loaded.w.toDouble(), loaded.h.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: loaded.w,
        ),
      ));
    } on PlatformException {
      return task(InputImage.fromFile(file));
    }
  }
}

// ───────────────────────────── isolate 入口 ─────────────────────────────

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

/// 合成阶段产物（**已按自动构图框补好底色边**）。
///
/// 补边放在这里而不是交付时，是为了让工作图坐标系里的 [autoCrop] 永远
/// 落在图内：交互裁剪编辑器是「窗口固定、图片可缩放平移」的模型，
/// 表达不了越界的裁剪框——若不在此处补边，编辑器显示的初始构图会与
/// 实际成片对不上。补的是纯底色，与换底后的背景无缝。
class _Composited {
  const _Composited({
    required this.rgba,
    required this.width,
    required this.height,
    required this.jpg,
    required this.originalJpg,
    required this.autoCrop,
    required this.faceRect,
    required this.foreground,
    required this.alpha,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final Uint8List jpg;
  final Uint8List originalJpg;

  /// 自动构图框（已补边坐标系，保证不越界）
  final Rect autoCrop;

  /// 人脸框（已补边坐标系）
  final Rect faceRect;

  /// 解混后的前景 RGBA 与掩码（**均为已补边尺寸**），供换底色秒切复用
  final Uint8List foreground;
  final Uint8List alpha;
}

/// isolate 入口：按 [rect]（**必须已钳进源图内**）裁一块 RGBA 出来。
/// 供抠图前的人像 ROI 粗裁使用，见 `ImagePipeline.matteRoiFor`。
Uint8List cropRgbaWorker(Map<String, Object> args) {
  final rgba = args['rgba'] as Uint8List;
  final w = args['width'] as int;
  final rect = args['rect'] as Rect;
  final x = rect.left.round(), y = rect.top.round();
  final cw = rect.width.round(), ch = rect.height.round();
  final out = Uint8List(cw * ch * 4);
  final rowBytes = cw * 4;
  for (var row = 0; row < ch; row++) {
    final src = ((y + row) * w + x) * 4;
    out.setRange(row * rowBytes, (row + 1) * rowBytes, rgba, src);
  }
  return out;
}

/// isolate 入口：掩码精修 → 前景色解混 → 换底合成 → 自动构图 → 底色补边 → 预览编码。
_Composited _compositeWork(Map<String, Object> args) {
  final rgba = args['rgba'] as Uint8List;
  final w = args['width'] as int;
  final h = args['height'] as int;
  final bg = args['bg'] as Uint8List;
  final face = args['face'] as Rect;
  final aspect = args['aspect'] as double;
  final alpha = refineAlpha(args['mask'] as Uint8List, w, h);

  // 换底合成（前景色解混消白边，alpha 完整保留）
  final fg = decontaminate(rgba, alpha, w, h);
  final comp = Uint8List(w * h * 4);
  final br = bg[0], bgG = bg[1], bb = bg[2];
  for (var px = 0; px < alpha.length; px++) {
    final i = px * 4;
    final a = alpha[px];
    final inv = 255 - a;
    comp[i] = (fg[i] * a + br * inv) ~/ 255;
    comp[i + 1] = (fg[i + 1] * a + bgG * inv) ~/ 255;
    comp[i + 2] = (fg[i + 2] * a + bb * inv) ~/ 255;
    comp[i + 3] = 255;
  }

  // 自动构图：优先用掩码测得的真实发际线定位头顶
  final crop =
      ImagePipeline.cropRectFor(w, h, face, aspect, headTop: detectHeadTop(alpha, w, h));

  // 按构图框越界量补底色边，并把坐标系整体平移
  final padL = math.max(0, -crop.left.round());
  final padT = math.max(0, -crop.top.round());
  final padR = math.max(0, crop.right.round() - w);
  final padB = math.max(0, crop.bottom.round() - h);

  final original =
      img.Image.fromBytes(width: w, height: h, bytes: rgba.buffer, numChannels: 4);

  Uint8List outRgba = comp;
  var outW = w, outH = h;
  if (padL > 0 || padT > 0 || padR > 0 || padB > 0) {
    outW = w + padL + padR;
    outH = h + padT + padB;
    outRgba = Uint8List(outW * outH * 4);
    // 先铺满底色，再把合成图整块搬进去（逐行 setRange，比逐像素快得多）
    for (var i = 0; i < outRgba.length; i += 4) {
      outRgba[i] = br;
      outRgba[i + 1] = bgG;
      outRgba[i + 2] = bb;
      outRgba[i + 3] = 255;
    }
    final rowBytes = w * 4;
    for (var y = 0; y < h; y++) {
      final src = y * rowBytes;
      final dst = ((y + padT) * outW + padL) * 4;
      outRgba.setRange(dst, dst + rowBytes, comp, src);
    }
  }

  // 前景色与掩码也搬进补边坐标系：换底色时只需重新做一次 alpha 混合，
  // 不必重跑解码/抠图/构图（见 recolorWorker）。补边区 alpha=0 即纯底色。
  var outFg = fg;
  var outAlpha = alpha;
  if (outW != w || outH != h) {
    outFg = Uint8List(outW * outH * 4);
    outAlpha = Uint8List(outW * outH);
    final rowBytes = w * 4;
    for (var y = 0; y < h; y++) {
      final dstRow = (y + padT) * outW + padL;
      outFg.setRange(dstRow * 4, dstRow * 4 + rowBytes, fg, y * rowBytes);
      outAlpha.setRange(dstRow, dstRow + w, alpha, y * w);
    }
  }

  final shifted = crop.translate(padL.toDouble(), padT.toDouble());
  final composited = img.Image.fromBytes(
      width: outW, height: outH, bytes: outRgba.buffer, numChannels: 4);

  return _Composited(
    rgba: outRgba,
    width: outW,
    height: outH,
    jpg: img.encodeJpg(composited, quality: 90),
    originalJpg: img.encodeJpg(original, quality: 88),
    autoCrop: shifted,
    faceRect: face.translate(padL.toDouble(), padT.toDouble()),
    foreground: outFg,
    alpha: outAlpha,
  );
}

/// 换底色请求：只带前景/掩码与新底色，不含任何需要重新推理的东西。
class RecolorRequest {
  const RecolorRequest({
    required this.foreground,
    required this.alpha,
    required this.width,
    required this.height,
    required this.bg,
  });

  final Uint8List foreground;
  final Uint8List alpha;
  final int width;
  final int height;
  final Uint8List bg;
}

class RecolorResult {
  const RecolorResult({required this.rgba, required this.jpg});

  final Uint8List rgba;
  final Uint8List jpg;
}

/// isolate 入口：换底色。
///
/// 抠图掩码、解混后的前景色、构图框都与底色无关，所以换底只是**一次
/// alpha 混合**（O(n)，几十毫秒）。早期实现是整条流水线重跑——包括最贵的
/// MODNet 推理——用户每点一次色块都要重新等一遍进度条，纯属浪费。
RecolorResult recolorWorker(RecolorRequest req) {
  final w = req.width, h = req.height;
  final fg = req.foreground, alpha = req.alpha;
  final br = req.bg[0], bgG = req.bg[1], bb = req.bg[2];
  final out = Uint8List(w * h * 4);
  for (var px = 0; px < alpha.length; px++) {
    final i = px * 4;
    final a = alpha[px];
    final inv = 255 - a;
    out[i] = (fg[i] * a + br * inv) ~/ 255;
    out[i + 1] = (fg[i + 1] * a + bgG * inv) ~/ 255;
    out[i + 2] = (fg[i + 2] * a + bb * inv) ~/ 255;
    out[i + 3] = 255;
  }
  final image =
      img.Image.fromBytes(width: w, height: h, bytes: out.buffer, numChannels: 4);
  return RecolorResult(rgba: out, jpg: img.encodeJpg(image, quality: 90));
}

/// 掩码精修：3×3 均值轻羽化 + **膝点映射**（高端饱和、低端保留）
/// + 主体连通域过滤 + 孔洞填实。
///
/// **不做形态学腐蚀**——旧版的 3×3 min-filter 会把整个人像轮廓向内啃掉一圈，
/// 头发丝、耳廓、肩线这些本就只有 1–2px 的结构会直接消失。消白边改由
/// [decontaminate] 在**颜色**上解决。
///
/// 但「不腐蚀」不等于「不做高端饱和」——曾经把映射放宽成对称的
/// `[0.06, 0.94]` 线性拉伸，结果 MODNet 在衣服/肩背这类低对比区域输出的
/// `a≈0.7` 原样保留成半透明，观感是**人物从胸口往下溶解进底色**。
/// 正确做法是不对称：
/// - 低端只清 5% 以下的背景残噪（发丝半透明带必须活着）；
/// - **高端 60% 以上直接判定为实心前景**（人体主体不允许半透明）。
Uint8List refineAlpha(Uint8List mask, int w, int h) {
  final n = w * h;
  // 1) 轻羽化（3×3 均值）：抹掉 512→原尺寸上采样带来的阶梯锯齿
  final smooth = Uint8List(n);
  for (var y = 0; y < h; y++) {
    final yl = y > 0 ? y - 1 : 0, yr = y < h - 1 ? y + 1 : h - 1;
    for (var x = 0; x < w; x++) {
      final xl = x > 0 ? x - 1 : 0, xr = x < w - 1 ? x + 1 : w - 1;
      smooth[y * w + x] = (mask[yl * w + xl] +
              mask[yl * w + x] +
              mask[yl * w + xr] +
              mask[y * w + xl] +
              mask[y * w + x] +
              mask[y * w + xr] +
              mask[yr * w + xl] +
              mask[yr * w + x] +
              mask[yr * w + xr]) ~/
          9;
    }
  }
  // 2) 膝点映射：[lo, knee] → [0, 1]，knee 以上一律实心
  const lo = 0.05, knee = 0.60;
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    final a = smooth[i] / 255.0;
    out[i] = (((a - lo) / (knee - lo)).clamp(0.0, 1.0) * 255).round();
  }
  // 3) 只留主体、填实孔洞
  keepMainSubject(out, w, h);
  return out;
}

/// 只保留最大前景连通域，并把被主体包围的孔洞填实（**原地修改** [alpha]）。
///
/// 解决两类 MODNet 误判：
/// - **飞地**：画面角落的建筑、地面色块被判成前景，换底后成了漂浮的残块；
/// - **孔洞**：躯干内部被判成背景，换底后身体上出现底色斑点。
///
/// 判定阈值 128（配合 [refineAlpha] 的膝点映射，主体已是 255）。面积不足
/// 最大域 25% 的独立连通域整体归零；从图像四边 flood fill 不到的背景像素
/// 即为孔洞，填 255。
void keepMainSubject(Uint8List alpha, int w, int h) {
  final n = w * h;
  final label = Int32List(n); // 0=未访问背景, -1=背景已访问, >0=前景域号
  final queue = Int32List(n);

  // ---- 前景连通域标记（4 邻域 BFS）----
  var best = 0, bestArea = 0;
  final areas = <int, int>{};
  var next = 1;
  for (var s = 0; s < n; s++) {
    if (alpha[s] < 128 || label[s] != 0) continue;
    final id = next++;
    var head = 0, tail = 0;
    queue[tail++] = s;
    label[s] = id;
    var area = 0;
    while (head < tail) {
      final p = queue[head++];
      area++;
      final x = p % w, y = p ~/ w;
      if (x > 0 && alpha[p - 1] >= 128 && label[p - 1] == 0) {
        label[p - 1] = id;
        queue[tail++] = p - 1;
      }
      if (x < w - 1 && alpha[p + 1] >= 128 && label[p + 1] == 0) {
        label[p + 1] = id;
        queue[tail++] = p + 1;
      }
      if (y > 0 && alpha[p - w] >= 128 && label[p - w] == 0) {
        label[p - w] = id;
        queue[tail++] = p - w;
      }
      if (y < h - 1 && alpha[p + w] >= 128 && label[p + w] == 0) {
        label[p + w] = id;
        queue[tail++] = p + w;
      }
    }
    areas[id] = area;
    if (area > bestArea) {
      bestArea = area;
      best = id;
    }
  }
  if (bestArea == 0) return; // 全背景，交由上层报 noPerson

  // 清掉小飞地（连同其周围的半透明带）
  for (var i = 0; i < n; i++) {
    final id = label[i];
    if (id > 0 && id != best && (areas[id] ?? 0) * 4 < bestArea) {
      alpha[i] = 0;
      label[i] = 0;
    }
  }

  // ---- 孔洞填实：从四边 flood fill 背景，未触达的背景像素即为洞 ----
  var head = 0, tail = 0;
  void seed(int p) {
    if (alpha[p] >= 128 || label[p] == -1) return;
    label[p] = -1;
    queue[tail++] = p;
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  while (head < tail) {
    final p = queue[head++];
    final x = p % w, y = p ~/ w;
    if (x > 0) seed(p - 1);
    if (x < w - 1) seed(p + 1);
    if (y > 0) seed(p - w);
    if (y < h - 1) seed(p + w);
  }
  for (var i = 0; i < n; i++) {
    if (alpha[i] < 128 && label[i] != -1) alpha[i] = 255;
  }
}

/// 前景色解混（消白边）：把**半透明边缘带**像素的颜色替换为邻域内高不透明度
/// 像素的加权平均色，alpha 完全不动。
///
/// 白边/毛刺的物理成因是边缘像素本身混合了原背景色，直接按 alpha 合成会
/// 把原背景（常是白墙）带进新底色里。工业界的解法是前景色估计而非腐蚀 alpha。
///
/// **两条必须的约束**（缺了会产生「头发外一圈白色光晕」）：
/// 1. 只处理**真正的边缘带**（`24 ≤ a ≤ 200`）。放宽到 `[8,240]` 会把大片
///    中间调区域也卷进来，等于拿邻域最亮色向外涂抹，观感就是发光。
/// 2. 替换强度 `k` 上限 0.6，且**只允许把颜色拉暗、不允许拉亮**——白边是
///    「被背景提亮」造成的，解混的物理方向只能是变暗；允许变亮就是在造光晕。
Uint8List decontaminate(Uint8List rgba, Uint8List alpha, int w, int h) {
  final out = Uint8List.fromList(rgba);
  const r = 2;
  const aLo = 24, aHi = 200;
  for (var pass = 0; pass < 2; pass++) {
    final src = Uint8List.fromList(out);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = y * w + x;
        final a = alpha[px];
        if (a < aLo || a > aHi) continue; // 只处理边缘过渡带
        var sw = 0.0, sr = 0.0, sg = 0.0, sb = 0.0;
        final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
        final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
        for (var ny = y0; ny <= y1; ny++) {
          for (var nx = x0; nx <= x1; nx++) {
            final na = alpha[ny * w + nx];
            if (na < 224) continue; // 只向「实心前景」取色，避免链式外推
            final t = na / 255.0;
            final wgt = t * t * t;
            final i = (ny * w + nx) * 4;
            sw += wgt;
            sr += src[i] * wgt;
            sg += src[i + 1] * wgt;
            sb += src[i + 2] * wgt;
          }
        }
        if (sw <= 0) continue;
        final o = px * 4;
        // alpha 越低污染越重，向估计的纯前景色靠得越多；上限 0.6 防过冲
        final k = ((1 - a / 255.0) * 0.75).clamp(0.0, 0.6);
        for (var c = 0; c < 3; c++) {
          final cur = src[o + c];
          final est = (c == 0 ? sr : (c == 1 ? sg : sb)) / sw;
          if (est >= cur) continue; // 解混只允许变暗，变亮 = 造光晕
          out[o + c] = (cur + (est - cur) * k).round().clamp(0, 255);
        }
      }
    }
  }
  return out;
}

/// 从掩码探测真实头顶 y：自上而下第一条「前景像素数达到阈值」的扫描线。
///
/// 阈值取 `max(3, 宽度·0.35%)`，既能抓住细软的头发轮廓，
/// 又不会被上采样噪点或残留碎块带偏；连续 2 行命中才确认，进一步抗噪。
double? detectHeadTop(Uint8List alpha, int w, int h) {
  final need = math.max(3, (w * 0.0035).round());
  var streak = 0;
  for (var y = 0; y < h; y++) {
    var count = 0;
    final row = y * w;
    for (var x = 0; x < w; x++) {
      if (alpha[row + x] > 96) count++;
    }
    if (count >= need) {
      if (++streak >= 2) return (y - 1).toDouble();
    } else {
      streak = 0;
    }
  }
  return null;
}

/// isolate 入口：底色补边裁剪 → 规格缩放 → 面部精修/清晰度 → 轻锐化 → 二分压缩。
/// 首次出片、改裁剪框、改效果强度三条路径共用，保证预览与成片参数完全一致。
Uint8List deliverWorker(DeliveryRequest req) {
  final bg = img.ColorRgb8(req.bg[0], req.bg[1], req.bg[2]);
  final source = img.Image.fromBytes(
      width: req.width,
      height: req.height,
      bytes: req.rgba.buffer,
      numChannels: 4);

  final cropped = ImagePipeline.paddedCrop(source, req.crop, bg);
  var out = ImagePipeline.resizeToSpecUniform(
      cropped, req.targetWidth, req.targetHeight, bg);

  if (req.beauty > 0 || req.clarity > 0) {
    // 人脸框：工作图坐标 → 裁剪后输出坐标
    final sx = req.targetWidth / cropped.width;
    final sy = req.targetHeight / cropped.height;
    final face = Rect.fromLTRB(
        (req.faceRect.left - req.crop.left) * sx,
        (req.faceRect.top - req.crop.top) * sy,
        (req.faceRect.right - req.crop.left) * sx,
        (req.faceRect.bottom - req.crop.top) * sy);
    out = PhotoEffects.apply(out, face,
        beauty: req.beauty, clarity: req.clarity);
  }

  // 高精修档：一道轻锐化，发丝/轮廓更利落
  if (req.sharpen) {
    out = img.convolution(out,
        filter: [0, -0.2, 0, -0.2, 1.8, -0.2, 0, -0.2, 0]);
  }
  return ImagePipeline.encodeToKbRange(out, req.minKb, req.maxKb);
}

/// 预览效果重算任务（不裁剪，直接在工作图上出 JPEG 预览）。
@immutable
class PreviewRequest {
  const PreviewRequest({
    required this.rgba,
    required this.width,
    required this.height,
    required this.faceRect,
    required this.beauty,
    required this.clarity,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final Rect faceRect;
  final double beauty;
  final double clarity;
}

/// isolate 入口：工作图上应用效果并编码为预览 JPEG。
Uint8List previewWorker(PreviewRequest req) {
  final src = img.Image.fromBytes(
      width: req.width,
      height: req.height,
      bytes: req.rgba.buffer,
      numChannels: 4);
  final out = PhotoEffects.apply(src, req.faceRect,
      beauty: req.beauty, clarity: req.clarity);
  return img.encodeJpg(out, quality: 90);
}

/// 后台 isolate 读图结果（含 ML Kit 输入）
class _LoadedWork {
  const _LoadedWork(this.w, this.h, this.rgba, this.mlJpg, this.mlScale);

  final int w;
  final int h;
  final Uint8List rgba;

  /// 960px/q85 JPEG（ML Kit 人脸检测输入）
  final Uint8List mlJpg;

  /// ml 图相对 work 的缩放比（人脸框映射回 work 坐标用）
  final double mlScale;
}

/// isolate 入口：解码 → EXIF 归一化 → 镜像补偿 → 限边缩放 → ML 输入编码
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
  // ML Kit 输入同 isolate 产出（主线程零重活）
  var mlImage = work;
  final mlScale =
      work.width >= work.height ? 960 / work.width : 960 / work.height;
  if (mlScale < 1) {
    mlImage = img.copyResize(work,
        width: (work.width * mlScale).round(),
        height: (work.height * mlScale).round());
  }
  return _LoadedWork(
      work.width,
      work.height,
      Uint8List.fromList(work.getBytes(order: img.ChannelOrder.rgba)),
      img.encodeJpg(mlImage, quality: 85),
      mlScale < 1 ? mlScale : 1.0);
}
