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
