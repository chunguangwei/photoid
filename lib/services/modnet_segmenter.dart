import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// MODNet 发丝级抠图（hivision_modnet，HivisionIDPhotos 自训练，MIT）。
/// 懒加载常驻 session；任何初始化/推理失败抛异常由调用方回退 ML Kit。
class ModnetSegmenter {
  ModnetSegmenter._();

  static const _modelAsset = 'assets/models/hivision_modnet.onnx';
  static const _inputSize = 512;

  static OrtSession? _session;
  static bool _initFailed = false;

  /// 初始化（幂等）。失败置 _initFailed，后续调用直接抛异常。
  static Future<void> _ensureSession() async {
    if (_session != null) return;
    if (_initFailed) throw StateError('MODNet unavailable');
    try {
      OrtEnv.instance.init();
      final model = await rootBundle.load(_modelAsset);
      _session = OrtSession.fromBuffer(
          model.buffer.asUint8List(), OrtSessionOptions());
    } catch (_) {
      _initFailed = true;
      rethrow;
    }
  }

  /// 对 [work] 图做人像分割，返回与 work 同尺寸的灰度掩码（0-255）。
  static Future<Uint8List> segment(img.Image work) async {
    await _ensureSession();
    // 预处理：resize 512×512，RGB 归一化到 [-1,1]，NCHW float32
    final resized =
        img.copyResize(work, width: _inputSize, height: _inputSize);
    final px = resized.getBytes(order: img.ChannelOrder.rgb);
    final input = Float32List(3 * _inputSize * _inputSize);
    final plane = _inputSize * _inputSize;
    for (var i = 0; i < plane; i++) {
      input[i] = px[i * 3] / 255.0 * 2 - 1; // R
      input[plane + i] = px[i * 3 + 1] / 255.0 * 2 - 1; // G
      input[plane * 2 + i] = px[i * 3 + 2] / 255.0 * 2 - 1; // B
    }
    final inputOrt = OrtValueTensor.createTensorWithDataList(
        input, [1, 3, _inputSize, _inputSize]);
    final outputs = _session!.run(OrtRunOptions(), {'input': inputOrt});
    inputOrt.release();
    final outOrt = outputs.first as OrtValueTensor;
    // 输出 matte [1,1,512,512]（0-1 float），嵌套 list 扁平化
    final flat = Float32List(plane);
    var idx = 0;
    void walk(dynamic v) {
      if (v is List) {
        for (final e in v) {
          walk(e);
        }
      } else if (idx < plane) {
        flat[idx++] = (v as num).toDouble();
      }
    }
    walk(outOrt.value);
    outOrt.release();

    // → 缩放到 work 尺寸的 0-255 灰度掩码
    final maskBytes = Uint8List(plane);
    for (var i = 0; i < plane; i++) {
      maskBytes[i] = (flat[i].clamp(0.0, 1.0) * 255).round();
    }
    var maskImg = img.Image.fromBytes(
        width: _inputSize,
        height: _inputSize,
        bytes: maskBytes.buffer,
        numChannels: 1);
    if (maskImg.width != work.width || maskImg.height != work.height) {
      maskImg = img.copyResize(maskImg,
          width: work.width,
          height: work.height,
          interpolation: img.Interpolation.linear);
    }
    return maskImg.getBytes();
  }
}
