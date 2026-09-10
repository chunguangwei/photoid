import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/image_pipeline.dart';

/// 构造 480×640 纯色图 + 居中人脸框
(img.Image, Rect) _fixture() {
  final base = img.Image(width: 480, height: 640);
  img.fill(base, color: img.ColorRgb8(200, 180, 170));
  const face = Rect.fromLTWH(165, 120, 150, 180);
  return (base, face);
}

void main() {
  group('beautify 强度', () {
    test('强度 0 不修改任何像素', () {
      final (base, face) = _fixture();
      final out = ImagePipeline.beautify(base.clone(), face, 0);
      expect(out.getPixel(240, 220), base.getPixel(240, 220));
      expect(out.getPixel(50, 50), base.getPixel(50, 50));
    });

    test('强度 1：肤色区磨皮、非肤色像素（模拟眼睛）不被磨皮', () {
      final (base, face) = _fixture();
      // 模拟深棕色眼睛（不满足肤色门控：r=60 < 95）
      base.setPixelRgb(240, 220, 60, 40, 30);
      final out = ImagePipeline.beautify(base.clone(), face, 1.0);
      // 磨皮若生效会被拉向周边肤色 200；仅全图提亮（≤6%）属设计行为
      expect(out.getPixel(240, 220).r.toInt(), lessThan(80));
    });

    test('强度提升单调增加提亮（色相顺序保持）', () {
      final (base, face) = _fixture();
      final corner = base.getPixel(5, 5);
      final weak = ImagePipeline.beautify(base.clone(), face, 0.3);
      final strong = ImagePipeline.beautify(base.clone(), face, 1.0);
      // 角落（椭圆外）：仅提亮，且强度越高越亮
      expect(strong.getPixel(5, 5).r.toInt(),
          greaterThanOrEqualTo(weak.getPixel(5, 5).r.toInt()));
      expect(weak.getPixel(5, 5).r.toInt(),
          greaterThanOrEqualTo(corner.r.toInt()));
      // 通道顺序保持（不变色）
      final c = strong.getPixel(5, 5);
      expect(c.r.toInt(), greaterThan(c.g.toInt()));
      expect(c.g.toInt(), greaterThan(c.b.toInt()));
    });
  });
}
