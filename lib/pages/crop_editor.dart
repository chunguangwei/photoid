import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 交互裁剪编辑器：固定规格比例视口内双指缩放、拖动调整构图。
/// 初始位置为自动构图框 [autoCrop]；onChanged 在手势结束时回传图像坐标系裁剪框。
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
  final Rect autoCrop;
  final double aspect;
  final ValueChanged<Rect> onChanged;

  @override
  State<CropEditor> createState() => CropEditorState();
}

class CropEditorState extends State<CropEditor> {
  final TransformationController _controller = TransformationController();
  double _viewportW = 0;
  double _scale0 = 1; // 初始缩放：autoCrop 恰好铺满视口

  @override
  void initState() {
    super.initState();
    _controller.addListener(_emitCrop);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emitCrop() {
    if (_viewportW == 0) return;
    widget.onChanged(currentCrop);
  }

  /// 当前变换对应的图像坐标系裁剪框。
  Rect get currentCrop {
    final m = _controller.value;
    final ts = _scale0 * m.getMaxScaleOnAxis();
    final tx = m.storage[12];
    final ty = m.storage[13];
    final left = -tx / ts;
    final top = -ty / ts;
    final w = _viewportW / ts;
    final h = w / widget.aspect;
    return Rect.fromLTWH(left, top, w, h);
  }

  /// 还原为自动构图。
  void reset() {
    _controller.value = Matrix4.translationValues(
        -widget.autoCrop.left * _scale0, -widget.autoCrop.top * _scale0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = vw / widget.aspect;
        if (vw != _viewportW) {
          _viewportW = vw;
          _scale0 = vw / widget.autoCrop.width;
          // 首次布局后设置初始变换
          WidgetsBinding.instance.addPostFrameCallback((_) => reset());
        }
        return ClipRect(
          child: SizedBox(
            width: vw,
            height: vh,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.4,
              maxScale: 4,
              // 子图比视口大，允许越界拖动
              clipBehavior: Clip.none,
              child: SizedBox(
                width: widget.imageWidth * _scale0,
                height: widget.imageHeight * _scale0,
                child: Image.memory(
                  widget.imageBytes,
                  width: widget.imageWidth * _scale0,
                  height: widget.imageHeight * _scale0,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
