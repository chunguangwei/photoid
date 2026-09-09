import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import 'camera_page.dart';
import 'edit_page.dart';

/// 底色本地化名（经 backgroundL10nKeys 映射到 l10n 键，未知底色原样显示）。
String localizedBgName(BuildContext context, SpecBackground bg) {
  final l = AppLocalizations.of(context);
  switch (backgroundL10nKeys[bg.name]) {
    case 'bgBlue':
      return l.bgBlue;
    case 'bgWhite':
      return l.bgWhite;
    case 'bgRed':
      return l.bgRed;
    case 'bgGray':
      return l.bgGray;
    case 'bgDarkBlue':
      return l.bgDarkBlue;
    default:
      return bg.name;
  }
}

/// 规格详情页：三栏参数卡 + 底色 + 要求清单，底部上传/拍摄双按钮。
class SpecDetailPage extends StatelessWidget {
  const SpecDetailPage({super.key, required this.spec});

  final PhotoSpec spec;

  Future<void> _upload(BuildContext context) async {
    // imageQuality 触发 image_picker 转码输出 JPG，规避 HEIC 解码问题
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditPage(sourcePath: picked.path, spec: spec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final tr = Tr.of(context);
    final requirements = tr.requirements(spec);
    return Scaffold(
      appBar: AppBar(title: Text(tr.specName(spec))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _paramColumn(
                        context, l.specPixelSize, '${spec.pixelWidth}×${spec.pixelHeight}px'),
                    _paramColumn(context, l.specDpi, '300'),
                    _paramColumn(
                      context,
                      l.specFileSize,
                      spec.minFileKb == 0
                          ? l.specNoLimit
                          : l.specKbRange('${spec.minFileKb}', '${spec.maxFileKb}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text(l.specBgColor),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(
                            255, spec.background.r, spec.background.g, spec.background.b),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(localizedBgName(context, spec.background)),
                  ],
                ),
              ),
            ),
            if (requirements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.requirementsTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ...requirements.map((r) => Padding(
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _upload(context),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l.specUpload),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CameraPage(spec: spec),
                  )),
                  icon: const Icon(Icons.photo_camera),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l.specShoot),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paramColumn(BuildContext context, String label, String value) =>
      Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}
