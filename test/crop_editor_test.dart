import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/pages/crop_editor.dart';

/// 构造真实 JPEG 字节
Uint8List _jpg(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(120, 140, 160));
  return Uint8List.fromList(img.encodeJpg(im, quality: 85));
}

void main() {
  // 浮点误差回归：disp 与窗口理论相等时 `_window - disp` 为 +ε，
  // clamp(下界>上界) 曾抛 ArgumentError（release 灰盒）。
  // 覆盖多组宽高比/图像尺寸组合，断言构建与拖动均不抛异常。
  final cases = <(int, int, double)>[
    (480, 640, 0.75), // 学生报名照：与窗口同比例（ε 高发）
    (295, 413, 295 / 413), // 一寸
    (413, 295, 413 / 295), // 横图
    (1200, 1600, 0.75),
    (1000, 1000, 1.0),
    (3000, 2000, 0.75),
  ];

  for (final (w, h, aspect) in cases) {
    testWidgets('CropEditor $w×$h aspect=$aspect 不抛异常', (tester) async {
      final bytes = _jpg(w, h);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: CropEditor(
              imageBytes: bytes,
              imageWidth: w,
              imageHeight: h,
              autoCrop: Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
              aspect: aspect,
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 模拟拖动（触发 _clampAll）
      await tester.drag(
          find.byType(CropEditor), const Offset(30, 30));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
