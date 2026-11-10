import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/embedding_model_store.dart';

/// 「我的」→ 图片处理模型：查看状态、下载/暂停/删除加强版语义模型。
class EmbeddingModelPage extends StatefulWidget {
  const EmbeddingModelPage({super.key, this.store});
  final EmbeddingModelStore? store;
  @override
  State<EmbeddingModelPage> createState() => _EmbeddingModelPageState();
}

class _EmbeddingModelPageState extends State<EmbeddingModelPage> {
  EmbeddingModelStore? _store;
  EmbeddingModelProgress? _progress;
  String? _error;
  bool _onlyWifi = true;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = widget.store ?? await EmbeddingModelStore.open();
      if (mounted) setState(() => _store = s);
    } catch (_) {
      if (mounted) setState(() => _error = 'access');
    }
  }

  Future<void> _download() async {
    final s = _store;
    if (s == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await s.startDownload(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          wifiOnly: _onlyWifi);
    } on EmbeddingWifiRequired {
      if (mounted) setState(() => _error = 'wifi');
    } catch (_) {
      if (mounted) setState(() => _error = 'download');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _pause() async {
    await _store?.pauseDownload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final s = _store;
    final l = AppLocalizations.of(context);
    if (s == null || _busy) return;
    final ok = await showAdaptiveDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog.adaptive(
                title: Text(l.modelDelete),
                content: Text(l.modelDeleteConfirm),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.dialogCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.modelDelete))
                ])) ??
        false;
    if (!ok) return;
    await s.delete();
    if (mounted) setState(() {});
  }

  String _mb(int b) => (b / (1024 * 1024)).round().toString();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _store;
    final status = s?.status ?? EmbeddingModelStatus.notInstalled;
    final downloading = _busy && s?.status == EmbeddingModelStatus.downloading;
    return Scaffold(
      appBar: AppBar(title: Text(l.modelTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Text(l.modelDesc, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 6),
        Text(l.modelSizeApprox, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(switch (status) {
                      EmbeddingModelStatus.ready => Icons.check_circle,
                      EmbeddingModelStatus.corrupt => Icons.error_outline,
                      EmbeddingModelStatus.downloading => Icons.downloading,
                      _ => Icons.cloud_download_outlined,
                    }),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(switch (status) {
                      EmbeddingModelStatus.ready =>
                        l.modelInstalledAt(_mb(s!.installedBytes)),
                      EmbeddingModelStatus.corrupt => l.modelStatusCorrupt,
                      EmbeddingModelStatus.downloading => l.modelStatusDownloading,
                      EmbeddingModelStatus.partial => l.modelStatusPartial,
                      _ => l.modelStatusMissing,
                    }, style: Theme.of(context).textTheme.titleMedium)),
                  ]),
                  if (_progress != null) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                        value: _progress!.totalBytes == 0
                            ? null
                            : _progress!.receivedBytes / _progress!.totalBytes),
                    const SizedBox(height: 6),
                    Text(l.modelProgress(_mb(_progress!.receivedBytes),
                        _mb(_progress!.totalBytes))),
                  ],
                  if (_error == 'download') ...[
                    const SizedBox(height: 8),
                    Text(l.loadFailed,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_error == 'wifi') ...[
                    const SizedBox(height: 8),
                    Text(l.modelWifiBlocked),
                  ],
                ]))),
        const SizedBox(height: 12),
        SwitchListTile(
            value: _onlyWifi,
            title: Text(l.modelOnlyWifi),
            subtitle: Text(l.modelWifiHint),
            onChanged: (v) => setState(() => _onlyWifi = v)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, children: [
          if (status == EmbeddingModelStatus.ready)
            OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.modelDelete))
          else if (downloading)
            FilledButton.icon(
                onPressed: _pause,
                icon: const Icon(Icons.pause),
                label: Text(l.modelPause))
          else
            FilledButton.icon(
                key: const Key('model-download'),
                onPressed: _busy ? null : _download,
                icon: const Icon(Icons.download),
                label: Text(status == EmbeddingModelStatus.partial
                    ? l.modelResume
                    : l.modelDownload)),
        ]),
      ]),
    );
  }
}
