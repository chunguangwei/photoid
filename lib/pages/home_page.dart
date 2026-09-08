import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import 'camera_page.dart';
import 'edit_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pickFromGallery(BuildContext context) async {
    // imageQuality 触发 image_picker 转码输出 JPG，规避 HEIC 解码问题
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EditPage(sourcePath: picked.path, spec: studentPhotoSpec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final tr = Tr.of(context);
    const spec = studentPhotoSpec;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.privacyNote)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.specName(spec), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('${spec.pixelWidth}×${spec.pixelHeight}px'),
                        _chip(tr.bgName(spec.background)),
                        _chip('${spec.minFileKb}–${spec.maxFileKb}KB'),
                        _chip('JPG'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(l.requirementsTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    ...tr.requirements(spec).map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(child: Text(r)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CameraPage(spec: studentPhotoSpec),
              )),
              icon: const Icon(Icons.photo_camera),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(l.takePhoto, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickFromGallery(context),
              icon: const Icon(Icons.photo_library_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(l.pickFromGallery, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) => Chip(
        label: Text(text),
        visualDensity: VisualDensity.compact,
      );
}
