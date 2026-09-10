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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.35),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
          children: [
            // 跳过 + 倒计时
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _leave,
                  style: TextButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: Text(l.splashSkip(_remain),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const Spacer(flex: 2),
            // logo 白卡 + 眨眼双眼 + 浮动
            AnimatedBuilder(
              animation: Listenable.merge([_floatOffset, _sway]),
              builder: (context, child) => Transform.translate(
                offset: Offset(_swayX.value, _floatOffset.value),
                child: Transform.rotate(
                  angle: _swayAngle.value,
                  child: child,
                ),
              ),
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: [
                    // 双层阴影：近处柔边深色 + 远处环境光，出质感
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.08),
                      blurRadius: 48,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Image.asset('assets/icon.png',
                          width: 120, height: 120),
                    ),
                    // 双眼（logo 上半部，眨眼 scaleY）
                    Positioned(
                      top: 58,
                      child: AnimatedBuilder(
                        animation: _blink,
                        builder: (context, _) {
                          final sy = 1 - _blink.value * 0.9;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _eye(sy),
                              const SizedBox(width: 22),
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
            const SizedBox(height: 20),
            Text(l.appTitle,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(l.privacyNote,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            const Spacer(flex: 3),
            // 广告位槽（本版留空不展示文案，接广告 SDK 时在此填充）
            const SizedBox(height: 60),
            const SizedBox(height: 24),
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
