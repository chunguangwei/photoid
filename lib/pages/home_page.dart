import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/spec_library.dart';
import 'camera_page.dart';
import 'custom_spec_page.dart';
import 'edit_page.dart';
import 'kb_tool_page.dart';
import 'my_album_page.dart';
import 'spec_detail_page.dart';

/// 首页：隐私提示 + 功能宫格 + 搜索 + 学生照样例卡 + 热门/全部规格流。
///
/// 自身保持 StatelessWidget；带状态的交互部分在 [_HomeView] 中。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const _HomeView();
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _specsKey = GlobalKey();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// 热门区固定锚定的规格 id 关键字。
  static const _hotIdKeys = [
    'one_inch',
    'two_inch',
    'cet_english',
    'gaokao',
    'student',
  ];

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scrollToSpecs() {
    final ctx = _specsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _pickFromGallery(
      BuildContext context, PhotoSpec spec) async {
    // imageQuality 触发 image_picker 转码输出 JPG，规避 HEIC 解码问题
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditPage(sourcePath: picked.path, spec: spec),
    ));
  }

  /// 热门区：id 命中锚点关键字的前 5 条；无匹配则取列表前 5。
  List<PhotoSpec> _hotSpecs(List<PhotoSpec> all) {
    final matched = all
        .where((s) => _hotIdKeys.any((k) => s.id.contains(k)))
        .take(5)
        .toList();
    return matched.isNotEmpty ? matched : all.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: SafeArea(
        child: FutureBuilder<List<PhotoSpec>>(
          future: SpecLibrary.search(_query),
          builder: (context, snapshot) {
            final specs = snapshot.data ?? const <PhotoSpec>[];
            final searching = _query.trim().isNotEmpty;
            return ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                _privacyCard(theme, l),
                const SizedBox(height: 16),
                _featureGrid(context, l),
                const SizedBox(height: 8),
                _customSpecEntry(context, l),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.homeSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _studentCard(context, theme, l),
                if (!searching) ...[
                  const SizedBox(height: 16),
                  _sectionHeader(context, l.homeHotSpecs, key: _specsKey),
                  ..._hotSpecs(specs).map((s) => _specTile(context, s)),
                ],
                const SizedBox(height: 16),
                _sectionHeader(context, l.homeAllSpecs),
                ...specs.map((s) => _specTile(context, s)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 区块 ─────────────────────────────────────────────────────────

  Widget _privacyCard(ThemeData theme, AppLocalizations l) => Card(
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
      );

  Widget _featureGrid(BuildContext context, AppLocalizations l) {
    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.photo_camera,
        l.homeTakePhoto,
        _scrollToSpecs,
      ),
      (
        Icons.palette_outlined,
        l.homeChangeBg,
        () => _pickFromGallery(context, studentPhotoSpec),
      ),
      (
        Icons.compress,
        l.homeChangeKb,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const KbToolPage(),
            )),
      ),
      (
        Icons.photo_library_outlined,
        l.homeMyAlbum,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MyAlbumPage(),
            )),
      ),
    ];
    return Row(
      children: [
        for (final (icon, label, onTap) in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Icon(icon),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _customSpecEntry(BuildContext context, AppLocalizations l) => Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.tune),
          title: Text(l.homeCustomSpec),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CustomSpecPage(),
          )),
        ),
      );

  /// 学生照样例卡：置顶列表项 + 拍摄/相册两个快捷入口。
  Widget _studentCard(
      BuildContext context, ThemeData theme, AppLocalizations l) {
    const spec = studentPhotoSpec;
    final tr = Tr.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SpecDetailPage(spec: spec),
              )),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(tr.specName(spec), style: theme.textTheme.titleLarge),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
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
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CameraPage(spec: spec),
              )),
              icon: const Icon(Icons.photo_camera),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.takePhoto),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickFromGallery(context, spec),
              icon: const Icon(Icons.photo_library_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.pickFromGallery),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text, {Key? key}) =>
      Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child:
              Text(text, style: Theme.of(context).textTheme.titleSmall),
        ),
      );

  Widget _specTile(BuildContext context, PhotoSpec spec) {
    final tr = Tr.of(context);
    return ListTile(
      title: Text(tr.specName(spec)),
      subtitle: Text('${spec.pixelWidth}×${spec.pixelHeight}px'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SpecDetailPage(spec: spec),
      )),
    );
  }

  Widget _chip(String text) => Chip(
        label: Text(text),
        visualDensity: VisualDensity.compact,
      );
}
