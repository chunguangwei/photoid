import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';
import 'pages/update_dialog.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhotoIdApp());
}

class PhotoIdApp extends StatefulWidget {
  const PhotoIdApp({super.key});

  @override
  State<PhotoIdApp> createState() => _PhotoIdAppState();
}

class _PhotoIdAppState extends State<PhotoIdApp> {
  /// 用于在 MaterialApp 的 Navigator 之上弹出升级对话框。
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    // 启动 3 秒后静默检查 GitHub Release，避免影响首屏。
    _updateCheckTimer = Timer(const Duration(seconds: 3), _checkUpdate);
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService().checkUpdate();
    final context = _navigatorKey.currentContext;
    if (info != null && context != null && context.mounted) {
      await showUpdateDialog(context, info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      navigatorKey: _navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supported) {
        // 系统语言为英文时用英文，否则回退中文。
        if (deviceLocale != null && deviceLocale.languageCode == 'en') {
          return const Locale('en');
        }
        return const Locale('zh');
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B6CB0)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
