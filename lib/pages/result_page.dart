import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/album_service.dart';
import '../services/compliance_service.dart';
import '../services/delivery_report.dart';
import '../services/delivery_export_cache.dart';
import '../widgets/glass_surface.dart';
import '../widgets/photo_input.dart';

/// 检测与保存页：合规报告 + 自定义文件命名 + 保存到相册。
class ResultPage extends StatefulWidget {
  const ResultPage(
      {super.key,
      required this.jpgBytes,
      required this.spec,
      this.onDelivered});

  final Future<void> Function(Uint8List, PhotoSpec)? onDelivered;

  final Uint8List jpgBytes;
  final PhotoSpec spec;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final TextEditingController _nameController =
      TextEditingController(text: _genFileName());

  /// 默认文件名：时间戳+毫秒，连点「重新生成」也不会重名
  static String _genFileName() {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'photoid_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}_'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  ComplianceReport? _report;
  String? _reportError;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  void _check() {
    setState(() {
      _report = null;
      _reportError = null;
    });
    ComplianceService().check(widget.jpgBytes, widget.spec).then((r) {
      if (mounted) setState(() => _report = r);
    }).catchError((Object e) {
      // 检测失败（如 ML Kit 异常）时给出错误态而非无限转圈
      if (mounted) setState(() => _reportError = '$e');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveToTask() async {
    if (_saving || widget.onDelivered == null) return;
    setState(() => _saving = true);
    try {
      await widget.onDelivered!(widget.jpgBytes, widget.spec);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pop();
    } catch (e) {
      if (mounted) showPhotoActionError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final permissionError =
        AppLocalizations.of(context).galleryPermissionDenied;
    final fileName = _nameController.text.trim();
    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).fileNameRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw Exception(permissionError);
      // 通过文件名传递用户命名：Android MediaStore / iOS Photos 均保留文件名
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, '$fileName.jpg'));
      try {
        await file.writeAsBytes(widget.jpgBytes, flush: true);
        await Gal.putImage(file.path);
      } finally {
        if (await file.exists()) await file.delete();
      }
      // 同步双写 App 相册；失败仅记录，不影响主保存流程
      try {
        await AlbumService.save(widget.jpgBytes, fileName);
      } catch (e) {
        debugPrint('AlbumService.save failed: $e');
      }
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              AppLocalizations.of(context).savedToGallery('$fileName.jpg'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).saveFailed('$e'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportFiles() async {
    final report = _report;
    if (report == null || _saving) return;
    final l = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.fileNameRequired)));
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final json = buildDeliveryReport(
        fileName: '$name.jpg',
        jpgBytes: widget.jpgBytes,
        spec: widget.spec,
        report: report);
    setState(() => _saving = true);
    try {
      final cache = DeliveryExportCache(await getTemporaryDirectory());
      await cache.cleanExpired();
      final files = await cache.prepare(
          name: name, jpgBytes: widget.jpgBytes, report: json);
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(files[0].path, mimeType: 'image/jpeg'),
          XFile(files[1].path, mimeType: 'application/json'),
        ],
        fileNameOverrides: ['$name.jpg', '$name.checks.json'],
        sharePositionOrigin: origin,
      ));
      // A share sheet result cannot guarantee the chosen destination saved it.
      // Keep the screen available for another export or Photos save.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.saveFailed('$e'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final tr = Tr.of(context);
    final report = _report;
    final kb = widget.jpgBytes.lengthInBytes / 1024;
    return Scaffold(
      appBar: AppBar(title: Text(l.resultTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 96,
                  height: 128,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Image.memory(widget.jpgBytes, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr.specName(widget.spec),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.spec.pixelWidth}×${widget.spec.pixelHeight}px · '
                        '${kb.toStringAsFixed(0)}KB · JPG',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (report != null)
                        Wrap(children: [
                          Chip(
                            avatar: Icon(
                              report.hardAllPass
                                  ? Icons.check_circle
                                  : Icons.warning_amber,
                              size: 18,
                              color: report.hardAllPass
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            label: Text(report.hardAllPass
                                ? l.verdictPass
                                : l.verdictFail),
                          )
                        ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.photoChecksNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(l.checkItemsTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (report == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _reportError != null
                      ? Column(children: [
                          Text(l.checkFailedRetry, textAlign: TextAlign.center),
                          TextButton(onPressed: _check, child: Text(l.retry)),
                        ])
                      : const CircularProgressIndicator(),
                ),
              )
            else
              ...report.items.map(_buildCheckTile),
            const SizedBox(height: 16),
            Text(l.deliveryExportHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: !_saved && !_saving,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l.fileNameLabel,
                hintText: l.fileNameHint,
                border: const OutlineInputBorder(),
                suffixText: '.jpg',
                suffixIcon: IconButton(
                  tooltip: l.fileNameRegenerate,
                  icon: const Icon(Icons.autorenew),
                  onPressed: _saved || _saving
                      ? null
                      : () =>
                          setState(() => _nameController.text = _genFileName()),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlassSurface(
            padding: const EdgeInsets.all(10),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onDelivered != null) ...[
                    FilledButton.icon(
                      key: const Key('save-output-to-task'),
                      onPressed: _saving || report == null ? null : _saveToTask,
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text(l.taskSaveOutput),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (!_saved) ...[
                    FilledButton.icon(
                        onPressed:
                            _saving || report == null ? null : _exportFiles,
                        icon: const Icon(Icons.ios_share),
                        label: Text(l.deliveryExport)),
                    const SizedBox(height: 4),
                  ],
                  _saved
                      ? FilledButton.icon(
                          onPressed: () => Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(l.doneRetake,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _saving || report == null ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_alt),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(l.saveToGallery,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckTile(CheckItem item) {
    final l = AppLocalizations.of(context);
    final tr = Tr.of(context);
    final color = item.pass
        ? Colors.green
        : item.soft
            ? Colors.orange
            : Colors.red;
    final icon = item.pass
        ? Icons.check_circle
        : item.soft
            ? Icons.warning_amber
            : Icons.cancel;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(tr.checkLabel(item, widget.spec) +
          (item.soft ? l.referenceSuffix : '')),
      subtitle: item.pass
          ? (item.detail != null ? Text(tr.detail(item)!) : null)
          : Text([tr.detail(item), tr.fix(item, widget.spec)]
              .whereType<String>()
              .join(l.referenceJoiner)),
    );
  }
}
