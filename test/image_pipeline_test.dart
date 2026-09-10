import 'package:photoid/services/modnet_segmenter.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/services/image_pipeline.dart';

/// 固定 LCG（Numerical Recipes 常数），输出完全确定，不依赖时间/随机种子。
int _lcg(int state) => (state * 1664525 + 1013904223) & 0xFFFFFFFF;

/// 480×640 纯蓝底图（与交付底色 RGB(67,142,219) 一致）。
img.Image _blueImage() {
  final image = img.Image(width: 480, height: 640);
  img.fill(image, color: img.ColorRgb8(67, 142, 219));
  return image;
}

/// 480×640 伪随机噪声图（逐像素 LCG 生成），JPEG 难以压缩，
/// 保证初始 q85 编码远超常规下限，用于测试可达区间的命中。
img.Image _noiseImage() {
  final image = img.Image(width: 480, height: 640);
  var state = 0x12345678;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      state = _lcg(state);
      final r = (state >> 16) & 0xFF;
      state = _lcg(state);
      final g = (state >> 16) & 0xFF;
      state = _lcg(state);
      final b = (state >> 16) & 0xFF;
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return image;
}

double _kb(Uint8List bytes) => bytes.lengthInBytes / 1024;

void _expectDecodableWithSameSize(Uint8List bytes, int w, int h) {
  final decoded = img.decodeJpg(bytes);
  expect(decoded, isNotNull, reason: '输出必须是合法 JPEG');
  expect(decoded!.width, w);
  expect(decoded.height, h);
}

void main() {
  group('ImagePipeline.encodeToKbRange', () {
    test('高熵噪声图落在可达区间 [10, 500]KB 且可解码、尺寸不变', () {
      final out = ImagePipeline.encodeToKbRange(_noiseImage(), 10, 500);
      expect(_kb(out), inInclusiveRange(10, 500));
      _expectDecodableWithSameSize(out, 480, 640);
    });

    test('蓝底图在常规区间输出不超过 500KB 且可解码、尺寸不变', () {
      // 纯平图高度可压缩，编码器只会向下压质量，无法把体积抬到下限以上，
      // 因此只断言上限与可解码性（可观察契约），不断言 ≥ minKb。
      final out = ImagePipeline.encodeToKbRange(_blueImage(), 10, 500);
      expect(_kb(out), lessThanOrEqualTo(500));
      _expectDecodableWithSameSize(out, 480, 640);
    });

    test('极端小区间 [10, 15]KB：蓝底图输出不超过 15KB 且可解码', () {
      // 初始 best 为 quality:85 编码结果，可能本身超 maxKb；
      // 只断言最终输出 ≤ maxKb（guard 循环兜底），不编码器内部行为。
      final out = ImagePipeline.encodeToKbRange(_blueImage(), 10, 15);
      expect(_kb(out), lessThanOrEqualTo(15));
      _expectDecodableWithSameSize(out, 480, 640);
    });
  });

  test('encodeToKbRange：min 达不到时 EOI 后填充补齐', () {
    // 纯色图即使 q98 也很小，天然达不到 min
    final image = img.Image(width: 295, height: 413);
    img.fill(image, color: img.ColorRgb8(67, 142, 219));
    final out = ImagePipeline.encodeToKbRange(image, 200, 500);
    // 必须恰好 200KB（填充后）
    expect(out.lengthInBytes, 200 * 1024);
    // 且仍是合法 JPEG：解码器读到 FFD9 即止
    final decoded = img.decodeJpg(out);
    expect(decoded, isNotNull);
    expect(decoded!.width, 295);
  });

  test('MODNet 模型输入维度约束钉死为 512（真机实证非 512 报 invalid dimensions）',
      () {
    expect(ModnetSegmenter.inputSize, 512);
  });
}
