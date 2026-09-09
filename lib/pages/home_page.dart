import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/spec_library.dart';
import 'settings_page.dart';
import 'custom_spec_page.dart';
import 'edit_page.dart';
import 'kb_tool_page.dart';
import 'my_album_page.dart';
import 'spec_detail_page.dart';

/// 首页：搜索 + 常用工具行 + 热门/全部规格流（学生报名照置顶并入规格流）。
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.settingsTitle,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsPage(),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<PhotoSpec>>(
          future: SpecLibrary.search(_query),
          builder: (context, snapshot) {
            // 学生报名照置顶进入规格流（不单设英雄卡）
            final specs = [
              studentPhotoSpec,
              ...?snapshot.data?.where((s) => s.id != studentPhotoSpec.id),
            ];
            final searching = _query.trim().isNotEmpty;
            return ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
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
                const SizedBox(height: 12),
                _toolsRow(context, l),
                const SizedBox(height: 16),
                if (!searching) ...[
                  _sectionHeader(context, l.homeHotSpecs, key: _specsKey),
                  ..._hotSpecs(specs).map((s) => _specTile(context, s)),
                  _allSpecsExpansion(context, l, specs),
                ] else
                  ...specs.map((s) => _specTile(context, s)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 区块 ─────────────────────────────────────────────────────────


  /// 常用工具：紧凑单行四入口，弱化视觉层级（对比原 2×2 大卡宫格）。
  Widget _toolsRow(BuildContext context, AppLocalizations l) {
    final items = <(IconData, String, VoidCallback)>[
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
      (
        Icons.tune,
        l.homeCustomSpec,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CustomSpecPage(),
            )),
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final (icon, label, onTap) in items)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 全部规格：默认折叠，避免一屏铺 33 条选项。
  Widget _allSpecsExpansion(
          BuildContext context, AppLocalizations l, List<PhotoSpec> specs) =>
      Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(top: 8),
        child: ExpansionTile(
          title: Text('${l.homeAllSpecs} (${specs.length})'),
          children:
              specs.map((s) => _specTile(context, s)).toList(),
        ),
      );

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
}
