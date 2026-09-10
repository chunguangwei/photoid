import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/modnet_segmenter.dart';
import 'home_page.dart';

/// 启动页：全 Dart 矢量绘制的品牌形象 + 自然眨眼 + 呼吸浮动 + 光晕流动。
///
/// 为什么不用图片：原先是一张 1.59MB 的 `splash_loading.png`，
/// 既撑包体、在高分屏上还会糊，而且静态图做不了眨眼。改为
/// `CustomPainter` 后包体直接减 1.59MB，任意分辨率矢量锐利，
/// 且所有动效都能精确控制。
///
/// 顺带在这 6 秒空闲期里预热 MODNet（落盘 26MB 模型 + 建 ONNX 会话），
/// 用户进到处理页时模型已就绪——这是首张照片体感提速最大的一笔。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  static const _totalSeconds = 6;

  Timer? _countdownTimer;
  Timer? _blinkTimer;
  int _remain = _totalSeconds;
  bool _left = false;

  /// 呼吸浮动 + 光晕流动（长周期，低频重绘）
  late final AnimationController _ambient = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat(reverse: true);

  /// 加载进度（一次性推进到满，与倒计时同步）
  late final AnimationController _progress = AnimationController(
      vsync: this, duration: const Duration(seconds: _totalSeconds))
    ..forward();

  /// 眨眼：1 = 完全睁开，0 = 闭合。由随机间隔的 Timer 触发一次 forward+reverse
  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 85));
  late final Animation<double> _eyeOpen =
      Tween<double>(begin: 1, end: 0.06).animate(
          CurvedAnimation(parent: _blink, curve: Curves.easeOut));

  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remain <= 1) {
        _leave();
      } else {
        setState(() => _remain--);
      }
    });
    _scheduleBlink();
    // 预热失败不阻塞启动流程（内部已静默兜底）
    unawaited(ModnetSegmenter.warmUp());
  }

  /// 自然眨眼：2.2–5.2s 随机间隔，偶尔连眨两下（真人就是这个节奏）
  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 2200 + _rand.nextInt(3000)),
      () async {
        if (!mounted) return;
        await _blinkOnce();
        if (!mounted) return;
        if (_rand.nextInt(4) == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 160));
          if (!mounted) return;
          await _blinkOnce();
        }
        if (mounted) _scheduleBlink();
      },
    );
  }

  Future<void> _blinkOnce() async {
    try {
      await _blink.forward();
      await _blink.reverse();
    } on TickerCanceled {
      // 页面已销毁，忽略
    }
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _blinkTimer?.cancel();
    _ambient.dispose();
    _progress.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景：渐变 + 缓慢流动的柔光斑（独立图层，与角色分开重绘）
          RepaintBoundary(
            child: CustomPaint(painter: _BackdropPainter(_ambient)),
          ),
          // 角色 + 取景框 + 底部加载指示
          RepaintBoundary(
            child: CustomPaint(
              painter: _MascotPainter(
                ambient: _ambient,
                eyeOpen: _eyeOpen,
                progress: _progress,
              ),
            ),
          ),
          // 广告位槽（本版留空不展示，接 SDK 时填充）
          const Positioned(
              left: 16, right: 16, bottom: 24, child: SizedBox(height: 60)),
          // 跳过 + 倒计时
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: TextButton(
              onPressed: _leave,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.55),
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: Text(l.splashSkip(_remain),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF54607A))),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── 背景层 ─────────────────────────────

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 主渐变（左上冷白 → 右下淡紫，和 Logo 同一套色温）
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFF), Color(0xFFEEF3FF), Color(0xFFF8F3FF)],
          stops: [0, 0.52, 1],
        ).createShader(rect),
    );

    // 两团柔光斑：缓慢反向漂移，制造「呼吸」的空气感
    final drift = (t.value - 0.5) * 2; // -1..1
    _blob(canvas, Offset(size.width * 0.87, size.height * 0.14 + drift * 18),
        size.shortestSide * 0.52, const Color(0xFFDDE8FF));
    _blob(canvas, Offset(size.width * 0.10, size.height * 0.70 - drift * 22),
        size.shortestSide * 0.55, const Color(0xFFE8E0FF));
  }

  void _blob(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

// ───────────────────────────── 角色层 ─────────────────────────────

/// 吉祥物：举着手机自拍的圆润机器人。所有坐标沿用设计稿的
/// 1170×2532 画布，绘制时整体缩放居中，因此任何屏幕比例下构图一致。
class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.ambient,
    required this.eyeOpen,
    required this.progress,
  }) : super(repaint: Listenable.merge([ambient, eyeOpen, progress]));

  final Animation<double> ambient;
  final Animation<double> eyeOpen;
  final Animation<double> progress;

  /// 设计稿画布
  static const _dw = 1170.0, _dh = 2532.0;

  static const _bodyLight = Color(0xFFFFFFFF);
  static const _bodyDark = Color(0xFFE7ECF6);
  static const _ink = Color(0xFF2E3340);
  static const _guide = Color(0xFF91A9D8);

  @override
  void paint(Canvas canvas, Size size) {
    // 等比缩放到屏幕，横向居中、纵向略偏上（给底部指示留空间）
    final scale = math.min(size.width / _dw, size.height / _dh);
    canvas.save();
    canvas.translate(
        (size.width - _dw * scale) / 2, (size.height - _dh * scale) / 2);
    canvas.scale(scale);

    _drawGuides(canvas);

    // 呼吸浮动：整个人上下 ±10 设计单位，缓入缓出
    final float = math.sin(ambient.value * math.pi * 2) * 10;
    canvas.save();
    canvas.translate(0, float);

    _drawShadow(canvas, float);
    _drawRearArm(canvas);
    _drawLegs(canvas);
    _drawBody(canvas);
    _drawHead(canvas);
    _drawFrontArm(canvas);
    _drawPhone(canvas);
    _drawHand(canvas);

    canvas.restore();
    _drawLoader(canvas);
    canvas.restore();
  }

  Paint get _bodyPaint => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_bodyLight, _bodyDark],
    ).createShader(const Rect.fromLTWH(353, 900, 470, 1080));

  /// 证件照取景角标（品牌暗示：这是个拍证件照的 App）
  void _drawGuides(Canvas canvas) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = _guide.withValues(alpha: 0.48);
    const l = 193.0, r = 977.0, t = 644.0, b = 1806.0;
    const arm = 74.0, rad = 54.0;
    // 四个圆角直角
    void corner(double x, double y, double sx, double sy) {
      final path = Path()
        ..moveTo(x, y + sy * (arm + rad))
        ..lineTo(x, y + sy * rad)
        ..quadraticBezierTo(x, y, x + sx * rad, y)
        ..lineTo(x + sx * (arm + rad), y);
      canvas.drawPath(path, p);
    }

    corner(l, t, 1, 1);
    corner(r, t, -1, 1);
    corner(l, b, 1, -1);
    corner(r, b, -1, -1);
  }

  /// 地面投影：随浮动同步缩放，人在高点时影子更小更淡（体积感来源）
  void _drawShadow(Canvas canvas, double float) {
    final k = 1 - float / 26; // float 越大（越高）影子越小
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(585, 1990) - Offset(0, float),
          width: 470 * k,
          height: 74 * k),
      Paint()
        ..color = const Color(0xFFB7C1DD).withValues(alpha: 0.30 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
  }

  void _drawRearArm(Canvas canvas) {
    final path = Path()
      ..moveTo(384, 1173)
      ..cubicTo(275, 1172, 218, 1264, 241, 1373)
      ..lineTo(299, 1650)
      ..cubicTo(315, 1724, 381, 1766, 448, 1745)
      ..cubicTo(510, 1726, 540, 1660, 520, 1594)
      ..lineTo(463, 1339)
      ..cubicTo(454, 1293, 471, 1253, 505, 1223)
      ..lineTo(466, 1184)
      ..cubicTo(442, 1176, 412, 1173, 384, 1173)
      ..close();
    canvas.drawPath(path, _bodyPaint);
    canvas.drawPath(
      Path()
        ..moveTo(315, 1420)
        ..cubicTo(359, 1450, 411, 1458, 461, 1436),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD3DAE8),
    );
  }

  void _drawLegs(Canvas canvas) {
    for (final dx in [0.0, 160.0]) {
      final path = Path()
        ..moveTo(405 + dx, 1745)
        ..cubicTo(405 + dx, 1704, 438 + dx, 1671, 479 + dx, 1671)
        ..lineTo(531 + dx, 1671)
        ..cubicTo(572 + dx, 1671, 605 + dx, 1704, 605 + dx, 1745)
        ..lineTo(605 + dx, 1884)
        ..cubicTo(605 + dx, 1934, 565 + dx, 1974, 515 + dx, 1974)
        ..lineTo(493 + dx, 1974)
        ..cubicTo(444 + dx, 1974, 405 + dx, 1934, 405 + dx, 1884)
        ..close();
      canvas.drawPath(path, _bodyPaint);
    }
  }

  void _drawBody(Canvas canvas) {
    final path = Path()
      ..moveTo(353, 1210)
      ..cubicTo(353, 1056, 455, 965, 585, 965)
      ..cubicTo(715, 965, 817, 1056, 817, 1210)
      ..lineTo(817, 1549)
      ..cubicTo(817, 1754, 720, 1884, 585, 1884)
      ..cubicTo(450, 1884, 353, 1754, 353, 1549)
      ..close();
    canvas.drawPath(path, _bodyPaint);
    // 胸口分割线
    canvas.drawPath(
      Path()
        ..moveTo(368, 1484)
        ..cubicTo(489, 1512, 681, 1512, 802, 1484),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = const Color(0xFFD8DFEC),
    );
  }

  void _drawHead(Canvas canvas) {
    final head = Path()
      ..moveTo(302, 829)
      ..cubicTo(302, 682, 424, 588, 585, 588)
      ..cubicTo(746, 588, 868, 682, 868, 829)
      ..cubicTo(868, 958, 754, 1033, 585, 1033)
      ..cubicTo(416, 1033, 302, 958, 302, 829)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEEF2F9)],
        ).createShader(const Rect.fromLTWH(302, 588, 566, 445)),
    );

    // 腮红：让形象更亲和
    for (final cx in [432.0, 738.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 890), width: 96, height: 54),
        Paint()..color = const Color(0xFFFFA9B4).withValues(alpha: 0.28),
      );
    }

    _drawEyes(canvas);

    // 微笑
    canvas.drawPath(
      Path()
        ..moveTo(543, 928)
        ..quadraticBezierTo(585, 962, 627, 928),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..color = _ink.withValues(alpha: 0.75),
    );
  }

  /// 双眼同步眨动：睁开时是竖椭圆 + 高光，闭合时压成一条带弧度的眼睑线。
  void _drawEyes(Canvas canvas) {
    final open = eyeOpen.value.clamp(0.0, 1.0);
    const rx = 31.0, ry = 45.0, cy = 819.0;
    final ink = Paint()..color = _ink;

    for (final cx in [500.0, 670.0]) {
      if (open > 0.18) {
        final h = ry * open;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: h * 2),
          ink,
        );
        // 高光：让眼睛有神（随睁开度淡出，闭眼时不该有反光）
        canvas.drawCircle(
          Offset(cx + 10, cy - h * 0.42),
          10 * open,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * open),
        );
      } else {
        // 闭眼：向下弯的弧线，比直线自然
        canvas.drawPath(
          Path()
            ..moveTo(cx - rx, cy - 4)
            ..quadraticBezierTo(cx, cy + 16, cx + rx, cy - 4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 16
            ..strokeCap = StrokeCap.round
            ..color = _ink,
        );
      }
    }
  }

  void _drawFrontArm(Canvas canvas) {
    final path = Path()
      ..moveTo(799, 1172)
      ..cubicTo(893, 1152, 953, 1217, 944, 1301)
      ..lineTo(922, 1514)
      ..cubicTo(916, 1580, 861, 1627, 795, 1619)
      ..cubicTo(736, 1612, 696, 1560, 704, 1498)
      ..lineTo(723, 1346)
      ..cubicTo(727, 1304, 710, 1278, 678, 1252)
      ..lineTo(705, 1188)
      ..cubicTo(733, 1183, 766, 1178, 799, 1172)
      ..close();
    canvas.drawPath(path, _bodyPaint);
  }

  void _drawPhone(Canvas canvas) {
    canvas.save();
    canvas.translate(900, 1070);
    canvas.rotate(-10 * math.pi / 180);
    canvas.translate(-900, -1070);

    // 机身 + 轻微投影，做出微立体
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(820, 920, 174, 296), const Radius.circular(31));
    canvas.drawRRect(
      body.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0xFF8F9BBB).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF343B54));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(833, 938, 148, 259), const Radius.circular(21)),
      Paint()..color = const Color(0xFFEEF4FF),
    );
    // 快门键：随呼吸轻微脉动，暗示「随时可以按下」
    final pulse = 1 + 0.06 * math.sin(ambient.value * math.pi * 2);
    canvas.drawCircle(const Offset(907, 1014), 43 * pulse,
        Paint()..color = const Color(0xFFFF6F7D));
    canvas.drawCircle(const Offset(907, 1014), 21 * pulse,
        Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(878, 1157, 58, 8), const Radius.circular(4)),
      Paint()..color = const Color(0xFFB2BED8),
    );
    canvas.restore();
  }

  void _drawHand(Canvas canvas) {
    final path = Path()
      ..moveTo(778, 1270)
      ..cubicTo(797, 1202, 855, 1164, 915, 1183)
      ..cubicTo(967, 1199, 995, 1254, 979, 1308)
      ..lineTo(950, 1401)
      ..cubicTo(934, 1454, 875, 1485, 824, 1465)
      ..cubicTo(777, 1447, 752, 1397, 765, 1350)
      ..close();
    canvas.drawPath(path, _bodyPaint);
    final finger = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD4DCEA);
    canvas.drawLine(const Offset(849, 1265), const Offset(902, 1281), finger);
    canvas.drawLine(const Offset(832, 1322), const Offset(894, 1339), finger);
    canvas.drawLine(const Offset(816, 1379), const Offset(874, 1395), finger);
  }

  /// 底部加载指示：进度条 + 三点波浪（无文字，天然多语言友好）
  void _drawLoader(Canvas canvas) {
    const barW = 180.0, barH = 10.0, barX = 495.0, barY = 2157.0;
    final r = const Radius.circular(barH / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(barX, barY, barW, barH), r),
      Paint()..color = const Color(0xFFD6DEEF),
    );
    // 进度用 easeOut 推进，末尾放缓，避免「到头了还在等」的割裂感
    final p = Curves.easeOut.transform(progress.value).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, math.max(barH, barW * p), barH), r),
      Paint()..color = const Color(0xFF7188C8),
    );

    // 三点依次起伏
    for (var i = 0; i < 3; i++) {
      final phase = (ambient.value * 2 + i * 0.22) % 1.0;
      final lift = math.sin(phase * math.pi) * 6;
      canvas.drawCircle(
        Offset(585 + i * 32, 2225 - lift),
        7,
        Paint()
          ..color = const Color(0xFF7188C8)
              .withValues(alpha: 0.35 + 0.45 * math.sin(phase * math.pi)),
      );
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) => false;
}
