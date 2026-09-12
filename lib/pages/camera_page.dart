import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import 'edit_page.dart';

/// 拍摄页（对标行业参考）：人形轮廓实线 + 横向虚线参考 + 顶栏已选规格 +
/// 大圆环快门 + 拍后「重拍/确认」。支持前置/后置切换。
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
  bool _switching = false;

  /// 拍后确认态：已拍照片路径（显示重拍/确认）
  String? _capturedPath;

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
      ResolutionPreset.high,
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

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _switching) return;
    _switching = true;
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
    } finally {
      _switching = false;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      // 拍后进入确认态（重拍/确认），而非直接跳转
      setState(() => _capturedPath = file.path);
    } on CameraException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)
              .captureFailed(e.description ?? e.code))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).captureFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickGallery() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 99);
    if (picked == null || !mounted) return;
    setState(() => _capturedPath = picked.path);
  }

  void _confirm() {
    final path = _capturedPath;
    if (path == null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => EditPage(
          sourcePath: path,
          spec: widget.spec,
          flipHorizontal: _lens == CameraLensDirection.front),
    ));
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
    final captured = _capturedPath;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(l),
              Expanded(
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : captured != null
                        ? _buildFrozenPreview(captured, l)
                        : controller == null
                            ? const Center(child: CircularProgressIndicator())
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Center(child: CameraPreview(controller)),
                                  CustomPaint(
                                    painter: _GuidePainter(
                                        aspect: widget.spec.aspect),
                                  ),
                                ],
                              ),
              ),
              captured != null
                  ? _buildConfirmBar(l)
                  : _buildCaptureBar(l, controller),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶栏：✕ 关闭｜人形图标｜已选：规格名
  Widget _topBar(AppLocalizations l) => Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Icon(Icons.person_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.cameraSelected(Tr.of(context).specName(widget.spec)),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  /// 底部快门栏：相册｜大圆环快门｜翻转镜头
  Widget _buildCaptureBar(AppLocalizations l, CameraController? controller) =>
      Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundSideButton(
              icon: Icons.photo_library_outlined,
              tooltip: l.pickGalleryShort,
              onTap: _pickGallery,
            ),
            GestureDetector(
              onTap: _capture,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 4),
                ),
                child: _capturing
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            _roundSideButton(
              icon: Icons.flip_camera_ios_outlined,
              tooltip: l.cameraSwitch,
              onTap: controller == null ? null : _switchCamera,
            ),
          ],
        ),
      );

  Widget _roundSideButton(
          {required IconData icon,
          required String tooltip,
          required VoidCallback? onTap}) =>
      IconButton(
        icon: Icon(icon, color: Colors.white70, size: 26),
        tooltip: tooltip,
        onPressed: onTap,
      );

  /// 拍后冻结预览（中间压暗，照片居中）
  Widget _buildFrozenPreview(String path, AppLocalizations l) => Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black87),
          Center(
            child: _lens == CameraLensDirection.front
                ? Transform.flip(
                    flipX: true,
                    child: Image.file(File(path), fit: BoxFit.contain))
                : Image.file(File(path), fit: BoxFit.contain),
          ),
        ],
      );

  /// 拍后底栏：重拍｜确认
  Widget _buildConfirmBar(AppLocalizations l) => Container(
        color: Colors.black87,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => setState(() => _capturedPath = null),
                child: Text(l.retake),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _confirm,
                child: Text(l.confirm,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
}

/// 人形轮廓参考框（对标行业：光滑头型+耳廓+颈部+肩部 S 曲线）+
/// 横向虚线（眼线/肩线）+ 弱取景框。
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.aspect});

  final double aspect; // 宽/高

  @override
  void paint(Canvas canvas, Size size) {
    final frameW = size.width * 0.82;
    final frameH = frameW / aspect;
    final left = (size.width - frameW) / 2;
    final top = (size.height - frameH) / 2 - size.height * 0.02;
    final frame = Rect.fromLTWH(left, top, frameW, frameH);

    // 框外遮罩
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = Colors.black45);

    // 弱框线
    canvas.drawRect(
        frame,
        Paint()
          ..color = Colors.white30
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);

    final cx = size.width / 2;
    // 头部：头顶在框高 6%，头高 36%，头宽≈头高 0.82
    final headTop = top + frameH * 0.06;
    final headH = frameH * 0.36;
    final headW = headH * 0.82;
    final chinY = headTop + headH;
    final neckW = headW * 0.42;
    final shoulderY = top + frameH * 0.88;
    final shoulderEndX = frame.left + frameW * 0.06; // 肩部出框

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final half = Path();
    // 右半：头顶 → 太阳穴 → 耳廓微凸 → 下颌内收 → 下巴
    half.moveTo(cx, headTop);
    half.cubicTo(cx + headW * 0.52, headTop + headH * 0.02, cx + headW * 0.50,
        headTop + headH * 0.30, cx + headW * 0.47, headTop + headH * 0.48);
    // 耳廓（微凸后回收）
    half.cubicTo(cx + headW * 0.53, headTop + headH * 0.56, cx + headW * 0.50,
        headTop + headH * 0.64, cx + headW * 0.40, headTop + headH * 0.72);
    // 下颌 → 下巴（圆润）
    half.cubicTo(cx + headW * 0.30, headTop + headH * 0.86, cx + headW * 0.16,
        chinY - headH * 0.02, cx, chinY);
    // 颈部
    half.moveTo(cx + neckW / 2, chinY - headH * 0.10);
    half.lineTo(cx + neckW / 2, chinY + headH * 0.16);
    // 肩部 S 曲线：颈根 → 斜方肌 → 肩峰 → 出框
    half.moveTo(cx + neckW / 2, chinY + headH * 0.16);
    half.cubicTo(cx + headW * 0.62, chinY + headH * 0.28, cx + headW * 0.98,
        chinY + headH * 0.42, frame.right - shoulderEndX, shoulderY);

    // 镜像左半（Matrix4.storage 为 Float64List）
    final mirror = Matrix4.identity()
      ..translateByDouble(cx, 0, 0, 1)
      ..scaleByVector3(Vector3(-1.0, 1.0, 1.0))
      ..translateByDouble(-cx, 0, 0, 1);
    final full = Path()
      ..addPath(half, Offset.zero)
      ..addPath(half.transform(mirror.storage), Offset.zero);
    canvas.drawPath(full, linePaint);

    // 横向虚线：眼线（头中部偏上）与肩线
    final dashPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _dashedH(canvas, headTop + headH * 0.52, frame, dashPaint);
    _dashedH(canvas, shoulderY, frame, dashPaint);
  }

  void _dashedH(Canvas canvas, double y, Rect frame, Paint paint) {
    const dash = 10.0, gap = 8.0;
    var x = frame.left + 6;
    while (x < frame.right - 6) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dash).clamp(x, frame.right - 6), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.aspect != aspect;
}
