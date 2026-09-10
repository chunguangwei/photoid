import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// 人像后期效果：**面部精修**与**画质清晰度**两条独立通道。
///
/// 设计原则（对齐行业最佳实践）：
/// - 两个强度均默认 0（不开启即完全原图，字节级一致），用户主动拉大才生效；
/// - 全部运算直接跑在 RGBA 原始缓冲区上（自研分离式盒子模糊 ≈ 高斯，
///   O(n) 与半径无关），比逐像素 `getPixel/setPixel` 快一个量级——
///   这是把效果重算压进「一次扫描动效」时长内的前提；
/// - 纯函数、无 BuildContext / 无 IO，可安全在 isolate 内调用。
class PhotoEffects {
  PhotoEffects._();

  /// 一次性应用两条通道（先精修面部、再全局提清晰度）。
  /// [face] 为 [src] 坐标系下的人脸框；[beauty]/[clarity] 均为 0.0–1.0。
  /// 两者皆为 0 时直接返回原图（零拷贝、零耗时）。
  static img.Image apply(img.Image src, Rect face,
      {double beauty = 0, double clarity = 0}) {
    final b = beauty.clamp(0.0, 1.0);
    final c = clarity.clamp(0.0, 1.0);
    if (b <= 0 && c <= 0) return src;

    final w = src.width;
    final h = src.height;
    var rgba = Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));

    if (b > 0) rgba = retouchFace(rgba, w, h, face, b);
    if (c > 0) rgba = enhanceClarity(rgba, w, h, c);

    return img.Image.fromBytes(
        width: w, height: h, bytes: rgba.buffer, numChannels: 4);
  }

  // ─────────────────────────── 面部精修 ───────────────────────────

  /// 面部精修：高低频分离磨皮（去皱/去斑，保五官锐度）+ 匀肤 + 轻度瘦脸。
  ///
  /// 与「整图高斯混合」的老做法相比，这里把图像拆成低频（肤色/光影）与
  /// 高频（纹理/五官边缘）：**只压制低幅度高频**（毛孔、细纹、色斑），
  /// 高幅度高频（眼睑、唇线、鼻翼）原样保留——所以强度拉满也不糊五官，
  /// 且在低强度时就能明显看出皮肤变干净（解决「拉大效果不明显」）。
  static Uint8List retouchFace(
      Uint8List rgba, int w, int h, Rect face, double intensity) {
    if (intensity <= 0 || face.width <= 2 || face.height <= 2) return rgba;

    final cx = face.left + face.width / 2;
    final cy = face.top + face.height / 2;
    // 椭圆略大于人脸框，覆盖额头/下颌/两颊；外侧有羽化，不会出现硬边
    final rx = math.max(4.0, face.width * 0.70);
    final ry = math.max(4.0, face.height * 0.82);

    // 模糊半径随脸尺寸自适应：同一强度在大图/小图上观感一致
    final radius = (face.width * 0.05).round().clamp(2, 40);
    final blur = _boxBlurRgba(rgba, w, h, radius);

    // 低幅高频的压制系数：intensity=1 时保留 12%（去皱/去斑）
    final keepLow = 1.0 - 0.88 * intensity;
    const tLo = 10.0; // 以下判定为瑕疵（全压）
    const tHi = 26.0; // 以上判定为五官结构（全留）

    final x0 = math.max(0, (cx - rx).floor());
    final x1 = math.min(w - 1, (cx + rx).ceil());
    final y0 = math.max(0, (cy - ry).floor());
    final y1 = math.min(h - 1, (cy + ry).ceil());

    // 匀肤目标色：椭圆内肤色像素均值（先扫一遍统计）
    var sr = 0, sg = 0, sb = 0, sn = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x - cx) / rx, dy = (y - cy) / ry;
        if (dx * dx + dy * dy > 1) continue;
        final i = (y * w + x) * 4;
        final r = rgba[i], g = rgba[i + 1], bl = rgba[i + 2];
        if (!_isSkin(r, g, bl)) continue;
        sr += r;
        sg += g;
        sb += bl;
        sn++;
      }
    }
    // 肤色样本太少（侧脸/强逆光/误检）→ 放弃匀肤，只做磨皮，避免整片偏色
    final evenOut = sn > 64;
    final mr = evenOut ? sr / sn : 0.0;
    final mg = evenOut ? sg / sn : 0.0;
    final mb = evenOut ? sb / sn : 0.0;
    final mLum = evenOut ? _lum(mr, mg, mb) : 1.0;
    final evenK = 0.16 * intensity;

    final out = Uint8List.fromList(rgba);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x - cx) / rx, dy = (y - cy) / ry;
        final d2 = dx * dx + dy * dy;
        if (d2 > 1) continue;
        final i = (y * w + x) * 4;
        final r = rgba[i], g = rgba[i + 1], bl = rgba[i + 2];
        if (!_isSkin(r, g, bl)) continue;

        // 边缘羽化：外圈 30% 线性淡出，杜绝「面具边」
        final dist = math.sqrt(d2);
        final feather = dist <= 0.70 ? 1.0 : (1 - dist) / 0.30;
        final k = intensity * feather;
        if (k <= 0) continue;

        var nr = _hiLo(r, blur[i], keepLow, tLo, tHi);
        var ng = _hiLo(g, blur[i + 1], keepLow, tLo, tHi);
        var nb = _hiLo(bl, blur[i + 2], keepLow, tLo, tHi);

        // 匀肤：仅拉齐色度，按当前像素亮度缩放目标色 → 保留立体光影
        if (evenOut) {
          final l = _lum(nr, ng, nb);
          final s = l / mLum;
          nr += (mr * s - nr) * evenK * feather;
          ng += (mg * s - ng) * evenK * feather;
          nb += (mb * s - nb) * evenK * feather;
        }

        out[i] = _u8(r + (nr - r) * k);
        out[i + 1] = _u8(g + (ng - g) * k);
        out[i + 2] = _u8(bl + (nb - bl) * k);
      }
    }

    return _slimFace(out, w, h, cx, cy, rx, ry, intensity);
  }

  /// 高低频重建：低幅细节按 [keepLow] 压制，高幅细节全保留，中间平滑过渡。
  static double _hiLo(
      int src, int blurred, double keepLow, double tLo, double tHi) {
    final d = src - blurred.toDouble();
    final ad = d.abs();
    final double s;
    if (ad <= tLo) {
      s = keepLow;
    } else if (ad >= tHi) {
      s = 1.0;
    } else {
      s = keepLow + (1 - keepLow) * ((ad - tLo) / (tHi - tLo));
    }
    return blurred + d * s;
  }

  /// 轻度瘦脸：仅下半脸（颧骨→下颌）水平向中线收缩，最大 4.5%。
  ///
  /// 幅度刻意压得很小：证件照审核关注「与本人一致」，明显改脸型有合规风险；
  /// 这里只做视觉上收紧下颌线的程度，双线性重采样保证无锯齿。
  static Uint8List _slimFace(Uint8List rgba, int w, int h, double cx, double cy,
      double rx, double ry, double intensity) {
    final strength = 0.045 * intensity;
    if (strength <= 0.001) return rgba;

    final x0 = math.max(0, (cx - rx * 1.15).floor());
    final x1 = math.min(w - 1, (cx + rx * 1.15).ceil());
    final y0 = math.max(0, (cy - ry * 0.2).floor());
    final y1 = math.min(h - 1, (cy + ry * 1.15).ceil());
    if (x1 <= x0 || y1 <= y0) return rgba;

    final out = Uint8List.fromList(rgba);
    for (var y = y0; y <= y1; y++) {
      final ny = (y - cy) / ry;
      // 纵向权重：颧骨(-0.1)起、下颌(0.7)峰值、下巴外(1.15)归零
      final t = _smooth(-0.10, 0.55, ny) * (1 - _smooth(0.80, 1.15, ny));
      if (t <= 0) continue;
      for (var x = x0; x <= x1; x++) {
        final nx = (x - cx) / rx;
        if (nx * nx + ny * ny > 1.32) continue;
        // 横向权重：中线附近不动，越靠外收缩越强（保证鼻/嘴不变形）
        final lat = _smooth(0.15, 1.0, nx.abs());
        final shift = nx.sign * strength * rx * t * lat;
        // 目标像素向外取样 ⇒ 图像向内收缩
        _sampleBilinear(rgba, w, h, x + shift, y.toDouble(), out, (y * w + x) * 4);
      }
    }
    return out;
  }

  // ─────────────────────────── 画质清晰度 ───────────────────────────

  /// 画质清晰度：USM 锐化（带阈值，不放大噪点）+ 局部对比度（去灰/通透）
  /// + 极轻的全局对比与饱和补偿。作用于**整图**，与面部精修互不干扰。
  static Uint8List enhanceClarity(
      Uint8List rgba, int w, int h, double intensity) {
    if (intensity <= 0) return rgba;
    final minSide = math.min(w, h);

    final rSharp = (minSide * 0.004).round().clamp(1, 6);
    final rLocal = (minSide * 0.030).round().clamp(4, 60);
    final blurS = _boxBlurRgba(rgba, w, h, rSharp);
    final blurL = _boxBlurRgba(rgba, w, h, rLocal);

    final amtSharp = 1.10 * intensity; // USM 强度
    final amtLocal = 0.42 * intensity; // 局部对比（通透感）
    const noiseT = 3.0; // 低于此幅度视为噪点，不锐化
    final contrast = 1 + 0.07 * intensity;
    final sat = 1 + 0.10 * intensity;

    final out = Uint8List.fromList(rgba);
    final n = w * h;
    for (var px = 0; px < n; px++) {
      final i = px * 4;
      var vr = rgba[i].toDouble(),
          vg = rgba[i + 1].toDouble(),
          vb = rgba[i + 2].toDouble();

      // 1) USM：仅对超过噪声阈值的细节增强
      final dr = vr - blurS[i], dg = vg - blurS[i + 1], db = vb - blurS[i + 2];
      if (dr.abs() > noiseT) vr += dr * amtSharp;
      if (dg.abs() > noiseT) vg += dg * amtSharp;
      if (db.abs() > noiseT) vb += db * amtSharp;

      // 2) 局部对比度：拉开大尺度明暗，去灰蒙
      vr += (vr - blurL[i]) * amtLocal;
      vg += (vg - blurL[i + 1]) * amtLocal;
      vb += (vb - blurL[i + 2]) * amtLocal;

      // 3) 极轻全局对比 + 饱和（绕中灰/绕亮度）
      vr = 128 + (vr - 128) * contrast;
      vg = 128 + (vg - 128) * contrast;
      vb = 128 + (vb - 128) * contrast;
      final l = _lum(vr, vg, vb);
      vr = l + (vr - l) * sat;
      vg = l + (vg - l) * sat;
      vb = l + (vb - l) * sat;

      out[i] = _u8(vr);
      out[i + 1] = _u8(vg);
      out[i + 2] = _u8(vb);
    }
    return out;
  }

  // ─────────────────────────── 基础运算 ───────────────────────────

  /// 三趟分离式盒子模糊 ≈ 高斯模糊，复杂度 O(w·h) 与半径**无关**。
  /// 只处理 RGB，alpha 原样透传（本流程 alpha 恒为 255）。
  static Uint8List _boxBlurRgba(Uint8List rgba, int w, int h, int radius) {
    if (radius < 1 || w < 2 || h < 2) return Uint8List.fromList(rgba);
    var buf = Uint8List.fromList(rgba);
    var tmp = Uint8List(rgba.length);
    for (var pass = 0; pass < 3; pass++) {
      _boxH(buf, tmp, w, h, radius);
      _boxV(tmp, buf, w, h, radius);
    }
    return buf;
  }

  static void _boxH(Uint8List src, Uint8List dst, int w, int h, int r) {
    final win = r * 2 + 1;
    for (var y = 0; y < h; y++) {
      final row = y * w;
      var sr = 0, sg = 0, sb = 0;
      // 初始化窗口（左侧用边缘像素补齐，避免边框变暗）
      for (var k = -r; k <= r; k++) {
        final i = (row + k.clamp(0, w - 1)) * 4;
        sr += src[i];
        sg += src[i + 1];
        sb += src[i + 2];
      }
      for (var x = 0; x < w; x++) {
        final o = (row + x) * 4;
        dst[o] = sr ~/ win;
        dst[o + 1] = sg ~/ win;
        dst[o + 2] = sb ~/ win;
        dst[o + 3] = src[o + 3];
        final add = (row + (x + r + 1).clamp(0, w - 1)) * 4;
        final sub = (row + (x - r).clamp(0, w - 1)) * 4;
        sr += src[add] - src[sub];
        sg += src[add + 1] - src[sub + 1];
        sb += src[add + 2] - src[sub + 2];
      }
    }
  }

  static void _boxV(Uint8List src, Uint8List dst, int w, int h, int r) {
    final win = r * 2 + 1;
    for (var x = 0; x < w; x++) {
      var sr = 0, sg = 0, sb = 0;
      for (var k = -r; k <= r; k++) {
        final i = (k.clamp(0, h - 1) * w + x) * 4;
        sr += src[i];
        sg += src[i + 1];
        sb += src[i + 2];
      }
      for (var y = 0; y < h; y++) {
        final o = (y * w + x) * 4;
        dst[o] = sr ~/ win;
        dst[o + 1] = sg ~/ win;
        dst[o + 2] = sb ~/ win;
        dst[o + 3] = src[o + 3];
        final add = ((y + r + 1).clamp(0, h - 1) * w + x) * 4;
        final sub = ((y - r).clamp(0, h - 1) * w + x) * 4;
        sr += src[add] - src[sub];
        sg += src[add + 1] - src[sub + 1];
        sb += src[add + 2] - src[sub + 2];
      }
    }
  }

  /// 双线性取样 [sx],[sy] 处的颜色写入 [dst] 的 [o] 偏移（越界钳到边缘）。
  static void _sampleBilinear(Uint8List src, int w, int h, double sx, double sy,
      Uint8List dst, int o) {
    final fx = sx.clamp(0.0, w - 1.0);
    final fy = sy.clamp(0.0, h - 1.0);
    final x0 = fx.floor(), y0 = fy.floor();
    final x1 = math.min(x0 + 1, w - 1), y1 = math.min(y0 + 1, h - 1);
    final ax = fx - x0, ay = fy - y0;
    final i00 = (y0 * w + x0) * 4,
        i10 = (y0 * w + x1) * 4,
        i01 = (y1 * w + x0) * 4,
        i11 = (y1 * w + x1) * 4;
    for (var c = 0; c < 3; c++) {
      final top = src[i00 + c] + (src[i10 + c] - src[i00 + c]) * ax;
      final bot = src[i01 + c] + (src[i11 + c] - src[i01 + c]) * ax;
      dst[o + c] = _u8(top + (bot - top) * ay);
    }
  }

  /// 经典 RGB 肤色判据：滤掉眼睛/眉毛/头发/嘴唇，避免磨糊五官。
  static bool _isSkin(int r, int g, int b) =>
      r > 95 && g > 40 && b > 20 && r > b && (r - math.min(g, b)) > 10;

  static double _lum(double r, double g, double b) =>
      0.299 * r + 0.587 * g + 0.114 * b;

  static double _smooth(double a, double b, double x) {
    if (b == a) return x >= b ? 1 : 0;
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static int _u8(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
}
