import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'home_page.dart';

/// 启动页（对标行业：品牌加载动效 + 倒计时跳过 + 广告位预留）。
/// 主体为我们的 logo 圆润白卡（非大白形象，规避版权）+ 双眼周期眨眼 +
/// 整体轻微浮动。6 秒自动进入首页，可提前跳过。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  static const _totalSeconds = 6;

  /// 眨眼动画：scaleY 1→0.1→1（每 ~2.8s 触发一次）
  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));

  /// 整体轻微浮动 ±6dp
  late final AnimationController _float = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);

  late final Animation<double> _floatOffset = Tween<double>(begin: -6, end: 6)
      .animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));

  /// 左右摆头：旋转 ±3° + 水平 ±10 平移（3.2s 慢速往返）
  late final AnimationController _sway = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat(reverse: true);

  late final Animation<double> _swayAngle =
      Tween<double>(begin: -0.05, end: 0.05)
          .animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));
  late final Animation<double> _swayX = Tween<double>(begin: -10, end: 10)
      .animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

  Timer? _blinkTimer;
  Timer? _countdownTimer;
  int _remain = _totalSeconds;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _blinkTimer =
        Timer.periodic(const Duration(milliseconds: 2800), (_) async {
      if (!mounted) return;
      await _blink.forward();
      if (mounted) _blink.reverse();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remain <= 1) {
        _leave();
      } else {
        setState(() => _remain--);
      }
    });
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _countdownTimer?.cancel();
    _blink.dispose();
    _float.dispose();
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        // 全屏渐变（logo 蓝灰主调），无框无卡片
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF93A8C4), Color(0xFF5E7BA0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 中央剪影人物（摆头 + 浮动 + 眨眼）
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_floatOffset, _sway]),
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_swayX.value, _floatOffset.value - 40),
                    child: Transform.rotate(
                      angle: _swayAngle.value,
                      child: child,
                    ),
                  ),
                  child: SizedBox(
                    width: 260,
                    height: 340,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // 白色剪影（logo 人形主调，柔和投影出质感）
                        CustomPaint(
                          size: const Size(260, 340),
                          painter: _SilhouettePainter(),
                        ),
                        // 双眼（头部，眨眼）
                        Positioned(
                          top: 80,
                          child: AnimatedBuilder(
                            animation: _blink,
                            builder: (context, _) {
                              final sy = 1 - _blink.value * 0.9;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _eye(sy),
                                  const SizedBox(width: 30),
                                  _eye(sy),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 名称 + 隐私语（底部上方）
              Positioned(
                left: 0,
                right: 0,
                bottom: 120,
                child: Column(
                  children: [
                    Text(l.appTitle,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(l.privacyNote,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              // 广告位槽（本版留空不展示，接 SDK 时填充）
              const Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SizedBox(height: 60),
              ),
              // 跳过 + 倒计时
              Positioned(
                top: 12,
                right: 16,
                child: TextButton(
                  onPressed: _leave,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                  ),
                  child: Text(l.splashSkip(_remain),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eye(double scaleY) => Transform.scale(
        scaleY: scaleY,
        child: Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            color: Color(0xFF2B2B2B),
            shape: BoxShape.circle,
          ),
        ),
      );
}

/// 白色剪影人物（logo 人形主调）：头身一体的圆润气球感造型，
/// 径向渐变出软立体明暗（左上受光、右下微暗）+ 地面软阴影。
class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    // 全身气球人：头 + 卵圆身 + 短臂 + 短腿（大重叠融成一体）
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, 88), radius: 56))
      // 身体（卵圆，顶部宽、与头底深度融合）
      ..addOval(Rect.fromCenter(
          center: Offset(cx, 205), width: 190, height: 190))
      // 左右短臂（微外张胶囊）
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx - 98, 190), width: 38, height: 110),
          const Radius.circular(19)))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + 98, 190), width: 38, height: 110),
          const Radius.circular(19)))
      // 左右短腿
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx - 34, 300), width: 42, height: 60),
          const Radius.circular(18)))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + 34, 300), width: 42, height: 60),
          const Radius.circular(18)));

    // 地面软阴影（椭圆 + 模糊）
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, 332), width: 175, height: 20),
        Paint()
          ..color = const Color(0xFF3A5578).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // 主体：径向渐变（左上受光白 → 右下微蓝灰），气球软立体
    final bounds = Rect.fromLTWH(cx - 120, 28, 240, 320);
    canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.55),
            radius: 1.15,
            colors: const [
              Colors.white,
              Color(0xFFF4F6FA),
              Color(0xFFDDE4EE),
            ],
            stops: [0.0, 0.55, 1.0],
          ).createShader(bounds));
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => false;
}
