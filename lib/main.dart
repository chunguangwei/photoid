import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'pages/splash_page.dart';
import 'pages/update_dialog.dart';
import 'services/locale_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // release 下子树构建/绘制异常默认只显示灰盒且静默：
  // 这里把异常+堆栈打到 logcat（release 可见），便于真机问题定位
  ErrorWidget.builder = (details) {
    debugPrint('PhotoID ErrorWidget: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
    return ErrorWidget(details.exception);
  };
  await LocaleService.load();
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
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleService.locale,
      builder: (context, localeOverride, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        navigatorKey: _navigatorKey,
        // 手动语言设置（设置页可改）；null 时按系统语言回退
        locale: localeOverride,
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
        builder: (context, child) {
          final scaler = MediaQuery.textScalerOf(context)
              .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          );
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B6CB0)),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2B6CB0), brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const SplashPage(),
      ),
    );
  }
}
