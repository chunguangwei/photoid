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

  /// 面部精修：**双尺度**频率分离磨皮（细节层去毛孔细纹、中频层去色斑痘印）
  /// + 匀肤 + 提亮 + 轻度瘦脸。
  ///
  /// 为什么是双尺度（这是「拉满了也看不出效果」的根因）：
  /// 皮肤瑕疵分布在两个尺度上——毛孔、细纹属于**高频小幅**；色斑、痘印、
  /// 眼袋、肤色不匀属于**中频中幅**（幅度常达 30–60）。早期只做单尺度高频
  /// 压制，且把「>26 幅度」一律当作五官结构全额保留，结果最该去掉的色斑
  /// 完全没被碰到，用户观感就是「磨了但脸还是那样」。
  ///
  /// 现在分两层处理，且**判定阈值随强度放大**——强度越高，敢压的幅度越大，
  /// 滑杆因此在全程都有可感知的变化；而五官结构靠「高幅度 + 非肤色」双重
  /// 保护，仍然不会被糊。
  static Uint8List retouchFace(
      Uint8List rgba, int w, int h, Rect face, double intensity) {
    if (intensity <= 0 || face.width <= 2 || face.height <= 2) return rgba;

    final cx = face.left + face.width / 2;
    final cy = face.top + face.height / 2;
    // 椭圆略大于人脸框，覆盖额头/下颌/两颊；外侧有羽化，不会出现硬边
    final rx = math.max(4.0, face.width * 0.70);
    final ry = math.max(4.0, face.height * 0.82);

    // 两个尺度的模糊半径都随脸尺寸自适应，保证不同分辨率下观感一致
    final rDetail = (face.width * 0.030).round().clamp(2, 30); // 毛孔/细纹
    final rBlotch = (face.width * 0.105).round().clamp(4, 90); // 色斑/痘印
    final blurD = _boxBlurRgba(rgba, w, h, rDetail);
    final blurB = _boxBlurRgba(rgba, w, h, rBlotch);

    // 细节层：intensity=1 时保留 10%
    final keepDetail = 1.0 - 0.90 * intensity;
    // 中频层：intensity=1 时保留 42%。不能压太狠——中频承载脸部立体感，
    // 压没了会变成一张纸片脸。
    final keepBlotch = 1.0 - 0.58 * intensity;

    // 判定阈值随强度放大：低强度只碰细腻瑕疵，高强度才敢动明显色斑
    final tLo = 8.0 + 6.0 * intensity;
    final tHi = 26.0 + 40.0 * intensity;

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
        if (_skinWeight(r, g, bl) < 0.5) continue;
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
    final evenK = 0.26 * intensity;
    // 提亮：证件照普遍偏暗，轻微抬亮部能显著改善「气色」，比单纯磨皮更可感知
    final brighten = 7.0 * intensity;
    // 暖肤：红通道微增。人对「气色好」的判断主要来自肤色暖度而非光滑度，
    // 这一项的可感知收益比继续加大磨皮强度高得多，且不损失任何细节。
    final warm = 4.0 * intensity;

    final out = Uint8List.fromList(rgba);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x - cx) / rx, dy = (y - cy) / ry;
        final d2 = dx * dx + dy * dy;
        if (d2 > 1) continue;
        final i = (y * w + x) * 4;
        final r = rgba[i], g = rgba[i + 1], bl = rgba[i + 2];
        // 肤色权重是**软的**：眼/眉/唇/发权重 0（完全不动），
        // 阴影侧的皮肤仍能拿到部分权重（旧版硬判据把它整片排除，
        // 导致侧脸、逆光照几乎看不出效果）
        final skin = _skinWeight(r, g, bl);
        if (skin <= 0) continue;

        // 边缘羽化：外圈 30% 线性淡出，杜绝「面具边」
        final dist = math.sqrt(d2);
        final feather = dist <= 0.70 ? 1.0 : (1 - dist) / 0.30;
        final k = intensity * feather * skin;
        if (k <= 0) continue;

        var nr = _twoScale(r, blurD[i], blurB[i], keepDetail, keepBlotch, tLo, tHi);
        var ng = _twoScale(
            g, blurD[i + 1], blurB[i + 1], keepDetail, keepBlotch, tLo, tHi);
        var nb = _twoScale(
            bl, blurD[i + 2], blurB[i + 2], keepDetail, keepBlotch, tLo, tHi);

        // 匀肤：仅拉齐色度，按当前像素亮度缩放目标色 → 保留立体光影
        if (evenOut) {
          final l = _lum(nr, ng, nb);
          final s = l / mLum;
          nr += (mr * s - nr) * evenK * feather;
          ng += (mg * s - ng) * evenK * feather;
          nb += (mb * s - nb) * evenK * feather;
        }

        // 提亮：暗部抬得多、亮部几乎不动，避免高光溢出成死白
        final room = (255 - _lum(nr, ng, nb)) / 255;
        final lift = brighten * room * feather;
        nr += lift + warm * feather;
        ng += lift;
        nb += lift;

        out[i] = _u8(r + (nr - r) * k);
        out[i + 1] = _u8(g + (ng - g) * k);
        out[i + 2] = _u8(bl + (nb - bl) * k);
      }
    }

    return _slimFace(out, w, h, cx, cy, rx, ry, intensity);
  }

  /// 双尺度频率重建。
  ///
  /// 把像素拆成三层：中频以下（`blurB`，脸部立体感与光影）、中频细节
  /// （`blurB → blurD`，色斑/痘印/肤色不匀）、高频细节（`blurD → src`，
  /// 毛孔/细纹/噪点）。两个细节层分别按 [keepBlotch] / [keepDetail] 压制，
  /// 并按幅度在 [tLo]–[tHi] 之间平滑过渡到「全额保留」——保证眼睑、唇线、
  /// 鼻翼这些高幅结构不被磨掉。
  static double _twoScale(int src, int blurD, int blurB, double keepDetail,
      double keepBlotch, double tLo, double tHi) {
    final dHigh = src - blurD.toDouble(); // 高频
    final dMid = blurD - blurB.toDouble(); // 中频
    return blurB + dMid * _blend(dMid.abs(), keepBlotch, tLo, tHi) +
        dHigh * _blend(dHigh.abs(), keepDetail, tLo, tHi);
  }

  /// 幅度 [ad] 越大越接近「原样保留」（返回 1），越小越接近 [keep]。
  static double _blend(double ad, double keep, double tLo, double tHi) {
    if (ad <= tLo) return keep;
    if (ad >= tHi) return 1.0;
    return keep + (1 - keep) * ((ad - tLo) / (tHi - tLo));
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

  /// 画质清晰度：**亮度通道** USM 锐化 + 局部对比（通透感）+ S 曲线
  /// + 极轻饱和补偿。作用于整图，与面部精修互不干扰。
  ///
  /// 三处与早期实现的关键差异（早期观感「过锐、发假、暗部发脏」）：
  ///
  /// 1. **只锐化亮度，不锐化色度**。对 R/G/B 分别做 USM 会让互补色在边缘
  ///    分离，产生彩色描边（紫边/绿边），在证件照的发丝与眼镜框上尤其明显。
  ///    改为提取亮度增量、三通道等量施加，边缘干净得多。
  /// 2. **S 曲线代替线性对比**。`128 + (v-128) * k` 会把暗部直接压死、
  ///    高光顶死；S 曲线只拉开中间调，两端自然收敛，这才是「通透」而非
  ///    「对比大」。
  /// 3. **饱和度大幅降权**（0.10 → 0.05）。清晰度滑杆的语义是锐利与通透，
  ///    颜色浓艳属于另一码事，混进来会让肤色发橙。
  static Uint8List enhanceClarity(
      Uint8List rgba, int w, int h, double intensity) {
    if (intensity <= 0) return rgba;
    final minSide = math.min(w, h);

    final rSharp = (minSide * 0.004).round().clamp(1, 6);
    final rLocal = (minSide * 0.030).round().clamp(4, 60);
    final blurS = _boxBlurRgba(rgba, w, h, rSharp);
    final blurL = _boxBlurRgba(rgba, w, h, rLocal);

    final amtSharp = 0.85 * intensity; // USM 强度（亮度通道）
    final amtLocal = 0.34 * intensity; // 局部对比（通透感）
    const noiseT = 3.0; // 低于此幅度视为噪点，不锐化
    final sCurve = 0.16 * intensity; // S 曲线强度
    // 鲜艳度（vibrance）而非饱和度：见 _vibrance 的说明，可以给到远高于
    // 线性饱和的系数而不会让肤色发橙
    final vib = 0.30 * intensity;

    final out = Uint8List.fromList(rgba);
    final n = w * h;
    for (var px = 0; px < n; px++) {
      final i = px * 4;
      var vr = rgba[i].toDouble(),
          vg = rgba[i + 1].toDouble(),
          vb = rgba[i + 2].toDouble();

      // 1) USM（仅亮度）：算出亮度增量后三通道等量施加，避免彩色描边
      final lSrc = _lum(vr, vg, vb);
      final lBlur =
          _lum(blurS[i].toDouble(), blurS[i + 1].toDouble(), blurS[i + 2].toDouble());
      final dl = lSrc - lBlur;
      if (dl.abs() > noiseT) {
        final add = dl * amtSharp;
        vr += add;
        vg += add;
        vb += add;
      }

      // 2) 局部对比度（同样走亮度）：拉开大尺度明暗，去灰蒙
      final lLocal =
          _lum(blurL[i].toDouble(), blurL[i + 1].toDouble(), blurL[i + 2].toDouble());
      final addL = (lSrc - lLocal) * amtLocal;
      vr += addL;
      vg += addL;
      vb += addL;

      // 3) S 曲线：只拉开中间调，暗部与高光自然收敛（不压死、不顶死）
      if (sCurve > 0) {
        vr = _sCurve(vr, sCurve);
        vg = _sCurve(vg, sCurve);
        vb = _sCurve(vb, sCurve);
      }

      // 4) 鲜艳度：低饱和区域多加、已鲜艳区域几乎不动
      if (vib > 0) {
        final l = _lum(vr, vg, vb);
        final mx = math.max(vr, math.max(vg, vb));
        final mn = math.min(vr, math.min(vg, vb));
        final k = 1 + _vibrance(mx, mn, vib);
        vr = l + (vr - l) * k;
        vg = l + (vg - l) * k;
        vb = l + (vb - l) * k;
      }

      out[i] = _u8(vr);
      out[i + 1] = _u8(vg);
      out[i + 2] = _u8(vb);
    }
    return out;
  }

  /// 鲜艳度增量：**当前饱和度越高，加得越少**（`amt = k × (1 - sat)`）。
  ///
  /// 这是比线性饱和度更适合人像的做法。线性饱和对所有像素等比放大，肤色本就
  /// 偏饱和，一放大立刻发橙发红，所以系数只能给到很小（0.05 级别），
  /// 结果是「调了跟没调一样」。鲜艳度把增益让给灰淡区域（衣服、背景过渡），
  /// 对已经饱和的肤色自动收手——因此可以给到 6 倍的系数而依然安全。
  /// 衰减取**平方**而非线性：线性衰减下饱和度 0.45 的肤色仍能拿到 55% 增益，
  /// 依旧会发橙；平方后只剩 30%，而近中性的灰淡区几乎不受影响（0.92），
  /// 两者的增益差被明显拉开，这正是「鲜艳」与「过饱和」的分界。
  static double _vibrance(double mx, double mn, double amount) {
    if (mx <= 0) return 0;
    final sat = ((mx - mn) / mx).clamp(0.0, 1.0);
    final k = 1 - sat;
    return amount * k * k;
  }

  /// S 曲线：以中灰为轴拉开中间调，两端平滑收敛。
  /// [k] 为强度（0 时恒等）。用平滑步进与恒等函数按 k 混合实现，
  /// 保证单调、无回绕、端点固定在 0/255。
  static double _sCurve(double v, double k) {
    final t = (v / 255).clamp(0.0, 1.0);
    final sm = t * t * (3 - 2 * t); // smoothstep：中间调更陡、两端更平
    return (t + (sm - t) * k) * 255;
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

  /// 肤色权重 0–1（**软判据**，YCbCr 色度域）。
  ///
  /// 早期用的是经典 RGB 硬判据（`r>95 && g>40 && ...`），问题是它把阴影侧的
  /// 皮肤、偏暗肤色整片排除在外——那些区域恰恰是最需要匀肤的地方，
  /// 结果侧脸和逆光照几乎看不出美颜效果。
  ///
  /// 改用色度域软判据：Cb/Cr 落在肤色椭圆中心权重为 1，边缘线性衰减到 0。
  /// **色度与亮度无关**，所以阴影里的皮肤同样能被识别；而眼睛、眉毛、头发、
  /// 嘴唇的色度明显偏离该区域，权重仍为 0（完全不参与磨皮）。
  static double _skinWeight(int r, int g, int b) {
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    // 经典 YCbCr 肤色窗口，边界各留 8 的软过渡带（避免权重突变造成色块）。
    // 窗口刻意取得宽：偏红、偏黄、偏冷的肤色都要覆盖，漏掉就等于「没效果」。
    final wCb = _window(cb, 77, 127, 8);
    final wCr = _window(cr, 133, 177, 8);
    if (wCb <= 0 || wCr <= 0) return 0;
    // 亮度门控：极暗区（头发缝隙、鼻孔、瞳孔）色度不可信，一律不动
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final wY = y <= 50 ? 0.0 : (y >= 80 ? 1.0 : (y - 50) / 30);
    return wCb * wCr * wY;
  }

  /// 带软边的区间隶属度：[lo,hi] 内为 1，向外 [soft] 宽度内线性衰减到 0。
  static double _window(double v, double lo, double hi, double soft) {
    if (v < lo) return math.max(0.0, 1 - (lo - v) / soft);
    if (v > hi) return math.max(0.0, 1 - (v - hi) / soft);
    return 1;
  }

  static double _lum(double r, double g, double b) =>
      0.299 * r + 0.587 * g + 0.114 * b;

  static double _smooth(double a, double b, double x) {
    if (b == a) return x >= b ? 1 : 0;
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static int _u8(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
}
