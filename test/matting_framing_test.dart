import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/image_pipeline.dart';

/// 造一张 w×h 的掩码：矩形「人物」区域为 255，其余为 0。
Uint8List _maskWithBody(int w, int h, Rect body) {
  final m = Uint8List(w * h);
  for (var y = body.top.toInt(); y < body.bottom.toInt(); y++) {
    for (var x = body.left.toInt(); x < body.right.toInt(); x++) {
      if (x >= 0 && x < w && y >= 0 && y < h) m[y * w + x] = 255;
    }
  }
  return m;
}

void main() {
  group('refineAlpha 不得啃掉人像轮廓（旧版腐蚀导致「头发/耳朵没了」的回归）',
      () {
    test('实心区域精修后仍为实心，面积不缩水', () {
      const w = 64, h = 64;
      const body = Rect.fromLTWH(16, 16, 32, 32);
      final out = refineAlpha(_maskWithBody(w, h, body), w, h);

      // 人物内部必须仍是全不透明
      expect(out[32 * w + 32], 255, reason: '实心区域不得被削弱');

      // 面积不允许出现整体内缩（旧版 3×3 min-filter 会缩掉一圈）
      var area = 0;
      for (final v in out) {
        if (v > 128) area++;
      }
      expect(area, greaterThanOrEqualTo(30 * 30),
          reason: '轮廓最多因羽化损失亚像素，不得整体腐蚀 1px 以上');
    });

    test('半透明发丝带（alpha 128）必须存活，不被阈值截断归零', () {
      const w = 32, h = 32;
      final m = Uint8List(w * h);
      // 一整片中等透明度区域，模拟发丝/毛边
      for (var i = 0; i < m.length; i++) {
        m[i] = 128;
      }
      final out = refineAlpha(m, w, h);
      expect(out[16 * w + 16], greaterThan(60),
          reason: '旧版 (a-0.35)/0.5 会把发丝带压没，这是「头发消失」的根因');
    });

    test('纯背景噪点被清零', () {
      const w = 16, h = 16;
      final m = Uint8List(w * h);
      for (var i = 0; i < m.length; i++) {
        m[i] = 10; // < 6% 阈值附近的背景残噪
      }
      final out = refineAlpha(m, w, h);
      expect(out[8 * w + 8], 0);
    });
  });

  group('detectHeadTop 真实发际线定位', () {
    test('返回人物顶部所在行（容差 2px）', () {
      const w = 64, h = 64;
      const body = Rect.fromLTWH(16, 20, 32, 40);
      final alpha = _maskWithBody(w, h, body);
      final top = detectHeadTop(alpha, w, h);
      expect(top, isNotNull);
      expect((top! - 20).abs(), lessThanOrEqualTo(2));
    });

    test('全空掩码返回 null（交由人脸框兜底）', () {
      expect(detectHeadTop(Uint8List(64 * 64), 64, 64), isNull);
    });

    test('单行孤立噪点不触发（需连续 2 行命中）', () {
      const w = 64, h = 64;
      final alpha = Uint8List(w * h);
      for (var x = 0; x < 40; x++) {
        alpha[3 * w + x] = 255; // 只有第 3 行有内容
      }
      // 真正的人物从第 30 行开始
      for (var y = 30; y < 60; y++) {
        for (var x = 16; x < 48; x++) {
          alpha[y * w + x] = 255;
        }
      }
      final top = detectHeadTop(alpha, w, h);
      expect(top, isNotNull);
      expect(top!, greaterThan(20), reason: '不应被第 3 行的孤立噪点带偏');
    });
  });

  group('cropRectFor 构图（允许越界，交付时底色补边）', () {
    const aspect = 0.75; // 宽/高

    test('比例严格锁定为规格比例', () {
      final r = cropFor(1000, 1000, const Rect.fromLTWH(400, 300, 200, 240));
      expect(r.width / r.height, closeTo(aspect, 0.01));
    });

    test('人物顶天立地时裁剪框向上越界，而不是切掉头顶', () {
      // 头顶紧贴图像上沿（headTop=0）
      final r = ImagePipeline.cropRectFor(
          800, 1000, const Rect.fromLTWH(300, 40, 200, 240), aspect,
          headTop: 0);
      expect(r.top, lessThan(0),
          reason: '必须越界留出头顶白边；旧版 clamp 到 0 会导致构图压头');
    });

    test('底边永不越界（身体下方不允许悬空底色）', () {
      final r = ImagePipeline.cropRectFor(
          800, 1000, const Rect.fromLTWH(300, 700, 200, 240), aspect,
          headTop: 620);
      expect(r.bottom, lessThanOrEqualTo(1000.0));
    });

    test('头顶始终在裁剪框内（任何情况下都不切头）', () {
      for (final headTop in [0.0, 50.0, 200.0, 600.0]) {
        final r = ImagePipeline.cropRectFor(
            800, 1000, Rect.fromLTWH(300, headTop + 90, 200, 240), aspect,
            headTop: headTop);
        expect(r.top, lessThanOrEqualTo(headTop),
            reason: 'headTop=$headTop 时头顶被切出画面');
      }
    });

    test('掩码头顶不可信时回退到人脸框推算，不崩溃', () {
      // headTop 高于人脸框太多（举手/帽饰误判）→ 应忽略
      final withBad = ImagePipeline.cropRectFor(
          800, 1000, const Rect.fromLTWH(300, 400, 200, 240), aspect,
          headTop: 5);
      final withNone = ImagePipeline.cropRectFor(
          800, 1000, const Rect.fromLTWH(300, 400, 200, 240), aspect);
      expect(withBad.height, closeTo(withNone.height, 1.0));
    });

    test('画幅不超过源图 1.5 倍（防补边过量与内存放大）', () {
      // 极端大头照：人脸几乎占满全图
      final r = ImagePipeline.cropRectFor(
          800, 1000, const Rect.fromLTWH(50, 50, 700, 900), aspect,
          headTop: 0);
      expect(r.width, lessThanOrEqualTo(800 * 1.5 + 1));
      expect(r.height, lessThanOrEqualTo(1000 * 1.5 + 1));
    });

    test('头部占比落在合规区间 45%–85% 内', () {
      const face = Rect.fromLTWH(300, 300, 200, 240);
      const headTop = 190.0; // 头顶
      final r = ImagePipeline.cropRectFor(800, 1000, face, aspect,
          headTop: headTop);
      final headRatio = (face.bottom - headTop) / r.height;
      expect(headRatio, inInclusiveRange(0.45, 0.85));
    });
  });

  group('decontaminate 消白边不改 alpha', () {
    test('边缘像素被拉向前景色，纯前景/纯背景像素不动', () {
      const w = 8, h = 8;
      final rgba = Uint8List(w * h * 4);
      final alpha = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          // 左半：纯前景红；右半：白色原背景
          final isFg = x < 4;
          rgba[i] = isFg ? 200 : 255;
          rgba[i + 1] = isFg ? 40 : 255;
          rgba[i + 2] = isFg ? 40 : 255;
          rgba[i + 3] = 255;
          alpha[y * w + x] = isFg ? 255 : 0;
        }
      }
      // 制造一列半透明边缘，颜色被白背景污染
      for (var y = 0; y < h; y++) {
        alpha[y * w + 3] = 120;
        final i = (y * w + 3) * 4;
        rgba[i] = 230;
        rgba[i + 1] = 150;
        rgba[i + 2] = 150;
      }

      final out = decontaminate(rgba, alpha, w, h);
      final edge = (4 * w + 3) * 4;
      expect(out[edge + 1], lessThan(150),
          reason: '边缘绿通道应被拉向纯前景（40），即消白边');

      final pureFg = (4 * w + 1) * 4;
      expect(out[pureFg], 200, reason: '纯前景像素不得改动');
      final pureBg = (4 * w + 6) * 4;
      expect(out[pureBg], 255, reason: '纯背景像素不得改动');
    });

    test('解混只允许变暗，绝不把边缘拉亮（白色光晕回归）', () {
      const w = 8, h = 8;
      final rgba = Uint8List(w * h * 4);
      final alpha = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final isFg = x < 4;
          // 前景是**亮色**（浅色衣服），边缘偏暗——若允许双向替换，
          // 解混会把边缘往亮拉，视觉上就是头发/肩线外一圈发光。
          rgba[i] = isFg ? 240 : 20;
          rgba[i + 1] = isFg ? 240 : 20;
          rgba[i + 2] = isFg ? 240 : 20;
          rgba[i + 3] = 255;
          alpha[y * w + x] = isFg ? 255 : 0;
        }
      }
      for (var y = 0; y < h; y++) {
        alpha[y * w + 3] = 120;
        final i = (y * w + 3) * 4;
        rgba[i] = rgba[i + 1] = rgba[i + 2] = 90;
      }
      final out = decontaminate(rgba, alpha, w, h);
      final edge = (4 * w + 3) * 4;
      expect(out[edge], lessThanOrEqualTo(90),
          reason: '解混方向必须单向变暗；变亮即产生白色光晕');
    });
  });

  group('keepMainSubject 清飞地 + 填孔洞', () {
    test('角落孤立小块被清零，主体保留', () {
      const w = 64, h = 64;
      final alpha = _maskWithBody(w, h, const Rect.fromLTWH(16, 16, 32, 32));
      // 右下角一块 4×4 飞地（模拟被误判成前景的建筑/地面）
      for (var y = 58; y < 62; y++) {
        for (var x = 58; x < 62; x++) {
          alpha[y * w + x] = 255;
        }
      }
      keepMainSubject(alpha, w, h);
      expect(alpha[60 * w + 60], 0, reason: '飞地必须清掉');
      expect(alpha[32 * w + 32], 255, reason: '主体必须保留');
    });

    test('主体内部孔洞被填实', () {
      const w = 64, h = 64;
      final alpha = _maskWithBody(w, h, const Rect.fromLTWH(16, 16, 32, 32));
      for (var y = 30; y < 34; y++) {
        for (var x = 30; x < 34; x++) {
          alpha[y * w + x] = 0; // 躯干中间被误判成背景
        }
      }
      keepMainSubject(alpha, w, h);
      expect(alpha[32 * w + 32], 255, reason: '被主体包围的孔洞必须填实');
      expect(alpha[2 * w + 2], 0, reason: '真背景不得被填');
    });

    test('全背景掩码不抛异常（交由上层报 noPerson）', () {
      final alpha = Uint8List(32 * 32);
      expect(() => keepMainSubject(alpha, 32, 32), returnsNormally);
    });
  });

  group('refineAlpha 高端饱和（人物半透明溶解回归）', () {
    test('MODNet 中高置信区（a≈0.7）必须判为实心前景', () {
      const w = 32, h = 32;
      final m = Uint8List(w * h);
      for (var i = 0; i < m.length; i++) {
        m[i] = 180; // ≈0.71，衣服/肩背这类低对比区的典型输出
      }
      final out = refineAlpha(m, w, h);
      expect(out[16 * w + 16], 255,
          reason: '对称拉伸会让它停在半透明，观感是人物从胸口往下溶解进底色');
    });
  });
}

/// 便捷包装：默认 aspect=0.75
Rect cropFor(int w, int h, Rect face, {double? headTop}) =>
    ImagePipeline.cropRectFor(w, h, face, 0.75, headTop: headTop);
