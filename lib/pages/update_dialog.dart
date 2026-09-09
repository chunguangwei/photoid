import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';

/// 弹出「发现新版本」对话框；用户选择「立即更新」后由系统 DownloadManager
/// 在后台下载（通知栏显示进度，切后台/杀进程不中断）。
/// 完成监听在 main.dart（App 生命周期）；通知点击亦可直接拉起安装。
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !info.isForceUpdate,
    builder: (context) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  static const _apkName = 'photoid-update.apk';

  bool _started = false;
  String? _error;

  Future<void> _startBackgroundDownload() async {
    if (_started) return;
    // 立即占位：权限弹窗等待期间防止重复点击重复 enqueue 同一 APK
    setState(() {
      _started = true;
      _error = null;
    });
    try {
      // Android 13+ 通知权限（用于在任务栏显示下载进度）。
      // 限定 Android：其它平台（含测试宿主 macOS）该请求会挂起不返回。
      if (Platform.isAndroid) await Permission.notification.request();

      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      // 直链优先、镜像回退探测（国内直连 GitHub 资产常超时）
      final url = await UpdateService().resolveDownloadUrl(widget.info.downloadUrl);
      await FlutterDownloader.enqueue(
        url: url,
        savedDir: dir.path,
        fileName: _apkName,
        showNotification: true,
        openFileFromNotification: true,
      );
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.updateBgStarted)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _started = false;
        _error = AppLocalizations.of(context).updateDownloadFailed;
      });
      debugPrint('Enqueue update download failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final info = widget.info;
    return PopScope(
      canPop: !info.isForceUpdate,
      child: AlertDialog(
        title: Text(l.updateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v${info.version}', style: theme.textTheme.titleMedium),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child:
                      Text(info.releaseNotes, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed:
                info.isForceUpdate ? null : () => Navigator.of(context).pop(),
            child: Text(l.updateLater),
          ),
          FilledButton(
            onPressed: _started ? null : _startBackgroundDownload,
            child: Text(l.updateNow),
          ),
        ],
      ),
    );
  }
}
