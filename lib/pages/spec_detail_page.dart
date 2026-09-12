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

/// 规格详情页：三栏参数卡 + 底色选择（默认推荐）+ 要求清单，底部上传/拍摄双按钮。
class SpecDetailPage extends StatefulWidget {
  const SpecDetailPage({super.key, required this.spec});

  final PhotoSpec spec;

  @override
  State<SpecDetailPage> createState() => _SpecDetailPageState();
}

class _SpecDetailPageState extends State<SpecDetailPage> {
  late PhotoSpec _spec = widget.spec;

  Future<void> _upload(BuildContext context) async {
    // imageQuality<100 才触发 image_picker 转码（Android quality=100 按字节
    // 拷贝原文件，HEIC 会原样漏入）；99 强制转 JPG 且质量损失可忽略
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 99);
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditPage(sourcePath: picked.path, spec: _spec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final tr = Tr.of(context);
    final requirements = tr.requirements(spec);
    return Scaffold(
      appBar: AppBar(
          title: Text(tr.specName(spec), overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 冲印尺寸按 300 DPI 换算（px ÷ 300 × 25.4mm）
                    _paramColumn(context, l.specPrintSize,
                        '${(spec.pixelWidth / 300 * 25.4).round()}×${(spec.pixelHeight / 300 * 25.4).round()}mm'),
                    _paramColumn(context, l.specPixelSize,
                        '${spec.pixelWidth}×${spec.pixelHeight}px'),
                    _paramColumn(context, l.specDpi, '300 DPI'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 背景色行：色块直选（右侧）
                    Row(
                      children: [
                        Text(l.specBgColor, style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        for (final bg in idPhotoBackgrounds)
                          _bgSwatch(spec, bg),
                      ],
                    ),
                    const Divider(height: 24),
                    // 文件大小行：可设置大小
                    Row(
                      children: [
                        Text(l.specFileSize, style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _editKbRange,
                          icon: const Icon(Icons.edit, size: 14),
                          label: Text(l.specKbEditable,
                              style: theme.textTheme.bodySmall),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          spec.minFileKb == 0
                              ? l.specNoLimit
                              : l.specKbRange(
                                  '${spec.minFileKb}', '${spec.maxFileKb}'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // 文件格式行
                    Row(
                      children: [
                        Text(l.specFileFormat,
                            style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        Text('JPG', style: theme.textTheme.bodyMedium),
                      ],
                    ),
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
                    child: Text(l.specUpload,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    child: Text(l.specShoot,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );

  /// 背景色块（对标参考 app 行内色块直选）
  Widget _bgSwatch(PhotoSpec spec, SpecBackground bg) {
    final selected = bg.name == _spec.background.name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _spec = _spec.copyWith(background: bg)),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Color.fromARGB(255, bg.r, bg.g, bg.b),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check,
                  size: 14,
                  color: bg.r > 200 && bg.g > 200
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white)
              : null,
        ),
      ),
    );
  }

  /// 「可设置大小」对话框：自定义 KB 区间（对标参考 app）
  Future<void> _editKbRange() async {
    final l = AppLocalizations.of(context);
    final minC = TextEditingController(
        text: _spec.minFileKb == 0 ? '' : '${_spec.minFileKb}');
    final maxC = TextEditingController(
        text: _spec.maxFileKb == 0 ? '' : '${_spec.maxFileKb}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l.specKbDialogTitle),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.customMinKb),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: maxC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.customMaxKb),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final minKb = int.tryParse(minC.text.trim()) ?? 0;
    final maxKb = int.tryParse(maxC.text.trim()) ?? 0;
    // min 不可达钳制：像素总量决定 JPEG 质量 100 的上限，min 过高会让
    // 编码器永远达不到下限，合规检测报无法修复的 fileTooSmall
    final estMaxKb = _spec.pixelWidth * _spec.pixelHeight ~/ 400;
    if (minKb < 0 ||
        maxKb < 0 ||
        (minKb > 0 && maxKb > 0 && minKb > maxKb) ||
        minKb > estMaxKb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(minKb > estMaxKb
              ? l.specKbUnreachable('${estMaxKb.clamp(1, 9999)}')
              : l.customInvalid)));
      return;
    }
    setState(() => _spec = _spec.copyWith(minFileKb: minKb, maxFileKb: maxKb));
  }
}
