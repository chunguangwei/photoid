// 验收 #0：目标引擎（fork 插件 + onnxruntime-c 1.30.0）真机加载并前向
// EmbeddingGemma 2 q4f16 双图（opset21 + MatMulNBits/GatherBlockQuantized）。
// 运行：flutter test integration_test/ort_q4f16_smoke_test.dart -d <device> \
//   --dart-define=SMOKE_DIR=<目录含两图与同名 .onnx_data>
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('q4f16 vision + text graphs load and run on-device', (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(docs.path);
    final sizes = {
      'vision_encoder_q4f16.onnx': 150693,
      'vision_encoder_q4f16.onnx_data': 97614336,
      'model_q4f16.onnx': 495298,
      'model_q4f16.onnx_data': 156862464,
    };
    // Integration reinstall recreates the container; a concurrent pusher uploads
    // the graphs here. Wait until every file is fully transferred (size match —
    // devicectl copies appear immediately but stream for minutes).
    for (var i = 0; i < 140; i++) {
      if (sizes.entries.every((e) =>
          File('${dir.path}/${e.key}').existsSync() &&
          File('${dir.path}/${e.key}').lengthSync() == e.value)) {
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    for (final e in sizes.entries) {
      expect(File('${dir.path}/${e.key}').lengthSync(), e.value,
          reason: 'missing/truncated ${e.key}');
    }
    final sw = Stopwatch()..start();
    OrtEnv.instance.init();
    final opts = OrtSessionOptions();
    final v =
        OrtSession.fromFile(File('${dir.path}/vision_encoder_q4f16.onnx'), opts);
    final px = Float32List(280 * 768);
    for (var i = 0; i < px.length; i++) {
      px[i] = (i % 997) / 997.0;
    }
    final pid = Int64List(280 * 2);
    for (var i = 0; i < 280; i++) {
      pid[2 * i] = i ~/ 20;
      pid[2 * i + 1] = i % 20;
    }
    final pxV = OrtValueTensor.createTensorWithDataList(
        px, [1, 280, 768]);
    final pidV = OrtValueTensor.createTensorWithDataList(pid, [1, 280, 2]);
    final feats = (v
        .run(OrtRunOptions(), {'pixel_values': pxV, 'pixel_position_ids': pidV})[0]!
        as OrtValueTensor)
        .value as List;
    final n = feats.length;
    expect(n, greaterThan(0));
    final packed = Float32List(n * 512);
    for (var row = 0; row < n; row++) {
      final r = (feats[row] as List).cast<num>();
      for (var c = 0; c < 512; c++) {
        packed[row * 512 + c] = r[c].toDouble();
      }
    }
    expect(packed.every((e) => e.isFinite), isTrue);
    final m = OrtSession.fromFile(File('${dir.path}/model_q4f16.onnx'), opts);
    // One <|image|> placeholder per image; the graph scatters the n feature
    // rows at that position internally (verified on desktop ORT 1.27).
    final ids = Int64List(4)
      ..[0] = 2
      ..[1] = 4642
      ..[2] = 258880
      ..[3] = 1;
    final mask = Int64List(4)..fillRange(0, 4, 1);
    final idsV = OrtValueTensor.createTensorWithDataList(ids, [1, 4]);
    final maskV = OrtValueTensor.createTensorWithDataList(mask, [1, 4]);
    final featV = OrtValueTensor.createTensorWithDataList(packed, [n, 512]);
    final empty =
        OrtValueTensor.createTensorWithDataList(Float32List(0), [0, 512]);
    final out = m.run(OrtRunOptions(), {
      'input_ids': idsV,
      'attention_mask': maskV,
      'image_features': featV,
      'video_features': empty,
      'audio_features': empty
    });
    final emb = (out[1] as OrtValueTensor).value as List;
    final row = (emb.first as List).cast<num>().map((e) => e.toDouble()).toList();
    expect(row.length, 768);
    expect(row.every((e) => e.isFinite), isTrue);
    var norm = 0.0;
    for (final e in row) {
      norm += e * e;
    }
    expect((norm - 1).abs() < 1e-2, isTrue,
        reason: 'sentence_embedding must stay L2-normalized');
    // ignore: avoid_print
    print('ORT q4f16 smoke OK: $n image tokens, ${sw.elapsedMilliseconds}ms total');
    pxV.release();
    pidV.release();
    idsV.release();
    maskV.release();
    featV.release();
    empty.release();
    v.release();
    m.release();
    opts.release();
    OrtEnv.instance.release();
  });
}
