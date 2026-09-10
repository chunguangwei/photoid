import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'home_page.dart';

/// 启动页：全屏设计图（品牌视觉）+ 6 秒倒计时可跳过 + 广告位槽预留。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const _totalSeconds = 6;

  Timer? _countdownTimer;
  int _remain = _totalSeconds;
  bool _left = false;

  @override
  void initState() {
    super.initState();
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
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 全屏设计图（cover 适配各比例）
          Image.asset(
            'assets/splash_loading.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFFF2F4F9)),
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
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: TextButton(
              onPressed: _leave,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: Text(l.splashSkip(_remain),
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
          ),
        ],
      ),
    );
  }
}
