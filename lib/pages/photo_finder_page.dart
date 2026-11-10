import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/application_task.dart';
import '../models/photo_spec.dart';
import '../services/application_task_store.dart';
import '../services/embedding_model_store.dart';
import '../services/embedding_session.dart';
import '../services/photo_finder_models.dart';
import '../services/photo_finder_session.dart';
import 'embedding_model_page.dart';
import '../widgets/photo_input.dart';
import 'photo_spec_picker_page.dart';
import 'edit_page.dart';

enum PhotoFinderResult { used, manual }

/// Choose one size, select a batch, tap a photo to prepare.
/// Existing task callers retain their saved requirements and replacement guard.
class PhotoFinderPage extends StatefulWidget {
  const PhotoFinderPage({super.key, this.taskId, this.store, this.gateway, this.embeddingStore});
  final String? taskId;
  final ApplicationTaskStore? store;
  final FinderGateway? gateway;
  final EmbeddingModelStore? embeddingStore;
  @override
  State<PhotoFinderPage> createState() => _PhotoFinderPageState();
}

class _PhotoFinderPageState extends State<PhotoFinderPage>
    with WidgetsBindingObserver {
  ApplicationTaskStore? _store;
  ApplicationTask? _task;
  PhotoFinderSession? _session;
  Completer<void>? _resumed;
  bool _sourcesExpanded = true, _processing = false, _selectingSize = false;
  bool _foreground = true,
      _recursive = false,
      _using = false,
      _preparing = false,
      _invalid = false,
      _showAll = false,
      _searching = false;
  String? _error;
  String _query = '';
  // 加强版（语义排序）：仅对当前批次缩略图本机嵌入，结果只影响排序。
  bool _enhancedOn = false, _ranking = false;
  String _semanticQuery = '';
  final Map<String, double> _scores = {};
  int _rankTotal = 0;
  final ValueNotifier<int> _rankDone = ValueNotifier<int>(0);
  bool _rankCancel = false;
  EmbeddingSession? _embed;
  EmbeddingModelStatus _modelStatus = EmbeddingModelStatus.notInstalled;
  bool get _draft => widget.taskId == null;
  PhotoSpec? get _spec =>
      _task?.outputs.isNotEmpty == true ? _task!.outputs.first.spec : null;
  bool get _busy =>
      _using ||
      _selectingSize ||
      _preparing ||
      _session?.running == true ||
      _session?.choosing == true;
  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final store = widget.store ?? await ApplicationTaskStore.open();
      final task = _draft
          ? ApplicationTask(id: 'draft', name: '', updatedAt: DateTime.now())
          : await store.get(widget.taskId!);
      if (!mounted) return;
      setState(() {
        _store = store;
        _task = task;
        _session = PhotoFinderSession(task.outputs,
            gateway: widget.gateway, waitUntilForeground: _waitForForeground)
          ..addListener(_refresh);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'access');
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _checkModel() async {
    try {
      final store = widget.embeddingStore ?? await EmbeddingModelStore.open();
      if (mounted) setState(() => _modelStatus = store.status);
    } catch (_) {
      if (mounted) setState(() => _modelStatus = EmbeddingModelStatus.corrupt);
    }
  }

  /// 首次开启加强版：未装模型先弹下载确认；就绪才打开。
  Future<void> _toggleEnhanced() async {
    if (_enhancedOn) {
      setState(() {
        _enhancedOn = false;
        _rankCancel = true;
        _scores.clear();
        // 关闭即释放模型会话（隐私承诺：不常驻）；再开启时 _ensureSession 重建。
        final e = _embed;
        _embed = null;
        unawaited(e?.dispose());
      });
      return;
    }
    await _checkModel();
    if (_modelStatus != EmbeddingModelStatus.ready) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final go = await showAdaptiveDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog.adaptive(
                  title: Text(l.enhancedEnableTitle),
                  content: Text(l.enhancedEnableBody),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.dialogCancel)),
                    FilledButton(
                        key: const Key('enhanced-download'),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.modelDownload))
                  ])) ??
          false;
      if (!go) return;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => EmbeddingModelPage(store: widget.embeddingStore)));
      if (!mounted) return;
      await _checkModel();
      if (_modelStatus != EmbeddingModelStatus.ready) return;
    }
    setState(() => _enhancedOn = true);
  }

  Future<EmbeddingSession> _ensureSession() async {
    if (_embed != null) return _embed!;
    final store = widget.embeddingStore ?? await EmbeddingModelStore.open();
    return _embed = await EmbeddingSession.open(store.directoryPath);
  }

  Future<void> _rank() async {
    final l = AppLocalizations.of(context);
    if (_ranking || _semanticQuery.trim().isEmpty) return;
    setState(() {
      _ranking = true;
      _rankCancel = false;
      _scores.clear();
      _rankTotal = 0;
      _rankDone.value = 0;
    });
    try {
      final session = await _ensureSession();
      final all = _session?.candidates ?? const <FinderCandidate>[];
      final targets =
          all.where((c) => c.analysis.thumbnailPath.isNotEmpty).toList();
      setState(() => _rankTotal = targets.length);
      final query = await session
          .embedText(EmbeddingSession.queryText(_semanticQuery.trim()));
      for (final c in targets) {
        if (_rankCancel || !mounted) break;
        try {
          final v = await session.embedImageBytes(
              await File(c.analysis.thumbnailPath).readAsBytes());
          var dot = 0.0;
          for (var i = 0; i < 768; i++) {
            dot += query[i] * v[i];
          }
          _scores[c.analysis.id] = dot;
        } catch (_) {/* 不可解码的缩略图留在原位，不参与语义排序 */}
        // 逐张只刷新进度行，不重建整个结果列表。
        _rankDone.value++;
      }
      if (mounted) setState(() {}); // 排序完成后整体重排一次
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.enhancedModelMissing)));
        setState(() => _enhancedOn = false);
      }
    } finally {
      if (mounted) setState(() => _ranking = false);
    }
  }

  Future<void> _waitForForeground() {
    if (_foreground || !mounted) return Future<void>.value();
    return (_resumed ??= Completer<void>()).future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resumed?.complete();
      _resumed = null;
    } else if (_session?.running == true) {
      _session!.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumed?.complete();
    _session?.removeListener(_refresh);
    _session?.dispose();
    _embed?.dispose();
    _rankDone.dispose();
    super.dispose();
  }

  Future<void> _pickSpec() async {
    if (_busy || _task == null || (!_draft && _task!.outputs.isNotEmpty)) {
      return;
    }
    setState(() => _selectingSize = true);
    try {
      final spec = await Navigator.push<PhotoSpec>(
          context,
          MaterialPageRoute(
              builder: (_) => PhotoSpecPickerPage(initialSpec: _spec)));
      if (spec == null || !mounted) return;
      try {
        final task = _draft
            ? ApplicationTask(
                id: 'draft',
                name: spec.name,
                updatedAt: DateTime.now(),
                outputs: [
                    ApplicationOutput(
                        id: 'draft', spec: spec, fileName: 'photo')
                  ])
            : await _store!.addOutput(widget.taskId!, spec, 'photo');
        if (!mounted) return;
        _session!.updateOutputs(task.outputs);
        setState(() {
          _task = task;
          _invalid = false;
          _error = null;
        });
      } catch (_) {
        if (mounted) setState(() => _error = 'access');
      }
    } finally {
      if (mounted) setState(() => _selectingSize = false);
    }
  }

  Future<void> _open(String method) async {
    if (_spec == null || _busy) return;
    setState(() {
      _preparing = true;
      _error = null;
      _query = '';
      _showAll = false;
    });
    try {
      await _session!.open(method,
          recursive: _recursive,
          languageCode: Localizations.localeOf(context).languageCode);
    } catch (_) {
      if (mounted) setState(() => _error = 'access');
    } finally {
      if (mounted) {
        setState(() {
          _preparing = false;
          if (_session!.candidates.isNotEmpty) _sourcesExpanded = false;
        });
      }
    }
  }

  Future<void> _manual() async {
    if (_using) return;
    _session?.stop();
    if (!_draft) {
      Navigator.pop(context, PhotoFinderResult.manual);
      return;
    }
    if (_spec == null) {
      await _pickSpec();
      if (!mounted || _spec == null) return;
    }
    final photo = await choosePhotoInput(context, allowCamera: true);
    if (photo == null || !mounted) return;
    setState(() {
      _using = true;
      _processing = true;
    });
    try {
      await _saveAndEdit(await readBoundedPhoto(photo));
    } catch (e) {
      if (mounted) showPhotoActionError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _using = false;
          _processing = false;
        });
      }
    }
  }

  Future<void> _saveAndEdit(List<int> source) async {
    final spec = _spec!;
    final task = await _store!.createFromSelection(
        name: Tr.of(context).specName(spec),
        source: source is Uint8List ? source : Uint8List.fromList(source),
        spec: spec);
    if (!mounted) return;
    setState(() {
      _using = false;
      _processing = false;
    });
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditPage(
                sourcePath: _store!.sourceFile(task).path,
                spec: spec,
                fixedRequirements: true,
                onDelivered: (bytes, deliveredSpec) async {
                  await _store!.saveOutput(
                      task.id, task.outputs.single.id, bytes, deliveredSpec,
                      expectedRevision: task.tokenFor(task.outputs.single));
                })));
  }

  Future<void> _use(FinderCandidate c) async {
    if (_using || c.analysis.skip != null || _spec == null) return;
    _session!.stop();
    setState(() {
      _using = true;
      _error = null;
    });
    try {
      final token = sourceSelectionToken(_task!);
      if (!_draft) {
        final current = await _store!.get(widget.taskId!);
        if (sourceSelectionToken(current) != token) {
          if (mounted) setState(() => _invalid = true);
          return;
        }
        if (!mounted) return;
        if (current.hasSource) {
          final l = AppLocalizations.of(context);
          final confirm = await showAdaptiveDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog.adaptive(
                      title: Text(l.taskReplaceSource),
                      content: Text(l.taskReplaceWarning),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l.dialogCancel)),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.confirm))
                      ]));
          if (confirm != true || !mounted) return;
        }
      }
      if (mounted) setState(() => _processing = true);
      final path = await _session!.materialize(c);
      final bytes = await readBoundedPhoto(XFile(path));
      if (!mounted) return;
      if (_draft) {
        await _saveAndEdit(bytes);
      } else {
        await _store!
            .setSource(widget.taskId!, bytes, expectedSelectionToken: token);
        if (mounted) {
          setState(() {
            _using = false;
            _processing = false;
          });
          Navigator.pop(context, PhotoFinderResult.used);
        }
      }
    } on StateError {
      if (mounted) setState(() => _invalid = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'changed');
    } finally {
      if (mounted) {
        setState(() {
          _using = false;
          _processing = false;
        });
      }
    }
  }

  String _reason(String code, AppLocalizations l) => switch (code) {
        'singleFrontal' => l.finderSingle,
        'multipleFaces' => l.finderMultiple,
        'poseUnknown' => l.finderPoseUnknown,
        'turnedFace' => l.finderTurned,
        'smallFace' => l.finderSmallFace,
        'qualityUnknown' => l.finderQualityUnknown,
        'softImage' => l.finderSoft,
        'exposure' => l.finderExposure,
        'cropPixels' => l.finderPixels,
        'cropFraming' => l.finderCropFraming,
        'noFaceDetected' => l.finderNoFace,
        'unsupported' => l.finderUnsupported,
        'oversized' => l.finderOversized,
        'remote' => l.finderRemote,
        'cacheLimit' => l.finderCacheLimit,
        _ => l.finderUnreadable
      };
  Future<void> _preview(FinderCandidate c) async {
    if (_using) return;
    final l = AppLocalizations.of(context), a = c.analysis;
    final use = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (ctx) => ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(a.name,
                          style: Theme.of(ctx).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      if (a.thumbnailPath.isNotEmpty)
                        SizedBox(
                            height: 270,
                            child: InteractiveViewer(
                                child: Image.file(File(a.thumbnailPath),
                                    cacheWidth: 900,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined)))),
                      const SizedBox(height: 12),
                      Text(c.reasons.isEmpty
                          ? l.finderShortCaution
                          : _reason(c.reasons.first, l)),
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(l.finderDetails),
                          children: [
                            Text(a.relativePath),
                            Text('${a.width} × ${a.height} px'),
                            for (final r in c.reasons.skip(1))
                              Text(_reason(r, l)),
                            for (final crop in c.crops)
                              Text(
                                  '${crop.outputName}: ${crop.pixelWidth} × ${crop.pixelHeight} px'),
                            Text(l.finderCropNote,
                                style: Theme.of(ctx).textTheme.bodySmall),
                          ]),
                      const SizedBox(height: 12),
                      FilledButton(
                          key: const Key('finder-use'),
                          onPressed: a.skip != null || _invalid
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: Text(l.finderPrepare)),
                    ]))));
    if (use == true && mounted) await _use(c);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tr = Tr.of(context), s = _session;
    final all = s?.candidates ?? <FinderCandidate>[];
    final recommended =
        all.where((c) => c.group == FinderGroup.priority).toList();
    final effectiveAll = _showAll || recommended.isEmpty;
    final visible = (effectiveAll ? all : recommended)
        .where((c) => '${c.analysis.name} ${c.analysis.relativePath}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    if (_enhancedOn && _scores.isNotEmpty) {
      // Dart sort 不稳定：并列分数（含未评分的 -2 组）按原始次序 tie-break。
      final order = {
        for (var i = 0; i < visible.length; i++) visible[i].analysis.id: i
      };
      visible.sort((a, b) {
        final c = (_scores[b.analysis.id] ?? -2)
            .compareTo(_scores[a.analysis.id] ?? -2);
        return c != 0
            ? c
            : order[a.analysis.id]!.compareTo(order[b.analysis.id]!);
      });
    }
    final ready = _spec != null && !_busy;
    return PopScope(
        canPop: !_using,
        child: Scaffold(
            appBar: AppBar(title: Text(l.finderTitle)),
            body: SafeArea(
                top: false,
                child:
                    CustomScrollView(key: const Key('finder-scroll'), slivers: [
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverToBoxAdapter(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            Text(l.finderSimpleIntro,
                                style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 16),
                            Card(
                                child: ListTile(
                                    key: const Key('finder-size'),
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: const Icon(
                                        Icons.photo_size_select_large_outlined),
                                    title: Text(_spec == null
                                        ? l.finderChooseTarget
                                        : tr.specName(_spec!)),
                                    subtitle: _spec == null
                                        ? Text(l.finderChooseSizeFirst)
                                        : Text(
                                            '${_spec!.pixelWidth} × ${_spec!.pixelHeight} px · ${_spec!.minFileKb}–${_spec!.maxFileKb == 0 ? "∞" : _spec!.maxFileKb} KB${_task!.outputs.length > 1 ? " + ${_task!.outputs.length - 1}" : ""}'),
                                    trailing:
                                        _draft || _task?.outputs.isEmpty == true
                                            ? const Icon(Icons.chevron_right)
                                            : null,
                                    onTap: _busy ? null : _pickSpec)),
                            const SizedBox(height: 16),
                            if (_sourcesExpanded || all.isEmpty) ...[
                              FilledButton.icon(
                                  key: const Key('finder-photos'),
                                  onPressed: ready
                                      ? () => _open('choosePhotos')
                                      : null,
                                  icon:
                                      const Icon(Icons.photo_library_outlined),
                                  label: Text(l.finderBatchPhotos)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                  key: const Key('finder-folder'),
                                  onPressed: ready
                                      ? () => _open('chooseDirectory')
                                      : null,
                                  icon: const Icon(Icons.folder_open_outlined),
                                  label: Text(l.finderFolder)),
                            ],
                            if (!_sourcesExpanded && all.isNotEmpty)
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _sourcesExpanded = true),
                                  child: Text(
                                      '${l.finderChangePhotos} (${s!.total})')),
                            TextButton.icon(
                                key: const Key('finder-manual'),
                                onPressed: _using ? null : _manual,
                                icon: const Icon(
                                    Icons.add_photo_alternate_outlined),
                                label: Text(l.finderManual)),
                            Text(l.finderShortPrivacy,
                                style: Theme.of(context).textTheme.bodySmall),
                            if (_sourcesExpanded || all.isEmpty)
                              ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(l.finderAdvanced,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  children: [
                                    CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(l.finderRecursive),
                                        value: _recursive,
                                        onChanged: _busy
                                            ? null
                                            : (v) => setState(
                                                () => _recursive = v ?? false)),
                                    OutlinedButton.icon(
                                        key: const Key('finder-files'),
                                        onPressed: ready
                                            ? () => _open('chooseFiles')
                                            : null,
                                        icon: const Icon(
                                            Icons.insert_drive_file_outlined),
                                        label: Text(l.finderFiles)),
                                    Text(l.finderSourceHint),
                                    const SizedBox(height: 8),
                                    Text(Platform.isAndroid
                                        ? l.finderProvider
                                        : l.finderProviderIos),
                                    const SizedBox(height: 8),
                                    Text(l.finderLimits),
                                  ]),
                            if (_processing ||
                                _preparing ||
                                s?.running == true ||
                                s?.choosing == true) ...[
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                  value: s?.running == true && s!.total > 0
                                      ? s.processed / s.total
                                      : null),
                              const SizedBox(height: 8),
                              Text(_processing
                                  ? l.finderPreparingSource
                                  : '${l.finderAnalyzing} ${s?.processed ?? 0}/${s?.total ?? 0}'),
                              if (s?.running == true)
                                TextButton(
                                    onPressed: s!.stop,
                                    child: Text(l.finderStop))
                            ],
                            if (s?.partial == true)
                              Text(l.finderPartial,
                                  style: Theme.of(context).textTheme.bodySmall),
                            if (_invalid) Text(l.finderStale),
                            if (_error != null || s?.error != null)
                              Text(_error == 'changed'
                                  ? l.finderChanged
                                  : l.finderFailed),
                            if (all.isEmpty && !_busy)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(s?.hasSelection == true
                                      ? l.finderNoPhotos
                                      : l.finderStartHint)),
                            if (all.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ChoiceChip(
                                        label: Text(
                                            '${l.finderRecommend} (${recommended.length})'),
                                        selected: !effectiveAll,
                                        onSelected: recommended.isEmpty
                                            ? null
                                            : (_) => setState(
                                                () => _showAll = false)),
                                    ChoiceChip(
                                        label: Text(
                                            '${l.finderAllPhotos} (${all.length})'),
                                        selected: effectiveAll,
                                        onSelected: (_) =>
                                            setState(() => _showAll = true)),
                                    IconButton(
                                        tooltip: l.finderSearch,
                                        onPressed: () => setState(
                                            () => _searching = !_searching),
                                        icon: const Icon(Icons.search)),
                                    ChoiceChip(
                                        key: const Key('enhanced-toggle'),
                                        avatar: const Icon(
                                            Icons.auto_awesome_outlined,
                                            size: 18),
                                        label: Text(l.enhancedTitle),
                                        selected: _enhancedOn,
                                        onSelected:
                                            _busy ? null : (_) => _toggleEnhanced()),
                                  ]),
                              if (_enhancedOn) ...[
                                Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(l.enhancedDisclaimer,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall)),
                                TextField(
                                    key: const Key('enhanced-input'),
                                    decoration: InputDecoration(
                                        hintText: l.enhancedSearchHint,
                                        suffixIcon: IconButton(
                                            onPressed:
                                                _ranking ? null : _rank,
                                            icon: const Icon(
                                                Icons.arrow_forward))),
                                    onChanged: (v) =>
                                        setState(() => _semanticQuery = v),
                                    onSubmitted: (_) => _rank()),
                                if (_ranking)
                                  ValueListenableBuilder<int>(
                                      valueListenable: _rankDone,
                                      builder: (ctx, done, _) => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child:
                                                      LinearProgressIndicator(
                                                          value: _rankTotal == 0
                                                              ? null
                                                              : done /
                                                                  _rankTotal)),
                                              const SizedBox(width: 8),
                                              TextButton(
                                                  onPressed: () =>
                                                      _rankCancel = true,
                                                  child: Text(l.enhancedStop)),
                                            ]),
                                            Text(l.enhancedSorting(done, _rankTotal),
                                                style:
                                                    Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                          ])),
                              ],
                              if (_searching)
                                TextField(
                                    decoration: InputDecoration(
                                        labelText: l.finderSearch),
                                    onChanged: (v) =>
                                        setState(() => _query = v)),
                              if (recommended.isEmpty && !_busy)
                                Text(l.finderNoRecommended,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              if (!_busy)
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                        onPressed: () async {
                                          try {
                                            await s!.clear();
                                          } catch (_) {
                                            if (mounted) {
                                              setState(() => _error = 'access');
                                            }
                                          }
                                        },
                                        child: Text(l.finderClear))),
                            ],
                          ]))),
                  SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      MediaQuery.sizeOf(context).width >= 600
                                          ? 3
                                          : 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 230),
                          itemCount: visible.length,
                          itemBuilder: (ctx, index) {
                            final c = visible[index], a = c.analysis;
                            return Card(
                                key: ValueKey('finder-result-${a.name}'),
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                    onTap: _using ? null : () => _preview(c),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                              child: a.thumbnailPath.isEmpty
                                                  ? const Icon(Icons
                                                      .image_not_supported_outlined)
                                                  : Image.file(
                                                      File(a.thumbnailPath),
                                                      cacheWidth: 360,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          const Icon(Icons
                                                              .broken_image_outlined))),
                                          Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      10, 8, 10, 2),
                                              child: Text(a.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .labelLarge)),
                                          Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      10, 0, 10, 10),
                                              child: Text(
                                                  c.group ==
                                                          FinderGroup.priority
                                                      ? l.finderRecommend
                                                      : c.group ==
                                                              FinderGroup.pixels
                                                          ? l.finderPixels
                                                          : l.finderManualGroup,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .bodySmall)),
                                        ])));
                          })),
                  SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                          child: Text(l.finderShortCaution,
                              style: Theme.of(context).textTheme.bodySmall))),
                ]))));
  }
}
