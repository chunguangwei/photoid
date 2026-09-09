import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/album_service.dart';
import '../services/compliance_service.dart';

/// 检测与保存页：合规报告 + 教育ID命名 + 保存到相册。
class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.jpgBytes, required this.spec});

  final Uint8List jpgBytes;
  final PhotoSpec spec;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final _eduIdController = TextEditingController();
  ComplianceReport? _report;
  String? _reportError;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    ComplianceService().check(widget.jpgBytes, widget.spec).then((r) {
      if (mounted) setState(() => _report = r);
    }).catchError((Object e) {
      // 检测失败（如 ML Kit 异常）时给出错误态而非无限转圈
      if (mounted) setState(() => _reportError = '$e');
    });
  }

  @override
  void dispose() {
    _eduIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final permissionError = AppLocalizations.of(context).galleryPermissionDenied;
    final eduId = _eduIdController.text.trim();
    if (eduId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).eduIdRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw Exception(permissionError);
      // 通过文件名传递教育ID：Android MediaStore / iOS Photos 均保留文件名
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, '$eduId.jpg'));
      await file.writeAsBytes(widget.jpgBytes, flush: true);
      await Gal.putImage(file.path);
      file.delete().ignore();
      // 同步双写 App 相册；失败仅记录，不影响主保存流程
      AlbumService.save(widget.jpgBytes, eduId).then((_) {}, onError: (e) {
        debugPrint('AlbumService.save failed: $e');
      });
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).savedToGallery('$eduId.jpg'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).saveFailed('$e'))));
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
                  color: Colors.black12,
                  child: Image.memory(widget.jpgBytes, fit: BoxFit.cover),
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
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.checkItemsTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (report == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _reportError != null
                      ? Text(_reportError!, textAlign: TextAlign.center)
                      : const CircularProgressIndicator(),
                ),
              )
            else
              ...report.items.map(_buildCheckTile),
            const SizedBox(height: 16),
            TextField(
              controller: _eduIdController,
              enabled: !_saved,
              decoration: InputDecoration(
                labelText: l.eduIdLabel,
                hintText: l.eduIdHint,
                border: const OutlineInputBorder(),
                suffixText: '.jpg',
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
          child: _saved
              ? FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l.doneRetake,
                        style: const TextStyle(fontSize: 16)),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l.saveToGallery,
                        style: const TextStyle(fontSize: 16)),
                  ),
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
      trailing: item.detail != null && item.pass ? null : null,
    );
  }
}
