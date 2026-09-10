import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 图版截取式裁剪编辑器（行业通用交互，同微信头像/最美证件照）：
/// 视口内固定规格比例的「取图窗」，用户双指**等比**缩放 + 单指拖动照片。
/// 状态只有一个缩放因子 [_scale] 和偏移 [_offset]，导出裁剪框的高由
/// 宽 ÷ [aspect] 推导——结构上不可能产生非等比拉伸。
class CropEditor extends StatefulWidget {
  const CropEditor({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.autoCrop,
    required this.aspect, // 宽/高
    required this.onChanged,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;

  /// 自动构图初始框（仅用于初始化 scale/offset；输出始终由窗口+缩放推导）
  final Rect autoCrop;
  final double aspect;
  final ValueChanged<Rect> onChanged;

  @override
  State<CropEditor> createState() => CropEditorState();
}

class CropEditorState extends State<CropEditor> {
  ui.Image? _image;
  bool _decodeFailed = false;

  /// 用户缩放倍率（相对铺满窗口的基准），≥1
  double _scale = 1;

  /// 图片左上角相对取图窗左上角的偏移（窗口坐标系，≤0）
  Offset _offset = Offset.zero;

  Size _viewport = Size.zero;
  Rect _window = Rect.zero;
  double _baseScale = 1;
  bool _initialized = false;

  // 手势基准
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureFocalWindow = Offset.zero;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _image = frame.image);
    } catch (e) {
      // 解码失败（OOM/数据损坏）：可观测日志 + 占位图标，不留白屏
      debugPrint('CropEditor decode failed '
          '(${widget.imageWidth}x${widget.imageHeight}, '
          '${widget.imageBytes.lengthInBytes}B): $e');
      if (mounted) setState(() => _decodeFailed = true);
    }
  }

  /// 还原为自动构图
  void reset() {
    _initialized = false;
    _initFromAutoCrop();
    setState(() {});
    _emit();
  }

  void _layout(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _viewport = size;
    const pad = 24.0;
    final availW = size.width - pad * 2;
    final availH = size.height - pad * 2;
    var winW = availW;
    var winH = winW / widget.aspect;
    if (winH > availH) {
      winH = availH;
      winW = winH * widget.aspect;
    }
    _window = Rect.fromLTWH(
        (size.width - winW) / 2, (size.height - winH) / 2, winW, winH);
    _baseScale = _coverScale();
    if (!_initialized) _initFromAutoCrop();
  }

  /// 图片铺满窗口所需的基准缩放（cover）
  double _coverScale() {
    final sx = _window.width / widget.imageWidth;
    final sy = _window.height / widget.imageHeight;
    return sx > sy ? sx : sy;
  }

  void _initFromAutoCrop() {
    if (_window.isEmpty) return;
    final crop = widget.autoCrop;
    // 总缩放 = 窗口宽 / 裁剪宽；用户倍率 = 总缩放 / 基准
    final total = _window.width / crop.width;
    _scale = (total / _baseScale).clamp(1.0, 8.0);
    _offset = Offset(-crop.left * total, -crop.top * total);
    _clampAll();
    _initialized = true;
  }

  /// 钳制：缩放 ≥1，图片始终覆盖窗口
  void _clampAll() {
    _scale = _scale.clamp(1.0, 8.0);
    final dispW = widget.imageWidth * _baseScale * _scale;
    final dispH = widget.imageHeight * _baseScale * _scale;
    final dx = _offset.dx.clamp(_window.width - dispW, 0.0);
    final dy = _offset.dy.clamp(_window.height - dispH, 0.0);
    _offset = Offset(dx, dy);
  }

  /// 当前取图窗对应的图像坐标裁剪框（高由宽÷比例推导，严格等比）
  Rect _currentCrop() {
    final total = _baseScale * _scale;
    final w = _window.width / total;
    final h = w / widget.aspect;
    return Rect.fromLTWH(-_offset.dx / total, -_offset.dy / total, w, h);
  }

  void _emit() => widget.onChanged(_currentCrop());

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureFocalWindow = d.localFocalPoint - _window.topLeft;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.scale != 1.0) {
        // 双指等比缩放：保持焦点下的图像点不动
        final newScale =
            (_gestureStartScale * d.scale).clamp(1.0, 8.0);
        final k = newScale / _gestureStartScale;
        _scale = newScale;
        _offset = _gestureFocalWindow -
            (_gestureFocalWindow - _gestureStartOffset) * k +
            (d.localFocalPoint - _window.topLeft - _gestureFocalWindow);
      } else {
        // 单指拖动
        _offset = _gestureStartOffset +
            (d.localFocalPoint - _window.topLeft - _gestureFocalWindow);
      }
      _clampAll();
    });
  }

  void _onScaleEnd(ScaleEndDetails _) => _emit();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(Size(constraints.maxWidth, constraints.maxHeight));
        final image = _image;
        if (_decodeFailed) {
          return const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 48, color: Colors.grey),
          );
        }
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: ClipRect(
            child: CustomPaint(
              size: _viewport,
              painter: _CropPainter(
                image: image,
                window: _window,
                offset: _offset,
                scale: _baseScale * _scale,
                imageW: widget.imageWidth,
                imageH: widget.imageHeight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.window,
    required this.offset,
    required this.scale,
    required this.imageW,
    required this.imageH,
  });

  final ui.Image? image;
  final Rect window;
  final Offset offset;
  final double scale;
  final int imageW;
  final int imageH;

  @override
  void paint(Canvas canvas, Size size) {
    // 底
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF1A1A1A));
    final img = image;
    if (img != null) {
      final dst = Rect.fromLTWH(
        window.left + offset.dx,
        window.top + offset.dy,
        imageW * scale,
        imageH * scale,
      );
      paintImage(
          canvas: canvas,
          rect: dst,
          image: img,
          fit: BoxFit.fill, // dst 与图片同宽高比（scale 为单一因子）
          filterQuality: FilterQuality.high);
    }
    // 窗外遮罩
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, size.width, window.top), overlay)
      ..drawRect(
          Rect.fromLTRB(0, window.bottom, size.width, size.height), overlay)
      ..drawRect(
          Rect.fromLTRB(0, window.top, window.left, window.bottom), overlay)
      ..drawRect(
          Rect.fromLTRB(
              window.right, window.top, size.width, window.bottom),
          overlay);
    // 窗框
    canvas.drawRect(
        window,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // 三分线（弱）
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    for (var i = 1; i <= 2; i++) {
      final gx = window.left + window.width * i / 3;
      final gy = window.top + window.height * i / 3;
      canvas.drawLine(
          Offset(gx, window.top), Offset(gx, window.bottom), grid);
      canvas.drawLine(
          Offset(window.left, gy), Offset(window.right, gy), grid);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.window != window ||
      old.offset != offset ||
      old.scale != scale;
}
