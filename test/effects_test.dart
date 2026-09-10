import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/photo_effects.dart';

/// 480×640 纯肤色图 + 居中人脸框
(img.Image, Rect) _fixture() {
  final base = img.Image(width: 480, height: 640);
  img.fill(base, color: img.ColorRgb8(200, 180, 170));
  const face = Rect.fromLTWH(165, 120, 150, 180);
  return (base, face);
}

int _dist(img.Pixel p, int r, int g, int b) =>
    (p.r.toInt() - r).abs() + (p.g.toInt() - g).abs() + (p.b.toInt() - b).abs();

void main() {
  group('PhotoEffects.apply 强度契约', () {
    test('两项强度均为 0 时短路返回原对象（零拷贝、零改动）', () {
      final (base, face) = _fixture();
      final out = PhotoEffects.apply(base, face);
      expect(identical(out, base), isTrue);
    });

    test('仅美颜 > 0 时不外溢到人脸椭圆之外', () {
      final (base, face) = _fixture();
      base.setPixelRgb(5, 5, 10, 200, 30); // 角落标记色
      final out = PhotoEffects.apply(base, face, beauty: 1.0);
      expect(_dist(out.getPixel(5, 5), 10, 200, 30), 0,
          reason: '面部精修只作用于人脸区域，这是与旧版全图提亮的关键差异');
    });

    test('美颜压制低幅瑕疵，同时保留非肤色的五官细节', () {
      final (base, face) = _fixture();
      base.setPixelRgb(240, 220, 208, 188, 178); // 低幅瑕疵（差 8）
      base.setPixelRgb(250, 230, 60, 40, 30); // 深色五官（非肤色）
      final out = PhotoEffects.apply(base, face, beauty: 1.0);

      expect(_dist(out.getPixel(240, 220), 200, 180, 170), lessThan(12),
          reason: '低幅细节（斑点/细纹）应被磨掉');
      expect(out.getPixel(250, 230).r.toInt(), lessThan(90),
          reason: '非肤色像素（眼/眉/唇）不参与磨皮');
    });

    test('清晰度作用于整图，且强度越高对比分离越强', () {
      final base = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final v = x < 32 ? 110 : 150;
          base.setPixelRgb(x, y, v, v, v);
        }
      }
      const face = Rect.fromLTWH(0, 0, 1, 1); // 面积极小，不触发面部通道
      final weak = PhotoEffects.apply(base.clone(), face, clarity: 0.3);
      final strong = PhotoEffects.apply(base.clone(), face, clarity: 1.0);

      int contrast(img.Image im) =>
          im.getPixel(60, 32).r.toInt() - im.getPixel(3, 32).r.toInt();

      expect(contrast(strong), greaterThan(contrast(weak)));
      expect(contrast(weak), greaterThanOrEqualTo(40),
          reason: '清晰度只应增强对比，不应削弱');
    });

    test('中频色斑必须被压制（「拉满也看不出效果」回归）', () {
      final (base, face) = _fixture();
      // 半径 12 的色斑，幅度 38——正是早期实现会当成「五官结构」全额保留的
      // 幅度区间，也是用户观感上最刺眼的瑕疵
      for (var y = 200; y < 224; y++) {
        for (var x = 228; x < 252; x++) {
          base.setPixelRgb(x, y, 162, 142, 132);
        }
      }
      final before = _dist(base.getPixel(240, 212), 200, 180, 170);
      final out = PhotoEffects.apply(base, face, beauty: 1.0);
      final after = _dist(out.getPixel(240, 212), 200, 180, 170);
      expect(after, lessThan(before * 0.75),
          reason: '幅度 38 的色斑属中频，单尺度高频磨皮碰不到它');
    });

    test('美颜强度单调可感知：50% 的改动量介于 0 与 100% 之间', () {
      double delta(double b) {
        final (base, face) = _fixture();
        for (var y = 200; y < 224; y++) {
          for (var x = 228; x < 252; x++) {
            base.setPixelRgb(x, y, 168, 148, 138);
          }
        }
        final out = PhotoEffects.apply(base, face, beauty: b);
        return _dist(out.getPixel(240, 212), 168, 148, 138).toDouble();
      }

      final half = delta(0.5), full = delta(1.0);
      expect(half, greaterThan(2), reason: '半强度就应看得出变化');
      expect(full, greaterThan(half), reason: '滑杆全程必须单调可感知');
    });

    test('阴影中的皮肤也参与美颜（旧版 RGB 硬判据会整片跳过）', () {
      final base = img.Image(width: 200, height: 200);
      // 暗部肤色：色度仍是皮肤，但亮度低，旧判据 r>95 直接判否
      img.fill(base, color: img.ColorRgb8(96, 74, 66));
      for (var y = 96; y < 104; y++) {
        for (var x = 96; x < 104; x++) {
          base.setPixelRgb(x, y, 78, 58, 52); // 暗部瑕疵
        }
      }
      const face = Rect.fromLTWH(50, 50, 100, 110);
      final out = PhotoEffects.apply(base, face, beauty: 1.0);
      expect(_dist(out.getPixel(100, 100), 78, 58, 52), greaterThan(2),
          reason: '色度域判据与亮度无关，阴影侧皮肤同样要被处理');
    });

    test('清晰度不产生彩色描边（只锐化亮度，不锐化色度）', () {
      // 灰阶竖边：任何通道差异都来自算法本身
      final base = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final v = x < 32 ? 90 : 170;
          base.setPixelRgb(x, y, v, v, v);
        }
      }
      final out = PhotoEffects.apply(
          base, const Rect.fromLTWH(0, 0, 1, 1), clarity: 1.0);
      for (var x = 28; x < 36; x++) {
        final p = out.getPixel(x, 32);
        expect((p.r.toInt() - p.g.toInt()).abs(), lessThanOrEqualTo(1),
            reason: '逐通道 USM 会让边缘产生紫边/绿边');
        expect((p.g.toInt() - p.b.toInt()).abs(), lessThanOrEqualTo(1));
      }
    });

    test('清晰度不压死暗部、不顶死高光（S 曲线而非线性对比）', () {
      final base = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          base.setPixelRgb(x, y, x < 16 ? 12 : 246, x < 16 ? 12 : 246,
              x < 16 ? 12 : 246);
        }
      }
      final out = PhotoEffects.apply(
          base, const Rect.fromLTWH(0, 0, 1, 1), clarity: 1.0);
      expect(out.getPixel(4, 16).r.toInt(), greaterThan(0),
          reason: '线性对比会把暗部直接压成纯黑，细节不可恢复');
      expect(out.getPixel(28, 16).r.toInt(), lessThan(255),
          reason: '高光同理不应顶死');
    });

    test('美颜带暖肤与提亮：肤色整体变暖变亮（气色感知的主要来源）', () {
      final (base, face) = _fixture();
      final out = PhotoEffects.apply(base, face, beauty: 1.0);
      final p = out.getPixel(240, 210); // 脸中心
      expect(p.r.toInt(), greaterThan(200), reason: '红通道应被暖肤抬高');
      expect(p.r.toInt() - 200, greaterThan(p.b.toInt() - 170),
          reason: '暖肤是红通道单独多加，不是整体等量提亮');
      expect(p.r.toInt(), lessThan(235), reason: '幅度须克制，不能过曝失真');
    });

    test('清晰度用鲜艳度而非线性饱和：灰淡区提升明显，肤色几乎不动', () {
      // 左半灰淡（低饱和），右半高饱和肤色
      final base = img.Image(width: 64, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 64; x++) {
          if (x < 32) {
            base.setPixelRgb(x, y, 140, 138, 134); // 近中性灰
          } else {
            base.setPixelRgb(x, y, 214, 150, 120); // 饱和肤色
          }
        }
      }
      final out = PhotoEffects.apply(
          base, const Rect.fromLTWH(0, 0, 1, 1), clarity: 1.0);

      int chroma(int x) {
        final p = out.getPixel(x, 16);
        final mx = [p.r.toInt(), p.g.toInt(), p.b.toInt()].reduce(math.max);
        final mn = [p.r.toInt(), p.g.toInt(), p.b.toInt()].reduce(math.min);
        return mx - mn;
      }

      // 灰淡区色度被拉开（原始 6）
      expect(chroma(8), greaterThan(6), reason: '低饱和区应获得鲜艳度增益');
      // 肤色区色度增幅须远小于线性饱和（原始 94；线性 ×1.3 会到 122）
      expect(chroma(56), lessThan(112),
          reason: '已饱和的肤色必须自动收手，否则发橙');
    });

    test('极端棋盘图锐化后不溢出回绕（始终钳在 0–255）', () {
      final base = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final v = (x + y).isEven ? 255 : 0;
          base.setPixelRgb(x, y, v, v, v);
        }
      }
      final out = PhotoEffects.apply(
          base, const Rect.fromLTWH(0, 0, 1, 1), clarity: 1.0);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final p = out.getPixel(x, y);
          for (final v in [p.r.toInt(), p.g.toInt(), p.b.toInt()]) {
            expect(v, inInclusiveRange(0, 255));
          }
        }
      }
    });
  });
}
