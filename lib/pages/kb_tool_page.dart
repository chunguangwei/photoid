import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../services/album_service.dart';
import '../services/kb_compressor.dart';

/// 通用改 KB 工具：任选照片，按目标大小（5–2048KB）二分压缩后保存。
class KbToolPage extends StatefulWidget {
  const KbToolPage({super.key});

  @override
  State<KbToolPage> createState() => _KbToolPageState();
}

class _KbToolPageState extends State<KbToolPage> {
  final _targetController = TextEditingController();
  String? _pickedPath;
  int? _originalBytes;
  Uint8List? _resultBytes;
  (int, int)? _resultSize;
  bool _busy = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 99);
      if (picked == null) return;
      final size = await File(picked.path).length();
      if (!mounted) return;
      setState(() {
        _pickedPath = picked.path;
        _originalBytes = size;
        _resultBytes = null;
        _resultSize = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).processFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _compress() async {
    final l = AppLocalizations.of(context);
    final path = _pickedPath;
    if (path == null || _busy) return;
    final target = double.tryParse(_targetController.text.trim());
    if (target == null || !target.isFinite || target < 5 || target > 2048) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.kbToolInvalidKb)));
      return;
    }
    setState(() {
      _busy = true;
      _resultBytes = null;
      _resultSize = null;
    });
    try {
      final result = await compute(
          compressPhotoWorker, (path: path, maxKb: target.floor()));
      if (!mounted) return;
      setState(() {
        _resultBytes = result.bytes;
        _resultSize = (result.width, result.height);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e is StateError ? l.kbLimitUnreachable : l.kbToolFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final bytes = _resultBytes;
    final path = _pickedPath;
    if (bytes == null || path == null || _busy) return;
    setState(() => _busy = true);
    try {
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw Exception(l.galleryPermissionDenied);
      final dir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(path);
      final tmp = File(p.join(dir.path, 'kb_tool_$baseName.jpg'));
      try {
        await tmp.writeAsBytes(bytes, flush: true);
        await Gal.putImage(tmp.path);
      } finally {
        if (await tmp.exists()) await tmp.delete();
      }
      // 双写 App 相册，保留压缩产物
      try {
        await AlbumService.save(bytes, baseName);
      } catch (e) {
        debugPrint('AlbumService.save failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.kbToolSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.kbToolFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final picked = _pickedPath;
    final result = _resultBytes;
    final size = _resultSize;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(l.kbToolTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (picked == null)
                FilledButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l.kbToolPick,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                )
              else ...[
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(picked),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Center(
                                  child: Icon(Icons.broken_image_outlined)),
                            )),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${((_originalBytes ?? 0) / 1024).toStringAsFixed(0)}KB',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  enabled: !_busy,
                  controller: _targetController,
                  onChanged: (_) => setState(() {
                    _resultBytes = null;
                    _resultSize = null;
                  }),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l.kbToolTargetKb,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _compress,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.compress),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l.kbToolCompress,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              if (picked != null)
                TextButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l.kbToolPick),
                ),
              if (result != null && size != null) ...[
                const SizedBox(height: 24),
                Text(
                  l.kbToolResult(
                    (result.lengthInBytes / 1024).toStringAsFixed(0),
                    '${size.$1}',
                    '${size.$2}',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(result, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_alt),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l.kbToolSave,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
