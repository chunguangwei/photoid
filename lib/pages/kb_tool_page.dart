import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../services/album_service.dart';
import '../services/image_pipeline.dart';

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
  img.Image? _resultImage;
  bool _busy = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 99);
    if (picked == null || !mounted) return;
    final size = await File(picked.path).length();
    setState(() {
      _pickedPath = picked.path;
      _originalBytes = size;
      _resultBytes = null;
      _resultImage = null;
    });
  }

  Future<void> _compress() async {
    final l = AppLocalizations.of(context);
    final path = _pickedPath;
    if (path == null) return;
    final target = double.tryParse(_targetController.text.trim());
    if (target == null || target < 5 || target > 2048) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.kbToolInvalidKb)));
      return;
    }
    setState(() => _busy = true);
    try {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) throw Exception('decode failed');
      final oriented = img.bakeOrientation(decoded);
      final bytes = ImagePipeline.encodeToKbRange(oriented, 5, target.round());
      if (!mounted) return;
      setState(() {
        _resultBytes = bytes;
        _resultImage = oriented;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.kbToolFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final bytes = _resultBytes;
    final path = _pickedPath;
    if (bytes == null || path == null) return;
    setState(() => _busy = true);
    try {
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) throw Exception(l.galleryPermissionDenied);
      final dir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(path);
      final tmp = File(p.join(dir.path, 'kb_tool_$baseName.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      await Gal.putImage(tmp.path);
      tmp.delete().ignore();
      // 双写 App 相册，保留压缩产物
      await AlbumService.save(bytes, baseName);
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
    final image = _resultImage;
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
                  onPressed: _pick,
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
                  controller: _targetController,
                  keyboardType: TextInputType.number,
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
              if (result != null && image != null) ...[
                const SizedBox(height: 24),
                Text(
                  l.kbToolResult(
                    (result.lengthInBytes / 1024).toStringAsFixed(0),
                    '${image.width}',
                    '${image.height}',
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
