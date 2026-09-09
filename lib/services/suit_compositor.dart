import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// 正装样式。none=不换装。
enum SuitStyle { none, menNavy, menCharcoal, womenNavy }

/// 端侧正装合成（行业通行做法：正装模板按人脸几何贴合）。
/// 平面向量风格（西装+衬衫+领带/圆领），绘制在独立图层上高斯羽化后
/// 叠到成片，颈部皮肤保留、边缘不生硬。
///
/// 合规提示：身份证/签证等严格场景不建议使用（官方可能拒收），
/// UI 层负责提示。
class SuitCompositor {
  SuitCompositor._();

  /// 在 [src]（输出坐标系）上按人脸框 [face] 合成 [style] 正装，返回新图。
  static img.Image apply(img.Image src, Rect face, SuitStyle style) {
    if (style == SuitStyle.none) return src;

    final w = src.width, h = src.height;
    final cx = face.left + face.width / 2;
    final chinY = face.bottom;
    final headW = face.width;
    final headH = face.height;

    // 几何锚点（相对头部尺寸，随构图缩放自适应）
    final neckW = headW * 0.42;
    final neckH = headH * 0.34;
    final suitTop = chinY + neckH * 1.15; // 领口起点：颈部中段，保留颈部皮肤
    final shoulderY = suitTop + headH * 0.30;
    final shoulderW = (headW * 2.85).clamp(0.0, w * 1.3);
    final vDepth = headH * (style == SuitStyle.womenNavy ? 0.42 : 0.60);

    // 独立图层（透明底），统一羽化后叠加
    final layer = img.Image(width: w, height: h, numChannels: 4);

    final pal = _palette(style);
    img.Point pt(double x, double y) =>
        img.Point(x.round(), y.round());

    // 西装主体（梯形带肩坡）
    img.fillPolygon(layer, vertices: [
      pt(cx - shoulderW / 2, h.toDouble()),
      pt(cx - shoulderW / 2, shoulderY + headH * 0.12),
      pt(cx - shoulderW * 0.30, suitTop),
      pt(cx - neckW / 2, suitTop - headH * 0.06),
      pt(cx + neckW / 2, suitTop - headH * 0.06),
      pt(cx + shoulderW * 0.30, suitTop),
      pt(cx + shoulderW / 2, shoulderY + headH * 0.12),
      pt(cx + shoulderW / 2, h.toDouble()),
    ], color: pal.jacket);

    // 衬衫（V/圆领区）
    img.fillPolygon(layer, vertices: [
      pt(cx - neckW * 0.62, suitTop - headH * 0.04),
      pt(cx + neckW * 0.62, suitTop - headH * 0.04),
      pt(cx, suitTop + vDepth),
    ], color: pal.shirt);

    // 领带（仅男款）
    if (style != SuitStyle.womenNavy) {
      final tieTop = suitTop + vDepth * 0.28;
      img.fillPolygon(layer, vertices: [
        pt(cx - neckW * 0.16, tieTop),
        pt(cx + neckW * 0.16, tieTop),
        pt(cx + neckW * 0.24, tieTop + headH * 0.42),
        pt(cx, tieTop + headH * 0.52),
        pt(cx - neckW * 0.24, tieTop + headH * 0.42),
      ], color: pal.tie);
      // 领结
      img.fillPolygon(layer, vertices: [
        pt(cx - neckW * 0.18, tieTop - headH * 0.05),
        pt(cx + neckW * 0.18, tieTop - headH * 0.05),
        pt(cx + neckW * 0.16, tieTop + headH * 0.04),
        pt(cx - neckW * 0.16, tieTop + headH * 0.04),
      ], color: pal.tie);
    }

    // 左右翻领（压色三角）
    for (final s in [-1.0, 1.0]) {
      img.fillPolygon(layer, vertices: [
        pt(cx + s * neckW * 0.62, suitTop - headH * 0.04),
        pt(cx + s * neckW * 1.9, suitTop + headH * 0.10),
        pt(cx + s * neckW * 0.9, suitTop + vDepth + headH * 0.10),
        pt(cx, suitTop + vDepth),
      ], color: pal.lapel);
    }

    // 衬衫领口三角补片（盖住翻领上缘，形成领子）
    for (final s in [-1.0, 1.0]) {
      img.fillPolygon(layer, vertices: [
        pt(cx + s * neckW * 0.62, suitTop - headH * 0.06),
        pt(cx + s * neckW * 1.35, suitTop + headH * 0.03),
        pt(cx + s * neckW * 0.28, suitTop + headH * 0.14),
      ], color: pal.shirt);
    }

    // 羽化边缘（半径 1 轻模糊，避免硬边贴纸感）
    final softened = img.gaussianBlur(layer, radius: 1);

    // 叠到底图（straight alpha 合成）
    final out = src.clone();
    img.compositeImage(out, softened);
    return out;
  }

  static _SuitPalette _palette(SuitStyle style) => switch (style) {
        SuitStyle.menNavy => _SuitPalette(
            jacket: img.ColorRgba8(35, 46, 71, 255),
            lapel: img.ColorRgba8(26, 35, 56, 255),
            shirt: img.ColorRgba8(245, 245, 245, 255),
            tie: img.ColorRgba8(122, 31, 43, 255),
          ),
        SuitStyle.menCharcoal => _SuitPalette(
            jacket: img.ColorRgba8(46, 46, 51, 255),
            lapel: img.ColorRgba8(34, 34, 38, 255),
            shirt: img.ColorRgba8(245, 245, 245, 255),
            tie: img.ColorRgba8(31, 42, 68, 255),
          ),
        SuitStyle.womenNavy => _SuitPalette(
            jacket: img.ColorRgba8(35, 46, 71, 255),
            lapel: img.ColorRgba8(26, 35, 56, 255),
            shirt: img.ColorRgba8(240, 240, 240, 255),
            tie: img.ColorRgba8(240, 240, 240, 255),
          ),
        SuitStyle.none => throw StateError('unreachable'),
      };
}

class _SuitPalette {
  const _SuitPalette(
      {required this.jacket,
      required this.lapel,
      required this.shirt,
      required this.tie});

  final img.Color jacket;
  final img.Color lapel;
  final img.Color shirt;
  final img.Color tie;
}
