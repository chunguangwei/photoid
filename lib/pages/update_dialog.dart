import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';

/// 弹出「发现新版本」对话框；用户选择「立即更新」后开始下载并安装 APK。
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
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/photoid-update.apk');

      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await request.send();
      if (response.statusCode != 200) {
        throw HttpException('下载失败（HTTP ${response.statusCode}）');
      }

      final sink = apkFile.openWrite();
      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      try {
        // addStream 提供背压，避免大 APK 一次性占满内存。
        await sink.addStream(response.stream.map((chunk) {
          receivedBytes += chunk.length;
          if (totalBytes > 0 && mounted) {
            setState(() => _progress = receivedBytes / totalBytes);
          }
          return chunk;
        }));
      } catch (_) {
        try {
          await sink.close();
        } catch (_) {
          // 关闭失败由下面的删除与上层错误提示兜底。
        }
        await apkFile.delete().catchError((_) => apkFile);
        rethrow;
      }
      await sink.close();
      if (!mounted) return;

      // 触发系统 PackageInstaller 安装流程。
      await OpenFilex.open(apkFile.path);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = AppLocalizations.of(context).updateDownloadFailed;
      });
      debugPrint('Update download failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final info = widget.info;
    return PopScope(
      canPop: !info.isForceUpdate && !_downloading,
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
                  child: Text(info.releaseNotes, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Text('${(_progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (!_downloading)
            TextButton(
              onPressed: info.isForceUpdate
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l.updateLater),
            ),
          FilledButton(
            onPressed: _downloading ? null : _downloadAndInstall,
            child: Text(l.updateNow),
          ),
        ],
      ),
    );
  }
}
