import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/custom_spec_store.dart';
import '../services/spec_library.dart';
import 'custom_spec_page.dart';
import 'edit_page.dart';
import 'kb_tool_page.dart';
import 'my_album_page.dart';
import 'settings_page.dart';
import 'spec_detail_page.dart';

/// 主页骨架：底部双 Tab（首页 / 我的）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          SettingsPage(showAlbumEntry: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l.tabMine,
          ),
        ],
      ),
    );
  }
}

/// 首页 Tab：品牌头 + 2×2 主功能大卡 + 次级工具 + 隐私横幅 + 热门规格流。
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  /// 已保存的自定义规格（首页展示，可删除）
  List<PhotoSpec> _customSpecs = [];

  @override
  void initState() {
    super.initState();
    _loadCustomSpecs();
  }

  Future<void> _loadCustomSpecs() async {
    final list = await CustomSpecStore.load();
    if (mounted) setState(() => _customSpecs = list);
  }

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// 热门区固定锚定的规格 id 关键字（学生报名照置顶）。
  static const _hotIdKeys = [
    'student',
    'one_inch',
    'two_inch',
    'cet_english',
    'gaokao',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery(BuildContext context, PhotoSpec spec) async {
    // imageQuality<100 才触发 image_picker 转码（Android quality=100 按字节
    // 拷贝原文件，HEIC 会原样漏入）；99 强制转 JPG 且质量损失可忽略
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 99);
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditPage(sourcePath: picked.path, spec: spec),
    ));
  }

  /// 热门区：id 命中锚点关键字的前 5 条；无匹配则取列表前 5。
  List<PhotoSpec> _hotSpecs(List<PhotoSpec> all) {
    // 按锚点顺序各取一条（学生照锚点在最前），避免被寸照变体挤占
    final result = <PhotoSpec>[];
    for (final k in _hotIdKeys) {
      final m = all.where((s) => s.id.contains(k));
      if (m.isNotEmpty && !result.any((r) => r.id == m.first.id)) {
        result.add(m.first);
      }
    }
    return result.isNotEmpty ? result : all.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: FutureBuilder<List<PhotoSpec>>(
        future: SpecLibrary.search(_query),
        builder: (context, snapshot) {
          final searching = _query.trim().isNotEmpty;
          // 学生报名照置顶进入规格流（搜索态按相关度排序，不强制置顶）
          final specs = searching
              ? (snapshot.data ?? const <PhotoSpec>[])
              : [
                  studentPhotoSpec,
                  ...?snapshot.data?.where((s) => s.id != studentPhotoSpec.id),
                ];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _brandHeader(context, l),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _primaryGrid(context, l),
                    const SizedBox(height: 8),
                    _secondaryTools(context, l),
                    if (_customSpecs.isNotEmpty)
                      _customSpecsSection(context, l),
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
                    if (!searching) ...[
                      _hotHeader(l),
                      ..._hotSpecs(specs).map((s) => _specCard(context, s)),
                      _allSpecsExpansion(context, l, specs),
                    ] else
                      ...specs.map((s) => _specCard(context, s)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 区块 ─────────────────────────────────────────────────────────

  /// 品牌头：渐变底 + App 名 + 隐私口号（对标参考图的蓝色横幅位）。
  Widget _brandHeader(BuildContext context, AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2B6CB0),
            const Color(0xFF2B6CB0).withValues(alpha: 0.75)
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.appTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(l.privacySlogan,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }

  /// 2×2 主功能大卡：拍证件照 / 换底色 / 改KB / 我的相册。
  Widget _primaryGrid(BuildContext context, AppLocalizations l) {
    final items = <(IconData, Color, String, VoidCallback)>[
      (
        Icons.photo_camera,
        const Color(0xFF3B82F6),
        l.homeTakePhoto,
        () => _scrollToHot(context),
      ),
      (
        Icons.palette_outlined,
        const Color(0xFFF97316),
        l.homeChangeBg,
        () => _pickFromGallery(context, studentPhotoSpec),
      ),
      (
        Icons.compress,
        const Color(0xFFEC4899),
        l.homeChangeKb,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const KbToolPage(),
            )),
      ),
      (
        Icons.photo_library_outlined,
        const Color(0xFF8B5CF6),
        l.homeMyAlbum,
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MyAlbumPage(),
            )),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (final (icon, color, label, onTap) in items)
          Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 拍证件照大卡：滚动到热门规格区（规格即拍摄入口）。
  void _scrollToHot(BuildContext context) {
    Scrollable.ensureVisible(
      _hotHeaderKey.currentContext ?? context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  final GlobalKey _hotHeaderKey = GlobalKey();

  /// 次级小工具：自定义规格（保持精简，只放真实存在的功能）。
  Widget _secondaryTools(BuildContext context, AppLocalizations l) => Row(
        children: [
          _smallTool(
            icon: Icons.tune,
            label: l.homeCustomSpec,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CustomSpecPage(),
              ));
              _loadCustomSpecs();
            },
          ),
        ],
      );

  /// 已保存自定义规格：点按进入详情，长按删除
  Widget _customSpecsSection(BuildContext context, AppLocalizations l) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.homeCustomSaved,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final spec in _customSpecs)
                  InputChip(
                    label: Text(
                        '${spec.name} ${spec.pixelWidth}×${spec.pixelHeight}'),
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SpecDetailPage(spec: spec),
                    )),
                    onDeleted: () => _confirmDeleteCustom(spec),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ],
        ),
      );

  Future<void> _confirmDeleteCustom(PhotoSpec spec) async {
    final l = AppLocalizations.of(context);
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(l.customDeleteTitle),
        content: Text(l.customDeleteConfirm(spec.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.customDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CustomSpecStore.delete(spec.id);
      _loadCustomSpecs();
    }
  }

  Widget _smallTool(
          {required IconData icon,
          required String label,
          required VoidCallback onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );

  Widget _hotHeader(AppLocalizations l) => Padding(
        key: _hotHeaderKey,
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(l.hotNow, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 6),
            Icon(Icons.local_fire_department,
                size: 18, color: Colors.orange.shade700),
          ],
        ),
      );

  /// 热门/全部规格卡片（对标参考图的留白卡片样式）。
  Widget _specCard(BuildContext context, PhotoSpec spec) {
    final tr = Tr.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(tr.specName(spec)),
        subtitle: Text('${spec.pixelWidth} × ${spec.pixelHeight} px'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SpecDetailPage(spec: spec),
        )),
      ),
    );
  }

  /// 全部规格：默认折叠。
  Widget _allSpecsExpansion(
          BuildContext context, AppLocalizations l, List<PhotoSpec> specs) =>
      Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: Text('${l.homeAllSpecs} (${specs.length})'),
          children: specs.map((s) => _specCard(context, s)).toList(),
        ),
      );
}
