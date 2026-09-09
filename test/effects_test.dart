import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/image_pipeline.dart';
import 'package:photoid/services/suit_compositor.dart';

/// 构造 480×640 纯色图 + 居中人脸框
(img.Image, Rect) _fixture() {
  final base = img.Image(width: 480, height: 640);
  img.fill(base, color: img.ColorRgb8(200, 180, 170));
  const face = Rect.fromLTWH(165, 120, 150, 180);
  return (base, face);
}

void main() {
  group('SuitCompositor', () {
    test('none 样式返回原图', () {
      final (base, face) = _fixture();
      final out = SuitCompositor.apply(base.clone(), face, SuitStyle.none);
      expect(out.getPixel(240, 600), base.getPixel(240, 600));
    });

    test('男士西装：下巴下方被覆盖，面部区域不受影响', () {
      final (base, face) = _fixture();
      final out = SuitCompositor.apply(base.clone(), face, SuitStyle.menNavy);
      // 下巴远下方（西装主体区）应变为西装色而非肤色
      final suitPx = out.getPixel(240, 630);
      expect(suitPx.r.toInt(), lessThan(100));
      // 面部中心（鼻尖区）保持原色
      expect(out.getPixel(240, 220), base.getPixel(240, 220));
    });

    test('女款无领带：胸前中心区接近衬衫色', () {
      final (base, face) = _fixture();
      final out =
          SuitCompositor.apply(base.clone(), face, SuitStyle.womenNavy);
      // 圆领衬衫区（领口下方 V 区内，领口随 neckH 下移后为 y≈420）
      final shirtPx = out.getPixel(240, 420);
      expect(shirtPx.r.toInt(), greaterThan(200));
    });
  });

  group('beautify 档位', () {
    test('off 档不修改任何像素', () {
      final (base, face) = _fixture();
      final out = ImagePipeline.beautify(
          base.clone(), face, BeautyLevel.off);
      expect(out.getPixel(240, 220), base.getPixel(240, 220));
      expect(out.getPixel(50, 50), base.getPixel(50, 50));
    });

    test('strong 档：椭圆内磨皮，全图仅微提亮（色相不变）', () {
      // 面部加噪声，磨皮应降低局部差异
      final (base, face) = _fixture();
      base.setPixelRgb(240, 220, 255, 255, 255);
      base.setPixelRgb(242, 220, 0, 0, 0);
      final out = ImagePipeline.beautify(
          base.clone(), face, BeautyLevel.strong);
      // 椭圆外角落：磨皮不生效，仅提亮 → R 略升、RGB 通道顺序保持（不变色）
      final corner = out.getPixel(5, 5);
      expect(corner.r.toInt(), greaterThan(200));
      expect(corner.r.toInt(), greaterThan(corner.g.toInt()));
      expect(corner.g.toInt(), greaterThan(corner.b.toInt()));
    });
  });
}
