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
    _drawPhone(canvas);
    _drawFrontArm(canvas);

    canvas.restore();
    _drawLoader(canvas);
    canvas.restore();
  }

  Paint get _bodyPaint => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_bodyLight, _bodyDark],
      // 渐变范围覆盖**整个角色**（含四肢），而不是只框住躯干：
      // 光源必须统一，否则手臂与身体各自明暗独立，接缝处会突变。
    ).createShader(const Rect.fromLTWH(330, 620, 700, 1320));

  /// 体块描边：极淡的冷灰线。
  ///
  /// 这是让四肢「看得见」的关键。角色通体近白、背景也是浅色，纯靠渐变
  /// 根本分不出手臂和躯干——初版就糊成了一团棉花。描边之后，后画的部件
  /// 会用自己的边压在先画的部件上，前后层次立刻成立。
  Paint get _edge => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = const Color(0xFFBFCBE2).withValues(alpha: 0.75);

  /// 填充 + 描边一个体块
  void _part(Canvas canvas, Path path) {
    canvas.drawPath(path, _bodyPaint);
    canvas.drawPath(path, _edge);
  }

  /// 渐细胶囊：从 [a]（半径 [ra]）到 [b]（半径 [rb]）的圆润管段，
  /// 两端各是一个圆帽，中间由两条**外公切线**平滑相连。
  ///
  /// 这是让「手臂-手」协调的关键图元（参考充气玩偶的肢体语言）：肢体不该
  /// 是等宽长条外接一个手，而应是一条**连续变粗细**的管——肩粗、肘收、
  /// 腕细、掌又鼓起。用同一个胶囊串起 肩→肘→腕→掌，相邻段端点同心同径，
  /// 接缝自然相切。
  Path _taperCapsule(Offset a, double ra, Offset b, double rb) {
    final d = b - a;
    final len = d.distance;
    final path = Path();
    if (len < 1e-3) {
      path.addOval(Rect.fromCircle(center: a, radius: math.max(ra, rb)));
      return path;
    }
    final ux = d.dx / len, uy = d.dy / len; // 轴向单位向量
    // 外公切线相对法向的倾角：半径差越大，管收得越急
    final sin = ((rb - ra) / len).clamp(-1.0, 1.0);
    final cos = math.sqrt(1 - sin * sin);
    final nx = -uy, ny = ux; // 左法向
    final lx = nx * cos - ux * sin, ly = ny * cos - uy * sin;
    final rx = -nx * cos - ux * sin, ry = -ny * cos - uy * sin;
    final angA = math.atan2(ly, lx); // 左切点方向
    final angB = math.atan2(ry, rx); // 右切点方向
    path
      ..moveTo(a.dx + lx * ra, a.dy + ly * ra)
      ..lineTo(b.dx + lx * rb, b.dy + ly * rb)
      // b 端圆帽：走朝向轴正方向的那段短弧
      ..arcTo(Rect.fromCircle(center: b, radius: rb), angA,
          _short(angA, angB), false)
      ..lineTo(a.dx + rx * ra, a.dy + ry * ra)
      // a 端圆帽：走背离 b 的那段长弧（故减一整圈换向）
      ..arcTo(Rect.fromCircle(center: a, radius: ra), angB,
          _short(angB, angA) - 2 * math.pi, false)
      ..close();
    return path;
  }

  /// 从 [from] 到 [to] 的最短有向弧，结果落在 (-π, π]
  double _short(double from, double to) {
    var d = (to - from) % (2 * math.pi);
    if (d <= -math.pi) d += 2 * math.pi;
    if (d > math.pi) d -= 2 * math.pi;
    return d;
  }

  /// 把若干关节点串成一条**连续渐细**的肢体，并合并为单一轮廓。
  ///
  /// 必须 union 成一个 Path 再描边：逐段描边会在每个关节处留下一圈多余的
  /// 接缝线，肢体看起来像用几节香肠拼的。
  Path _limbPath(List<(Offset, double)> joints) {
    var acc = _taperCapsule(
        joints[0].$1, joints[0].$2, joints[1].$1, joints[1].$2);
    for (var i = 1; i < joints.length - 1; i++) {
      // 中间关节补一个**完整圆**。胶囊的端帽只是圆的一部分，肘部折返角度
      // 越锐，两段端帽之间露出的内侧夹角就越尖——初版右肘就戳出了一根刺。
      // 补上整圆，关节任何弯折角度下都是圆的。
      acc = Path.combine(PathOperation.union, acc,
          Path()..addOval(Rect.fromCircle(
              center: joints[i].$1, radius: joints[i].$2)));
      acc = Path.combine(
          PathOperation.union,
          acc,
          _taperCapsule(
              joints[i].$1, joints[i].$2, joints[i + 1].$1, joints[i + 1].$2));
    }
    return acc;
  }

  /// 手：掌是比腕明显鼓起的圆块，掌缘长出几根短粗分指。
  ///
  /// 手指是独立的小管而非画在掌面上的刻线——刻线是平的，小管才有体积。
  Path _handPath(Offset palm, double pr, List<(Offset, Offset)> fingers) {
    var acc = Path()..addOval(Rect.fromCircle(center: palm, radius: pr));
    for (final (a, b) in fingers) {
      acc = Path.combine(
          PathOperation.union, acc, _taperCapsule(a, 22, b, 17));
    }
    return acc;
  }

  /// 证件照取景角标（品牌暗示：这是个拍证件照的 App）
  void _drawGuides(Canvas canvas) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = _guide.withValues(alpha: 0.48);
    const l = 214.0, r = 956.0, t = 596.0, b = 1976.0;
    const arm = 74.0, rad = 54.0;
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
    final k = 1 - float / 26;
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(585, 1946) - Offset(0, float),
          width: 430 * k,
          height: 68 * k),
      Paint()
        ..color = const Color(0xFFB7C1DD).withValues(alpha: 0.30 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
  }

  /// 后臂（画面左侧）：自然下垂、略向外撇，末端带手。
  /// 旧版这条手臂**根本没有手**，与右手形成明显的不对称破绽。
  void _drawRearArm(Canvas canvas) {
    final arm = _limbPath(const [
      (Offset(470, 1156), 80), // 肩
      (Offset(306, 1366), 66), // 肘：明显撑到躯干轮廓之外
      (Offset(300, 1548), 50), // 腕
    ]);
    final hand = _handPath(const Offset(298, 1606), 56, const [
      (Offset(274, 1638), Offset(268, 1676)),
      (Offset(300, 1644), Offset(298, 1684)),
      (Offset(326, 1638), Offset(332, 1676)),
    ]);
    // 合并后只描一次边：分开描边会让腕圆与掌圆的两条弧在重叠区交叉，
    // 凭空多出一个尖角。
    _part(canvas, Path.combine(PathOperation.union, arm, hand));
  }

  /// 双腿：短粗胶囊 + 圆脚底，落在躯干下缘两侧。
  void _drawLegs(Canvas canvas) {
    for (final cx in [492.0, 678.0]) {
      _part(
          canvas,
          _limbPath([
            (Offset(cx, 1596), 76),
            (Offset(cx, 1820), 70),
          ]));
    }
  }

  /// 躯干：上窄下宽的梨形。
  ///
  /// 比例是这一版重做的重点——旧版躯干又长又直，头反而比躯干还宽，
  /// 整体读起来是「雪人」而不是圆润机器人。
  void _drawBody(Canvas canvas) {
    // 颈：先于躯干绘制，下端**深深插进**躯干里。
    // 否则颈的描边会浮在胸口上，看起来像多了一圈衣领。
    _part(
        canvas,
        _limbPath(const [
          (Offset(585, 942), 50),
          (Offset(585, 1060), 58),
        ]));

    final path = Path()
      ..moveTo(440, 1140)
      ..cubicTo(440, 1040, 500, 990, 585, 990)
      ..cubicTo(670, 990, 730, 1040, 730, 1140)
      ..cubicTo(792, 1210, 812, 1340, 812, 1450)
      ..cubicTo(812, 1618, 712, 1706, 585, 1706)
      ..cubicTo(458, 1706, 358, 1618, 358, 1450)
      ..cubicTo(358, 1340, 378, 1210, 440, 1140)
      ..close();
    _part(canvas, path);
    // 胸腹分界：一条极淡的弧，暗示充气体块的接缝
    canvas.drawPath(
      Path()
        ..moveTo(400, 1436)
        ..cubicTo(494, 1474, 676, 1474, 770, 1436),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = const Color(0xFFD8DFEC),
    );
  }

  void _drawHead(Canvas canvas) {
    final head = Path()
      ..addOval(Rect.fromCenter(
          center: const Offset(585, 806), width: 372, height: 320));
    _part(canvas, head);

    // 腮红：让形象更亲和
    for (final cx in [468.0, 702.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 858), width: 84, height: 46),
        Paint()..color = const Color(0xFFFFA9B4).withValues(alpha: 0.28),
      );
    }

    _drawEyes(canvas);

    // 微笑
    canvas.drawPath(
      Path()
        ..moveTo(551, 890)
        ..quadraticBezierTo(585, 918, 619, 890),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..color = _ink.withValues(alpha: 0.75),
    );
  }

  /// 双眼同步眨动：睁开时是竖椭圆 + 高光，闭合时压成一条带弧度的眼睑线。
  ///
  /// 刻意**不画两眼之间的连线**：那是参考形象的标志性特征，既涉及他人
  /// 角色识别，也会把我们这套「有瞳孔 + 会眨眼」的表情语言压扁成一条杠。
  void _drawEyes(Canvas canvas) {
    final open = eyeOpen.value.clamp(0.0, 1.0);
    const rx = 27.0, ry = 38.0, cy = 800.0;
    final ink = Paint()..color = _ink;

    for (final cx in [521.0, 649.0]) {
      if (open > 0.18) {
        final h = ry * open;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: h * 2),
          ink,
        );
        // 高光：让眼睛有神（随睁开度淡出，闭眼时不该有反光）
        canvas.drawCircle(
          Offset(cx + 9, cy - h * 0.42),
          9 * open,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * open),
        );
      } else {
        // 闭眼：向下弯的弧线，比直线自然
        canvas.drawPath(
          Path()
            ..moveTo(cx - rx, cy - 4)
            ..quadraticBezierTo(cx, cy + 14, cx + rx, cy - 4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round
            ..color = _ink,
        );
      }
    }
  }

  /// 前臂（画面右侧）：**抬起自拍**的姿势——肩向外、肘弯起、前臂上举。
  ///
  /// 旧版是一条垂到胯边的长胶囊，手机却悬在肩膀上方，中间没有任何连接，
  /// 「举着手机」这件事在结构上根本不成立。现在 肩→肘→腕→掌 是连续的
  /// 一条，掌正好托在机身底部，姿势才读得懂。
  void _drawFrontArm(Canvas canvas) {
    final arm = _limbPath(const [
      (Offset(748, 1156), 80), // 肩（只浅浅嵌进躯干，避免描边横穿胸口）
      (Offset(902, 1332), 66), // 肘：向外下方撑开
      (Offset(880, 1062), 46), // 腕
    ]);
    // 掌托住机身底端，三指搭上机身正面，拇指从左缘扣住
    final hand = _handPath(const Offset(880, 1054), 60, const [
      (Offset(842, 1026), Offset(830, 972)),
      (Offset(880, 1020), Offset(876, 962)),
      (Offset(918, 1030), Offset(922, 978)),
      (Offset(834, 1076), Offset(794, 1062)),
    ]);
    _part(canvas, Path.combine(PathOperation.union, arm, hand));
  }

  /// 手机：机身略向内倾（顶端偏向脸），表达「镜头正对着自己」。
  ///
  /// 按插画惯例画成能看见屏幕与快门键的一面——真实自拍看到的是机背，
  /// 但那样就丢掉了「正在拍照」这个信息。
  void _drawPhone(Canvas canvas) {
    canvas.save();
    canvas.translate(876, 900);
    canvas.rotate(-9 * math.pi / 180);
    canvas.translate(-876, -900);

    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(798, 742, 156, 268), const Radius.circular(28));
    canvas.drawRRect(
      body.shift(const Offset(0, 8)),
      Paint()
        ..color = const Color(0xFF8F9BBB).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF343B54));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(810, 758, 132, 236), const Radius.circular(19)),
      Paint()..color = const Color(0xFFEEF4FF),
    );
    // 快门键：随呼吸轻微脉动，暗示「随时可以按下」
    final pulse = 1 + 0.06 * math.sin(ambient.value * math.pi * 2);
    canvas.drawCircle(const Offset(876, 838), 38 * pulse,
        Paint()..color = const Color(0xFFFF6F7D));
    canvas.drawCircle(const Offset(876, 838), 18 * pulse,
        Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.restore();
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
