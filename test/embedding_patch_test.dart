import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/embedding_session.dart';

/// 参考实现：逐 patch 独立构造（与 embeddingPatchLayout 的行主序
/// 图像扫描完全不同的遍历顺序），验证布局不是自反推的镜像。
/// 与主函数一样不缩放：只搬运 uint8 值。
Float32List referencePatchLayout(Uint8List bytes) {
  final out = Float32List(kEmbNumPatches * kEmbPatchDim);
  for (var pr = 0; pr < kEmbRows; pr++) {
    for (var pc = 0; pc < kEmbCols; pc++) {
      final patchBase = (pr * kEmbCols + pc) * kEmbPatchDim;
      for (var dy = 0; dy < kEmbPatchSize; dy++) {
        for (var dx = 0; dx < kEmbPatchSize; dx++) {
          final imgRow = pr * kEmbPatchSize + dy;
          final imgCol = pc * kEmbPatchSize + dx;
          final src = (imgRow * kEmbImgWidth + imgCol) * 3;
          final o = patchBase + (dy * kEmbPatchSize + dx) * 3;
          out[o] = bytes[src].toDouble();
          out[o + 1] = bytes[src + 1].toDouble();
          out[o + 2] = bytes[src + 2].toDouble();
        }
      }
    }
  }
  return out;
}

void main() {
  group('embeddingPatchLayout', () {
    test('常量几何 = 320x224 / 14x20 patch / 768 维', () {
      expect(kEmbImgWidth, 320);
      expect(kEmbImgHeight, 224);
      expect(kEmbPatchSize, 16);
      expect(kEmbCols, 20);
      expect(kEmbRows, 14);
      expect(kEmbNumPatches, 280);
      expect(kEmbPatchDim, 768);
    });

    test('长度不符抛 ArgumentError', () {
      expect(() => embeddingPatchLayout(Uint8List(10)),
          throwsA(isA<ArgumentError>()));
      expect(() => embeddingPatchLayout(Uint8List(kEmbNumPatches * kEmbPatchDim + 3)),
          throwsA(isA<ArgumentError>()));
    });

    test('角点/边界 patch 抽样值精确落位', () {
      // 只有像素 (r,c) 非零的图，检查它进入哪个 patch 的哪个 dot。
      Uint8List singlePixel(int r, int c, int v) {
        final b = Uint8List(kEmbNumPatches * kEmbPatchDim);
        b[(r * kEmbImgWidth + c) * 3] = v; // 仅 R 通道
        return b;
      }

      // 左上角 (0,0) → patch 0, dot 0, R
      var out = embeddingPatchLayout(singlePixel(0, 0, 255));
      expect(out[0], 255);
      expect(out[1], 0);

      // 右下角 (223,319) → patch (13,19)=279, dot (15,15)=255（16×16=256
      // dot/patch）, R —— 即整个输出的最后一段首字节
      out = embeddingPatchLayout(singlePixel(223, 319, 255));
      final lastBase = 279 * kEmbPatchDim + 255 * 3;
      expect(lastBase, kEmbNumPatches * kEmbPatchDim - 3);
      expect(out[lastBase], 255);
      expect(out.where((e) => e != 0).length, 1);

      // patch 边界 (16,16) → patch (1,1)=21, dot 0
      out = embeddingPatchLayout(singlePixel(16, 16, 7));
      expect(out[21 * kEmbPatchDim], 7);

      // 跨列换行 (0,20) → patch (0,1)=1, dot (0,4)（20%16=4）→ 段内偏移 12
      out = embeddingPatchLayout(singlePixel(0, 20, 9));
      expect(out[1 * kEmbPatchDim + 12], 9);

      // G/B 通道同偏移：像素 (0,1) 属 patch 0 的 dot 1 → R 在段内偏移 3，
      // 其 G 落在偏移 4（输入字节 4 = 该像素 G）。
      final g = Uint8List(kEmbNumPatches * kEmbPatchDim)..[3 + 1] = 42;
      expect(embeddingPatchLayout(g)[4], 42);
    });

    test('随机图（伪随机固定种子）与逐 patch 参考实现逐元素一致', () {
      final rnd = math.Random(20261110);
      final bytes = Uint8List.fromList(
          List.generate(kEmbNumPatches * kEmbPatchDim, (_) => rnd.nextInt(256)));
      final actual = embeddingPatchLayout(bytes);
      final expected = referencePatchLayout(bytes);
      expect(actual.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        // Float32 存储 uint8 精确；两侧同为 uint8→double→f32，等值。
        expect(actual[i], expected[i], reason: 'mismatch at $i');
      }
    });

    test('线性渐变图整图值域正确（0..1）', () {
      final bytes = Uint8List(kEmbNumPatches * kEmbPatchDim);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = i % 256;
      }
      final out = embeddingPatchLayout(bytes);
      expect(out.reduce(math.max), 255);
      expect(out.reduce(math.min), 0);
      // 布局是置换：每个值出现次数与输入一致。
      final inCounts = <int, int>{};
      for (final b in bytes) {
        inCounts[b] = (inCounts[b] ?? 0) + 1;
      }
      final outCounts = <double, int>{};
      for (final v in out) {
        outCounts[v] = (outCounts[v] ?? 0) + 1;
      }
      expect(outCounts.length, inCounts.length);
      for (final e in inCounts.entries) {
        expect(outCounts[e.key.toDouble()], e.value);
      }
    });
  });

  group('embeddingPatchPositionIds', () {
    test('280×2，patch i → (i~/20, i%20) 行主序', () {
      final pid = embeddingPatchPositionIds();
      expect(pid.length, 280 * 2);
      expect(pid.sublist(0, 2), [0, 0]);
      expect(pid.sublist(2, 4), [0, 1]);
      expect(pid.sublist(38, 40), [0, 19]); // i=19
      expect(pid.sublist(40, 42), [1, 0]); // i=20
      expect(pid.sublist(558, 560), [13, 19]); // i=279 末 patch
      for (var i = 0; i < kEmbNumPatches; i++) {
        expect(pid[2 * i], i ~/ kEmbCols);
        expect(pid[2 * i + 1], i % kEmbCols);
      }
    });
  });

  test('queryText 官方前缀文案', () {
    expect(EmbeddingSession.queryText('红色的墙'),
        'task: search result | query: 红色的墙');
  });
}
