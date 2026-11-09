import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import 'home_page.dart';

/// Brief brand motion, independent of model/network readiness.
/// The home is built immediately underneath; any tap can dismiss the intro.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stage = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  bool _started = false, _finished = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _finished = true;
      _stage.stop();
    } else if (!_started && !_finished) {
      _started = true;
      _stage.forward();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _stage.stop();
    setState(() => _finished = true);
  }

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Stack(fit: StackFit.expand, children: [
      ExcludeSemantics(excluding: !_finished, child: const HomePage()),
      if (!_finished)
        Positioned.fill(
            child: AnimatedBuilder(
                animation: _stage,
                builder: (_, child) => Opacity(
                    opacity: 1 - ((_stage.value - .84) / .16).clamp(0.0, 1.0),
                    child: child),
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: const SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.light,
                        statusBarBrightness: Brightness.dark),
                    child: GestureDetector(
                        key: const Key('brand-intro'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _finish,
                        child: Scaffold(
                            backgroundColor: const Color(0xFF2E3A63),
                            body: Stack(fit: StackFit.expand, children: [
                              RepaintBoundary(
                                  child: CustomPaint(
                                      painter: _BackdropPainter(_stage))),
                              RepaintBoundary(
                                  child: CustomPaint(
                                      painter: _BrandPainter(
                                          stage: _stage,
                                          ambient: _stage,
                                          progress: _stage))),
                              Positioned(
                                  top: MediaQuery.paddingOf(context).top + 12,
                                  right: 16,
                                  child: TextButton(
                                      key: const Key('startup-continue'),
                                      onPressed: _finish,
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: .16),
                                          minimumSize: const Size(88, 44),
                                          shape: const StadiumBorder()),
                                      child: Text(l.startupContinue))),
                            ])))))),
    ]);
  }
}

