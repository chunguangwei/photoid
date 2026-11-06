import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/photo_spec.dart';
import '../services/custom_spec_store.dart';
import '../services/application_task_store.dart';
import '../services/demo_task.dart';
import '../models/application_task.dart';
import 'application_task_page.dart';
import '../services/spec_library.dart';
import '../widgets/glass_surface.dart';
import '../widgets/photo_input.dart';
import 'custom_spec_page.dart';
import 'application_tasks_page.dart';
import 'photo_check_page.dart';
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
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          SettingsPage(showAlbumEntry: true),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GlassSurface(
            child: NavigationBar(
          height: 68,
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
        )),
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
  ApplicationTask? _recent;
  int _ongoing = 0;
  bool _demoBusy = false;
  Future<List<PhotoSpec>> _specsFuture = SpecLibrary.load();

  @override
  void initState() {
    super.initState();
    _loadCustomSpecs();
    _loadTasks();
  }

  Future<void> _loadCustomSpecs() async {
    final list = await CustomSpecStore.load();
    if (mounted) setState(() => _customSpecs = list);
  }

  Future<void> _loadTasks() async {
    try {
      final store = await ApplicationTaskStore.open();
      final tasks = await store.list();
      if (mounted) {
        setState(() {
          _recent = tasks.isEmpty ? null : tasks.first;
          _ongoing = tasks.where((t) => !t.complete).length;
        });
      }
    } catch (_) {
      /* Existing tools remain usable when local task storage is unavailable. */
    }
  }

  Future<void> _openTasks() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ApplicationTasksPage()));
    if (mounted) await _loadTasks();
  }

  Future<void> _demo() async {
    if (_demoBusy) return;
    final locale = AppLocalizations.of(context).localeName;
    setState(() => _demoBusy = true);
    try {
      final store = await ApplicationTaskStore.open();
      final task = await DemoTask.open(store, locale);
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ApplicationTaskPage(taskId: task.id, store: store)));
    } catch (e) {
      if (mounted) showPhotoActionError(context, e);
    } finally {
      if (mounted) {
        setState(() => _demoBusy = false);
        await _loadTasks();
      }
    }
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
        future: _specsFuture,
        builder: (context, snapshot) {
          final searching = _query.trim().isNotEmpty;
          // 学生报名照置顶进入规格流（搜索态按相关度排序，不强制置顶）
          final all = [
            studentPhotoSpec,
            ...?snapshot.data?.where((s) => s.id != studentPhotoSpec.id),
          ];
          final query = _query.trim().toLowerCase();
          final specs = searching
              ? all
                  .where((s) =>
                      s.name.toLowerCase().contains(query) ||
                      (s.nameEn?.toLowerCase().contains(query) ?? false) ||
                      Tr.of(context).specName(s).toLowerCase().contains(query))
                  .toList()
              : all;
          return ListView(
            padding: const EdgeInsets.only(bottom: 112),
            children: [
              _brandHeader(context, l),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _applicationEntries(context, l),
                    const SizedBox(height: 16),
                    _secondaryTools(context, l),
                    const SizedBox(height: 16),
                    _primaryGrid(context, l),
                    if (_customSpecs.isNotEmpty)
                      _customSpecsSection(context, l),
                    const SizedBox(height: 16),
                    if (snapshot.hasError) ...[
                      Text(l.loadFailed),
                      TextButton(
                        onPressed: () =>
                            setState(() => _specsFuture = SpecLibrary.load()),
                        child: Text(l.retry),
                      ),
                    ],
                    if (searching &&
                        specs.isEmpty &&
                        snapshot.connectionState == ConnectionState.done)
                      Text(l.homeNoResults),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.homeEyebrow,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Text(l.homeHeroTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.lock_outline,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
                child: Text(l.privacySlogan,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          ]),
        ],
      ),
    );
  }

  Widget _applicationEntries(BuildContext context, AppLocalizations l) =>
      Column(
        children: [
          Card(
              child: ListTile(
            key: const Key('home-tasks'),
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(Icons.folder_copy_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text(l.tasksTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child:
                    Text('${l.tasksDesc}\n$_ongoing ${l.workflowInProgress}')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openTasks,
          )),
          if (_recent != null)
            ListTile(
                title: Text(l.workflowRecent),
                subtitle: Text(_recent!.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ApplicationTaskPage(taskId: _recent!.id)));
                  if (mounted) await _loadTasks();
                }),
          OutlinedButton.icon(
              onPressed: _demoBusy ? null : _demo,
              icon: const Icon(Icons.play_circle_outline),
              label: Text(l.workflowDemo)),
          const SizedBox(height: 12),
          Card(
              child: ListTile(
            key: const Key('home-check'),
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(Icons.fact_check_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: Text(l.checkExistingTitle,
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l.checkExistingDesc)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PhotoCheckPage())),
          )),
        ],
      );

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
      childAspectRatio: 2,
      children: [
        for (final (icon, _, label, onTap) in items)
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        color: Theme.of(context).colorScheme.primary, size: 20),
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
    if (_query.isNotEmpty) {
      _searchCtrl.clear();
      setState(() => _query = '');
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToHot(context);
      });
      return;
    }
    Scrollable.ensureVisible(
      _hotHeaderKey.currentContext ?? context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  final GlobalKey _hotHeaderKey = GlobalKey();

  /// 次级小工具：自定义规格（保持精简，只放真实存在的功能）。
  Widget _secondaryTools(BuildContext context, AppLocalizations l) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CustomSpecPage(),
            ));
            _loadCustomSpecs();
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 52,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.tune,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(l.homeCustomSpec,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(l.homeCustomDesc,
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ]),
          ),
        ),
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

  Widget _hotHeader(AppLocalizations l) => Padding(
        key: _hotHeaderKey,
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
                child: Text(l.hotNow,
                    style: Theme.of(context).textTheme.titleMedium)),
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
