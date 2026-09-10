import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/image_pipeline.dart';

/// 处理中动效。
///
/// 性能约束（曾是处理页卡顿根因之一，勿回退成 Widget 方案）：动效必须
/// `CustomPaint` + `super(repaint: controller)` + `RepaintBoundary` ——
/// 只重绘、不 rebuild、不 relayout，渐变着色器按尺寸缓存。反例是用
/// `AnimatedBuilder` 每帧重建 `Container`/`BoxDecoration(LinearGradient)`，
/// 等于每帧新建并编译一次 shader，还脏化整棵子树。

/// 扫描揭色：光带自上而下推进，**已扫过的区域从灰度变彩色**，
/// 未扫到的仍是灰度，配合四角取景括号 —— 无需文字即可表达
/// 「AI 正在逐行处理这张图，进度到这里了」。
///
/// 相比单纯的光带往返，它把「处理中」和「处理到哪了」两层信息都给了用户；
/// 灰→彩的方向也天然隐喻「原始 → 已修好」。
///
/// 实现要点（延续 §2.2 的性能约束）：
/// - [child] 只构建**一次**，用 `ColorFiltered` 包一层灰度作为底、
///   原色 child 用 `ClipRect` 按进度露出。二者共享同一棵 widget 子树描述，
///   动画期间不 rebuild [child]；
/// - 裁剪与光带都在 `AnimatedBuilder` 里只重建轻量的 `ClipRect`/`CustomPaint`，
///   外层 `RepaintBoundary` 隔离重绘。
class ScanRevealEffect extends StatefulWidget {
  const ScanRevealEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2200),
  });

  final Widget child;
  final Duration duration;

  @override
  State<ScanRevealEffect> createState() => _ScanRevealEffectState();
}

class _ScanRevealEffectState extends State<ScanRevealEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  /// 灰度矩阵（BT.601 亮度）
  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底：灰度（尚未处理）
          ColorFiltered(colorFilter: _grayscale, child: widget.child),
          // 上：原色，按扫描进度自上而下揭开
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => ClipRect(
              clipper: _TopReveal(_c.value),
              child: widget.child,
            ),
          ),
          // 光带 + 四角括号
          IgnorePointer(
            child: CustomPaint(
              painter: _RevealPainter(progress: _c, color: color),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

/// 从顶部露出 [t] 比例的高度
class _TopReveal extends CustomClipper<Rect> {
  const _TopReveal(this.t);

  final double t;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * t.clamp(0.0, 1.0));

  @override
  bool shouldReclip(_TopReveal old) => old.t != t;
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(
      {required this.progress, required this.color, this.scrim = 0.0})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  /// 未扫描区的压暗程度（叠加层模式用，揭色模式为 0）
  final double scrim;

  Shader? _shader;
  double _cacheKey = -1;

  static const _band = 18.0;
  static const _corner = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.value.clamp(0.0, 1.0);
    if (scrim > 0) {
      // 光带下方（尚未处理）压暗，形成与揭色一致的「已处理/未处理」分界
      canvas.drawRect(
        Rect.fromLTRB(0, size.height * t, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: scrim),
      );
    }

    // 四角取景括号：静态，表达「取景/识别中」
    final bracket = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final c = math.min(_corner, math.min(size.width, size.height) / 4);
    const m = 6.0;
    void drawCorner(double x, double y, double sx, double sy) {
      canvas
        ..drawLine(Offset(x, y), Offset(x + c * sx, y), bracket)
        ..drawLine(Offset(x, y), Offset(x, y + c * sy), bracket);
    }

    drawCorner(m, m, 1, 1);
    drawCorner(size.width - m, m, -1, 1);
    drawCorner(m, size.height - m, 1, -1);
    drawCorner(size.width - m, size.height - m, -1, -1);

    // 扫描光带：贴在灰/彩分界线上
    final band = _band.clamp(1.0, size.height);
    if (_shader == null || _cacheKey != band) {
      _cacheKey = band;
      _shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.9),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, band));
    }
    final edge = size.height * t;
    canvas.save();
    canvas.translate(0, edge - band);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, band),
      Paint()..shader = _shader,
    );
    canvas.restore();
    // 分界亮线
    canvas.drawLine(
      Offset(0, edge),
      Offset(size.width, edge),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.color != color || old.scrim != scrim;
}

/// 扫描叠加层：与 [ScanRevealEffect] 同一视觉语言（四角括号 + 自上而下光带），
/// 但**不做灰→彩揭色**，只作为半透明覆盖层叠在已有内容之上。
///
/// 用于「效果重算中」——此时底下是 `CropEditor`（自带 key、内部有手势与解码
/// 状态），不能像揭色那样把同一子树实例化两份，故只覆盖不包裹。
class ScanOverlayEffect extends StatefulWidget {
  const ScanOverlayEffect(
      {super.key, this.duration = const Duration(milliseconds: 1600)});

  final Duration duration;

  @override
  State<ScanOverlayEffect> createState() => _ScanOverlayEffectState();
}

class _ScanOverlayEffectState extends State<ScanOverlayEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _RevealPainter(
            progress: _c,
            color: Theme.of(context).colorScheme.primary,
            scrim: 0.1,
          ),
          size: Size.infinite,
        ),
      );
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