// ───────────────────────────── 背景层 ─────────────────────────────

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  /// 与 Logo 同一套色阶：左上亮、右下沉
  static const _stops = [
    Color(0xFF7E97DE),
    Color(0xFF5A70B4),
    Color(0xFF3C4C82),
    Color(0xFF27325A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _stops,
          stops: [0, 0.36, 0.72, 1],
        ).createShader(rect),
    );

    // 极淡的斜向网格：科技感的底噪，alpha 刻意压到几乎看不见，
    // 只在大面积渐变上提供一点「材质」，不能喧宾夺主。
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const gap = 58.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), grid);
    }

    // 两团柔光斑：缓慢反向漂移，制造呼吸般的空气感
    final k = t.value;
    void glow(Offset c, double r, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    glow(Offset(size.width * (0.22 + 0.06 * k), size.height * 0.26),
        size.width * 0.62, 0.20);
    glow(Offset(size.width * (0.84 - 0.08 * k), size.height * 0.70),
        size.width * 0.55, 0.10);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

// ───────────────────────────── 主体层 ─────────────────────────────

/// 品牌主体：取景角标 + 头肩剪影 + 品牌徽章，按四拍组装。
///
/// 坐标沿用 1170×2532 的设计画布，绘制时整体等比缩放居中，因此任何
/// 屏幕比例下构图一致。几何比例与 `logo/logo.svg` 一一对应。
class _BrandPainter extends CustomPainter {
  _BrandPainter({
    required this.stage,
    required this.ambient,
    required this.progress,
  }) : super(repaint: Listenable.merge([stage, ambient, progress]));

  final Animation<double> stage;
  final Animation<double> ambient;
  final Animation<double> progress;

  static const _dw = 1170.0, _dh = 2532.0;

  /// 取景框（设计稿坐标）
  static const _fl = 255.0, _fr = 915.0, _ft = 750.0, _fb = 1410.0;

  /// 四拍的时间切片
  static const _cornersIn = Interval(0.00, 0.16, curve: Curves.easeOutCubic);
  static const _outline = Interval(0.10, 0.42, curve: Curves.easeInOut);
  static const _scan = Interval(0.38, 0.76, curve: Curves.easeInOutCubic);
  static const _badge = Interval(0.76, 0.94, curve: Curves.elasticOut);
  static const _title = Interval(0.52, 0.80, curve: Curves.easeOut);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _dw, size.height / _dh);
    canvas.save();
    canvas.translate(
        (size.width - _dw * scale) / 2, (size.height - _dh * scale) / 2);
    canvas.scale(scale);

    final t = stage.value;
    _drawCorners(canvas, _cornersIn.transform(t));
    _drawFigure(canvas, _outline.transform(t), _scan.transform(t));
    _drawBadge(canvas, _badge.transform(t));
    _drawTitle(canvas, _title.transform(t));
    _drawLoader(canvas);

    canvas.restore();
  }

  // ── ① 取景：四角从画面外滑入 ──

  void _drawCorners(Canvas canvas, double t) {
    if (t <= 0) return;
    // 滑入位移：从外侧 120 单位处归位，配合透明度淡入
    final off = 120 * (1 - t);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFD7E1F8)],
      ).createShader(const Rect.fromLTRB(_fl, _ft, _fr, _fb))
      ..color = Colors.white.withValues(alpha: t);

    // 四角各自朝对角线方向偏移，收拢感更强
    final corners = <(Path, Offset)>[
      (
        Path()
          ..moveTo(255, 884)
          ..lineTo(255, 807)
          ..cubicTo(255, 776, 281, 750, 312, 750)
          ..lineTo(389, 750),
        Offset(-off, -off)
      ),
      (
        Path()
          ..moveTo(781, 750)
          ..lineTo(858, 750)
          ..cubicTo(889, 750, 915, 776, 915, 807)
          ..lineTo(915, 884),
        Offset(off, -off)
      ),
      (
        Path()
          ..moveTo(915, 1276)
          ..lineTo(915, 1353)
          ..cubicTo(915, 1384, 889, 1410, 858, 1410)
          ..lineTo(781, 1410),
        Offset(off, off)
      ),
      (
        Path()
          ..moveTo(389, 1410)
          ..lineTo(312, 1410)
          ..cubicTo(281, 1410, 255, 1384, 255, 1353)
          ..lineTo(255, 1276),
        Offset(-off, off)
      ),
    ];

    // 角标外扩一圈柔光：深色背景上白色描边容易显得「贴上去的」，
    // 加一层低透明度的模糊同形描边，边缘才有发光的质感。
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);

    canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: t));
    for (final (path, shift) in corners) {
      canvas.save();
      canvas.translate(shift.dx, shift.dy);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  // ── ②③ 人像：先描边，再被扫描光带「点亮」为实体 ──

  /// 头（椭圆）与肩（拱形），几何与 logo 完全一致
  static Path get _headPath => Path()
    ..addOval(Rect.fromCenter(
        center: const Offset(585, 995), width: 190, height: 202));

  static Path get _shoulderPath => Path()
    ..moveTo(398, 1255)
    ..lineTo(398, 1250)
    ..cubicTo(398, 1170, 481, 1119, 585, 1119)
    ..cubicTo(689, 1119, 773, 1170, 773, 1250)
    ..lineTo(773, 1255)
    ..cubicTo(773, 1282, 752, 1304, 724, 1304)
    ..lineTo(446, 1304)
    ..cubicTo(419, 1304, 398, 1282, 398, 1255)
    ..close();

  void _drawFigure(Canvas canvas, double outlineT, double scanT) {
    final head = _headPath, shoulder = _shoulderPath;

    // ② 轮廓描边：按总长度依次画出「头 → 肩」，视觉上是一笔连续画完
    if (outlineT > 0 && scanT < 1) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.92);
      _drawPartialStroke(canvas, [head, shoulder], outlineT, stroke);
    }

    // ③ 扫描揭色：已扫过的区域换成实体白，未扫到的仍是上面的线框
    if (scanT > 0) {
      final edge = _ft + (_fb - _ft) * scanT;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, _dw, edge));
      final fill = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFD2DDF4)],
        ).createShader(const Rect.fromLTRB(440, 890, 740, 1310));
      canvas.drawPath(head, fill);
      canvas.drawPath(shoulder, fill);
      canvas.restore();

      // 光带：贴在明暗分界线上，拖尾朝向已处理的一侧。
      //
      // 左右两端必须淡出——直接画矩形会在取景框边缘留下两道生硬的竖切口，
      // 像贴了张纸条。这里用 saveLayer + BlendMode.dstIn 施加一层横向的
      // 羽化遮罩，光带与亮线一起被裁成「中间实、两端虚」。
      if (scanT < 1) {
        const band = 72.0;
        final bandRect =
            Rect.fromLTRB(_fl - 40, edge - band, _fr + 40, edge + 10);
        canvas.saveLayer(bandRect, Paint());

        canvas.drawRect(
          Rect.fromLTRB(bandRect.left, edge - band, bandRect.right, edge),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.42),
              ],
            ).createShader(Rect.fromLTRB(_fl, edge - band, _fr, edge)),
        );
        canvas.drawLine(
          Offset(bandRect.left, edge),
          Offset(bandRect.right, edge),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 4
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        // 分界线中点的高光：让扫描看起来是「一束」而不是一条均匀的线
        canvas.drawCircle(
          Offset((_fl + _fr) / 2, edge),
          58,
          Paint()
            ..shader = RadialGradient(colors: [
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(
                center: Offset((_fl + _fr) / 2, edge), radius: 58)),
        );

        canvas.drawRect(
          bandRect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white,
                Colors.white,
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.18, 0.82, 1],
            ).createShader(bandRect),
        );
        canvas.restore();
      }
    }
  }

  /// 按 [t] 比例画出多条路径的前段，用于「一笔画出轮廓」。
  ///
  /// 用 `PathMetric.extractPath` 而不是 dash 偏移：前者能精确按弧长截断，
  /// 曲率变化剧烈时速度依然均匀。
  void _drawPartialStroke(
      Canvas canvas, List<Path> paths, double t, Paint paint) {
    if (t >= 1) {
      for (final p in paths) {
        canvas.drawPath(p, paint);
      }
      return;
    }
    final metrics = <PathMetric>[];
    var total = 0.0;
    for (final p in paths) {
      for (final m in p.computeMetrics()) {
        metrics.add(m);
        total += m.length;
      }
    }
    var remain = total * t;
    for (final m in metrics) {
      if (remain <= 0) break;
      final take = math.min(remain, m.length);
      canvas.drawPath(m.extractPath(0, take), paint);
      remain -= take;
    }
  }

  // ── ④ 品牌徽章：弹入 + 打勾 ──

  void _drawBadge(Canvas canvas, double t) {
    if (t <= 0) return;
    const c = Offset(755, 1219);
    const r = 57.0;
    // elasticOut 会短暂越过 1，这正是「弹一下」的来源，不要 clamp 掉
    final s = t;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);

    canvas.drawCircle(
      c.translate(0, 9),
      r,
      Paint()
        ..color = const Color(0xFF6E1A2E).withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9AA4), Color(0xFFE8455C)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final tick = Path()
      ..moveTo(734, 1219)
      ..lineTo(750, 1235)
      ..lineTo(780, 1201);
    _drawPartialStroke(
      canvas,
      [tick],
      // 勾比圆晚一点起笔，先有底再打勾
      ((t - 0.35) / 0.5).clamp(0.0, 1.0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.restore();
  }

  // ── 品牌名 ──

  void _drawTitle(Canvas canvas, double t) {
    if (t <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: 'PhotoID',
        style: TextStyle(
          fontSize: 82,
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
          color: Colors.white.withValues(alpha: t),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // 随淡入轻微上浮 16 单位，避免「凭空出现」
    tp.paint(canvas, Offset((_dw - tp.width) / 2, 1596 + 16 * (1 - t)));
  }

  // ── 底部加载指示 ──

  void _drawLoader(Canvas canvas) {
    const barW = 220.0, barH = 8.0, barY = 2157.0;
    final barX = (_dw - barW) / 2;
    const r = Radius.circular(barH / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, barW, barH).shift(Offset(barX, barY)), r),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    // 进度用 easeOut 推进，末尾放缓，避免「到头了还在等」的割裂感
    final p = Curves.easeOut.transform(progress.value).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, math.max(barH, barW * p), barH), r),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(_BrandPainter old) => false;
}
