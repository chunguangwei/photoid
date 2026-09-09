import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import 'edit_page.dart';

/// 拍摄页：实时预览 + 3:4 参考框 + 人像轮廓框，支持前置/后置切换。
/// 默认后置（家长替孩子拍摄场景）。
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _lens = CameraLensDirection.back;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  CameraDescription get _current => _cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => _cameras.first,
      );

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = AppLocalizations.of(context).cameraNotFound);
        return;
      }
      await _startController();
    } on CameraException catch (e) {
      setState(() => _error = AppLocalizations.of(context)
          .cameraInitFailed(e.description ?? e.code));
    }
  }

  Future<void> _startController() async {
    final controller = CameraController(
      _current,
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
  }

  /// 前置/后置切换：释放旧控制器后按新镜头方向重建。
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final old = _controller;
    setState(() {
      _controller = null;
      _lens = _lens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await old?.dispose();
    try {
      await _startController();
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(Tr.of(context).specName(widget.spec)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_outlined),
              tooltip: l.cameraSwitch,
              onPressed: _switchCamera,
            ),
        ],
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
                        l.cameraGuidePerson,
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

/// 半透明遮罩 + 3:4 取景框 + 人像轮廓参考框（头 + 肩剪影虚线）
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

    // 人像轮廓：头部占框高约 40%（对应成片头部占比 62% 的视觉引导），
    // 肩部展开至框宽约 62%，底部在框高 82% 处截止
    final cx = size.width / 2;
    final headR = frameH * 0.20;
    final headCY = top + frameH * 0.08 + headR;
    final shoulderW = frameW * 0.62;
    final shoulderY = headCY + headR * 0.85; // 颈部
    final bottomY = top + frameH * 0.82;

    final person = Path()
      // 头部圆
      ..addOval(Rect.fromCircle(center: Offset(cx, headCY), radius: headR))
      // 肩部轮廓（颈 → 肩 → 底部）
      ..moveTo(cx - headR * 0.55, shoulderY)
      ..cubicTo(
        cx - shoulderW * 0.48, shoulderY + headR * 0.25,
        cx - shoulderW * 0.52, bottomY - headR * 0.5,
        cx - shoulderW / 2, bottomY,
      )
      ..lineTo(cx + shoulderW / 2, bottomY)
      ..cubicTo(
        cx + shoulderW * 0.52, bottomY - headR * 0.5,
        cx + shoulderW * 0.48, shoulderY + headR * 0.25,
        cx + headR * 0.55, shoulderY,
      );

    final dashPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _dashed(canvas, person, dashPaint);
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dashLen = 10.0;
    const gapLen = 6.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + dashLen;
        canvas.drawPath(
            metric.extractPath(
                dist, next.clamp(0.0, metric.length).toDouble()),
            paint);
        dist = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.aspect != aspect;
}
