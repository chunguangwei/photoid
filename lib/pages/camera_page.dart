import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import 'edit_page.dart';

/// 拍摄页：实时预览 + 3:4 参考框 + 头部椭圆虚线。
/// 后置摄像头默认（家长替孩子拍摄场景）。
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = AppLocalizations.of(context).cameraNotFound);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      setState(() => _error = AppLocalizations.of(context)
          .cameraInitFailed(e.description ?? e.code));
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => EditPage(sourcePath: file.path, spec: widget.spec),
      ));
    } on CameraException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)
              .captureFailed(e.description ?? e.code))));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(Tr.of(context).specName(widget.spec)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            )
          : controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: CameraPreview(controller)),
                    CustomPaint(
                      painter: _GuidePainter(aspect: widget.spec.aspect),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 110,
                      child: Text(
                        AppLocalizations.of(context).cameraGuide,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller == null
          ? null
          : FloatingActionButton.large(
              onPressed: _capture,
              child: _capturing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.photo_camera, size: 36),
            ),
    );
  }
}

/// 半透明遮罩 + 3:4 取景框 + 头部椭圆虚线参考线
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.aspect});

  final double aspect; // 宽/高

  @override
  void paint(Canvas canvas, Size size) {
    // 取景框：宽占屏 78%，按规格比例
    final frameW = size.width * 0.78;
    final frameH = frameW / aspect;
    final left = (size.width - frameW) / 2;
    final top = (size.height - frameH) / 2 - size.height * 0.04;
    final frame = Rect.fromLTWH(left, top, frameW, frameH);

    // 框外遮罩
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = Colors.black54);

    // 框边
    canvas.drawRect(
        frame,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // 头部椭圆（约占框高 62%，居中偏上，与构图算法一致）
    final headH = frameH * 0.62;
    final headW = headH * 0.72;
    final headTop = top + frameH * 0.10;
    final head = Rect.fromCenter(
        center: Offset(size.width / 2, headTop + headH / 2),
        width: headW,
        height: headH);
    final dashPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _dashedOval(canvas, head, dashPaint);
  }

  void _dashedOval(Canvas canvas, Rect rect, Paint paint) {
    const dashCount = 36;
    const gapRatio = 0.4;
    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      final dashLen = metric.length / dashCount;
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + dashLen * (1 - gapRatio);
        canvas.drawPath(
            metric.extractPath(
                dist, next.clamp(0.0, metric.length).toDouble()),
            paint);
        dist += dashLen;
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.aspect != aspect;
}
