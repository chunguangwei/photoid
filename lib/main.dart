import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';
import 'pages/update_dialog.dart';
import 'services/locale_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 后台下载引擎（WorkManager 持久任务，切后台/杀进程不中断）
  if (Platform.isAndroid) {
    await FlutterDownloader.initialize(debug: false);
  }
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
  final ReceivePort _dlPort = ReceivePort();

  static const _dlPortName = 'photoid_downloader';
  static const _apkName = 'photoid-update.apk';

  @override
  void initState() {
    super.initState();
    // 启动 3 秒后静默检查 GitHub Release，避免影响首屏。
    _updateCheckTimer = Timer(const Duration(seconds: 3), _checkUpdate);
    _registerDownloadListener();
  }

  /// 下载完成监听（App 生命周期）：前台时直接拉起安装器；
  /// 后台/被杀时由系统通知点击打开 APK（openFileFromNotification）。
  void _registerDownloadListener() {
    if (!Platform.isAndroid) return;
    IsolateNameServer.registerPortWithName(_dlPort.sendPort, _dlPortName);
    FlutterDownloader.registerCallback(_downloadCallback, step: 1);
    _dlPort.listen((dynamic msg) async {
      final status = msg[1];
      final complete = status == DownloadTaskStatus.complete ||
          status == DownloadTaskStatus.complete.index;
      if (complete) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) OpenFilex.open('${dir.path}/$_apkName');
      }
    });
  }

  @pragma('vm:entry-point')
  static void _downloadCallback(String id, int status, int progress) {
    IsolateNameServer.lookupPortByName(_dlPortName)
        ?.send([id, status, progress]);
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    IsolateNameServer.removePortNameMapping(_dlPortName);
    _dlPort.close();
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B6CB0)),
        useMaterial3: true,
      ),
        home: const HomePage(),
      ),
    );
  }
}
