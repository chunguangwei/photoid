import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/image_pipeline.dart';

/// 造一张 w×h 的 RGBA 工作图：上半蓝、下半肤色（模拟换底后的合成图）
Uint8List _workRgba(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final top = y < h ~/ 2;
      rgba[i] = top ? 67 : 200;
      rgba[i + 1] = top ? 142 : 180;
      rgba[i + 2] = top ? 219 : 170;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

final _bg = Uint8List.fromList([67, 142, 219]);

DeliveryRequest _req({
  required Rect crop,
  double beauty = 0,
  double clarity = 0,
  bool sharpen = false,
}) =>
    DeliveryRequest(
      rgba: _workRgba(300, 400),
      width: 300,
      height: 400,
      crop: crop,
      faceRect: const Rect.fromLTWH(100, 120, 100, 120),
      targetWidth: 295,
      targetHeight: 413,
      bg: _bg,
      minKb: 10,
      maxKb: 500,
      beauty: beauty,
      clarity: clarity,
      sharpen: sharpen,
    );

void main() {
  // compute() 会真的 spawn isolate，这里验证的是**跨 isolate 传参契约**：
  // DeliveryRequest/PreviewRequest 里带了 dart:ui 的 Rect，若不可序列化
  // 会在真机上直接抛异常——静态分析和纯函数单测都发现不了。
  group('isolate 交付契约（真实 compute）', () {
    test('deliverWorker 跨 isolate 出片，尺寸与格式符合规格', () async {
      final jpg = await compute(
          deliverWorker, _req(crop: const Rect.fromLTWH(20, 30, 240, 320)));
      final decoded = img.decodeJpg(jpg);
      expect(decoded, isNotNull);
      expect(decoded!.width, 295);
      expect(decoded.height, 413);
      expect(jpg.lengthInBytes / 1024, lessThanOrEqualTo(500));
    });

    test('越界裁剪框由底色补边，不抛异常且四角为底色', () async {
      // 框整体向上、向左越界（模拟人物顶天立地的情形）
      final jpg = await compute(
          deliverWorker, _req(crop: const Rect.fromLTWH(-60, -80, 240, 320)));
      final decoded = img.decodeJpg(jpg)!;
      expect(decoded.width, 295);
      // 左上角必然落在补边区，应为底色（JPEG 有损，给宽容差）
      final c = decoded.getPixel(3, 3);
      expect((c.r.toInt() - 67).abs(), lessThan(24));
      expect((c.g.toInt() - 142).abs(), lessThan(24));
      expect((c.b.toInt() - 219).abs(), lessThan(24));
    });

    test('开启美颜+清晰度+锐化不崩溃，输出仍合规', () async {
      final jpg = await compute(
          deliverWorker,
          _req(
              crop: const Rect.fromLTWH(20, 30, 240, 320),
              beauty: 1.0,
              clarity: 1.0,
              sharpen: true));
      final decoded = img.decodeJpg(jpg);
      expect(decoded, isNotNull);
      expect(decoded!.width, 295);
      expect(decoded.height, 413);
    });

    test('previewWorker 跨 isolate 产出可解码预览，尺寸等于工作图', () async {
      final jpg = await compute(
        previewWorker,
        PreviewRequest(
          rgba: _workRgba(200, 260),
          width: 200,
          height: 260,
          faceRect: const Rect.fromLTWH(60, 70, 80, 100),
          beauty: 0.8,
          clarity: 0.5,
        ),
      );
      final decoded = img.decodeJpg(jpg);
      expect(decoded, isNotNull);
      expect(decoded!.width, 200);
      expect(decoded.height, 260);
    });
  });
}
