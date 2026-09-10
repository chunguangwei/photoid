import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../services/update_service.dart';

/// 「发现新版本」对话框：应用内流式下载 APK 并显示进度条，
/// 完成后拉起系统安装器。不依赖系统 DownloadManager（其通知为英文且
/// 国产 ROM 常静默失败），与微信/支付宝等行业实践一致。
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !info.isForceUpdate,
    builder: (context) => _UpdateDialog(info: info),
  );
}

enum _DlState { idle, downloading, done, error, needPermission }

class _InstallBlocked implements Exception {}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  static const _apkName = 'photoid-update.apk';
  static const _partName = 'photoid-update.apk.part';
  // 断点续传状态（杀进程后仍可续）
  static const _prefUrl = 'upd_resume_url';
  static const _prefTotal = 'upd_resume_total';

  _DlState _state = _DlState.idle;
  int _received = 0;
  int _total = 0;
  http.Client? _client;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  /// 断点续传下载：
  /// 1. 分片写入 .part 文件，URL/总大小持久化到 SharedPreferences
  /// 2. 重试/重启后发现同 URL 分片 → Range: bytes=N- 续传（服务器需 206）
  /// 3. 完成后改名正式 APK 并清状态；切后台被杀/网络中断均可从断点继续
  Future<void> _startDownload() async {
    setState(() => _state = _DlState.downloading);
    final client = http.Client();
    _client = client;
    try {
      // 直链优先、镜像回退探测（国内直连 GitHub 资产常超时）
      final url =
          await UpdateService().resolveDownloadUrl(widget.info.downloadUrl);
      // cache 目录：open_filex FileProvider 覆盖，且系统清理策略友好
      final dir = await getTemporaryDirectory();
      final part = File(p.join(dir.path, _partName));
      final file = File(p.join(dir.path, _apkName));
      if (await file.exists()) await file.delete();
      final prefs = await SharedPreferences.getInstance();

      // 断点恢复：同 URL 且有分片 → 从已有长度续传
      var resumeFrom = 0;
      if (prefs.getString(_prefUrl) == url && await part.exists()) {
        resumeFrom = await part.length();
      } else if (await part.exists()) {
        await part.delete();
      }

      final req = http.Request('GET', Uri.parse(url));
      if (resumeFrom > 0) req.headers['Range'] = 'bytes=$resumeFrom-';
      final response = await client.send(req);
      if (resumeFrom > 0 && response.statusCode != 206) {
        // 服务器不支持续传：重来
        resumeFrom = 0;
        await part.delete();
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      _received = resumeFrom;
      _total = resumeFrom > 0
          ? resumeFrom + (response.contentLength ?? 0)
          : (response.contentLength ?? 0);
      await prefs.setString(_prefUrl, url);
      await prefs.setInt(_prefTotal, _total);

      final sink = part.openWrite(
          mode: resumeFrom > 0 ? FileMode.append : FileMode.write);
      await for (final chunk in response.stream) {
        sink.add(chunk);
        _received += chunk.length;
        if (mounted) setState(() {});
      }
      await sink.flush();
      await sink.close();
      // 完整性校验：长度不符视为失败，防止装到半截包（分片保留可续）
      if (_total > 0 && _received != _total) {
        throw const HttpException('incomplete');
      }
      await part.rename(file.path);
      await prefs.remove(_prefUrl);
      await prefs.remove(_prefTotal);
      if (!mounted) return;
      setState(() => _state = _DlState.done);
      await _install(file.path);
    } on _InstallBlocked {
      if (!mounted) return;
      setState(() => _state = _DlState.needPermission);
    } catch (e) {
      if (!mounted) return;
      // 取消时 _state 已被 _cancel 置回 idle，此处不再覆盖
      if (_state == _DlState.downloading) {
        setState(() => _state = _DlState.error);
      }
      debugPrint('Update download failed: $e');
    }
  }

  /// 拉起系统安装器。Android 8+ 需「安装未知应用」授权：
  /// 未授权时先弹系统授权页，用户返回后再次点击安装。
  Future<void> _install(String path) async {
    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        // 国产 ROM 常拦截运行时弹窗，直接跳「未知来源」系统设置页
        await openAppSettings();
        throw _InstallBlocked();
      }
    }
    final result = await OpenFilex.open(path,
        type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw Exception('open installer failed: ${result.message}');
    }
  }

  Future<void> _retryInstall() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _apkName));
    if (!await file.exists()) {
      setState(() => _state = _DlState.error);
      return;
    }
    try {
      await _install(file.path);
      if (mounted) setState(() => _state = _DlState.done);
    } on _InstallBlocked {
      if (mounted) setState(() => _state = _DlState.needPermission);
    } catch (_) {
      if (mounted) setState(() => _state = _DlState.error);
    }
  }

  void _cancel() {
    _client?.close();
    _client = null;
    if (mounted) setState(() => _state = _DlState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = widget.info;
    final percent =
        _total > 0 ? (_received / _total * 100).clamp(0, 100).round() : null;

    return PopScope(
      canPop: !info.isForceUpdate && _state != _DlState.downloading,
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
                  child: Text(info.releaseNotes,
                      style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            if (_state == _DlState.downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                  value: percent != null ? _received / _total : null),
              const SizedBox(height: 8),
              Text(
                percent != null
                    ? l.updateProgress(percent, _mb(_received), _mb(_total))
                    : l.updateProgressUnknown(_mb(_received)),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_state == _DlState.error) ...[
              const SizedBox(height: 12),
              Text(l.updateDownloadFailed,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            if (_state == _DlState.needPermission) ...[
              const SizedBox(height: 12),
              Text(l.updateNeedInstallPermission,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            if (_state == _DlState.done) ...[
              const SizedBox(height: 12),
              Text(l.updateDone, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          ...switch (_state) {
            _DlState.idle => [
                if (!info.isForceUpdate)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.updateLater),
                  ),
                FilledButton(
                  onPressed: _startDownload,
                  child: Text(l.updateNow),
                ),
              ],
            _DlState.downloading => [
                TextButton(
                  onPressed: _cancel,
                  child: Text(l.updateCancel),
                ),
              ],
            _DlState.error => [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.updateLater),
                ),
                FilledButton(
                  onPressed: _startDownload,
                  child: Text(l.updateRetry),
                ),
              ],
            _DlState.done => [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.updateInstall),
                ),
              ],
            _DlState.needPermission => [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.updateLater),
                ),
                FilledButton(
                  // 授权后重试安装（APK 已下载，直接复用）
                  onPressed: _retryInstall,
                  child: Text(l.updateRetryInstall),
                ),
              ],
          },
        ],
      ),
    );
  }

  String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);
}
