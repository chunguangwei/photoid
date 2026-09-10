import 'package:flutter/material.dart';

import '../services/image_pipeline.dart';

/// 科技感扫描动效：光带上下往返 + 微呼吸亮度，表明「AI 正在处理这张图」。
///
/// 性能要点（这是处理页卡顿的直接原因之一，勿回退成 Widget 方案）：
/// 旧实现用 `AnimatedBuilder` 每帧重建 `Stack`/`Container`/`BoxDecoration`，
/// 意味着每帧都要新建一次 `LinearGradient` 并重新编译 shader，
/// 还会触发整棵子树的 build+layout。这里改为：
/// - `CustomPaint` + `repaint: controller` —— 只重绘，不 rebuild、不 layout；
/// - 渐变着色器按尺寸缓存，尺寸不变就不重建；
/// - 外层 `RepaintBoundary` 把重绘隔离在自己的图层，不脏化父级。
class ScanLineEffect extends StatefulWidget {
  const ScanLineEffect({super.key, this.duration = const Duration(milliseconds: 1800)});

  final Duration duration;

  @override
  State<ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<ScanLineEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ScanPainter(
          progress: _c,
          color: Theme.of(context).colorScheme.primary,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter({required this.progress, required this.color})
      : super(repaint: progress);

  /// 0→1→0 往返；`repaint` 直接挂在 controller 上，Flutter 只调 paint
  final Animation<double> progress;
  final Color color;

  // 着色器缓存：只随「光带高度」变化重建，动画期间恒定
  Shader? _bandShader;
  double _bandCacheKey = -1;

  static const _bandHeight = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = Curves.easeInOut.transform(progress.value);

    // 1) 微呼吸亮度
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.06 + 0.05 * t),
    );

    // 2) 扫描光带
    final band = _bandHeight.clamp(1.0, size.height);
    if (_bandShader == null || _bandCacheKey != band) {
      _bandCacheKey = band;
      _bandShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.85),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, band));
    }

    final y = (size.height - band) * t;
    canvas.save();
    canvas.translate(0, y);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, band),
      Paint()..shader = _bandShader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.color != color;
}

/// 体感进度条：随流水线步骤向目标值缓动前进，避免处理中界面「卡死」感。
///
/// 始终 ≤0.97，完成由页面切换表达。同样用 `CustomPaint`+`repaint`
/// 避免每帧 rebuild `LinearProgressIndicator`（后者内部还带自己的动画控制器）。
class SmoothProgressBar extends StatefulWidget {
  const SmoothProgressBar({super.key, required this.step, this.height = 5});

  final PipelineStep step;
  final double height;

  @override
  State<SmoothProgressBar> createState() => _SmoothProgressBarState();
}

class _SmoothProgressBarState extends State<SmoothProgressBar>
    with SingleTickerProviderStateMixin {
  /// 各步骤的目标进度。步骤内部再用一条慢速缓动持续爬升，
  /// 保证即使某一步耗时很长，进度条也始终在动（体感不卡）。
  static const _targets = {
    PipelineStep.preparing: 0.08,
    PipelineStep.reading: 0.20,
    PipelineStep.segmenting: 0.58,
    PipelineStep.compositing: 0.76,
    PipelineStep.framing: 0.89,
    PipelineStep.compressing: 0.97,
  };

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));
  late Animation<double> _a = const AlwaysStoppedAnimation(0);
  double _current = 0;

  @override
  void initState() {
    super.initState();
    _animateTo(_targets[widget.step] ?? 0.08);
  }

  @override
  void didUpdateWidget(SmoothProgressBar old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) _animateTo(_targets[widget.step] ?? 0.97);
  }

  void _animateTo(double target) {
    _current = _a.value;
    _a = Tween<double>(begin: _current, end: target)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _c
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ProgressPainter(
          progress: _a,
          track: scheme.surfaceContainerHighest,
          fill: scheme.primary,
        ),
        size: Size(double.infinity, widget.height),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(
      {required this.progress, required this.track, required this.fill})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    final w = size.width * progress.value.clamp(0.0, 1.0);
    if (w <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), r),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.track != track || old.fill != fill;
}
