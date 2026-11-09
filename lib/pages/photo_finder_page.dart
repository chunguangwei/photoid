import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/application_task.dart';
import '../services/application_task_store.dart';
import '../services/photo_finder_demo.dart';
import '../services/photo_finder_models.dart';
import '../services/photo_finder_session.dart';
import '../widgets/photo_input.dart';

enum PhotoFinderResult { used, manual }

class PhotoFinderPage extends StatefulWidget {
  const PhotoFinderPage(
      {super.key, required this.taskId, required this.store, this.gateway});
  final String taskId;
  final ApplicationTaskStore store;
  final FinderGateway? gateway;
  @override
  State<PhotoFinderPage> createState() => _PhotoFinderPageState();
}

class _PhotoFinderPageState extends State<PhotoFinderPage>
    with WidgetsBindingObserver {
  ApplicationTask? _task;
  bool _foreground = true;
  Completer<void>? _resumed;
  PhotoFinderSession? _session;
  Directory? _demoDirectory;
  String? _error;
  String _query = '';
  FinderGroup? _filter;
  bool _recursive = false, _using = false, _preparing = false, _invalid = false;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final task = await widget.store.get(widget.taskId);
      if (!mounted) return;
      setState(() {
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

  Future<void> _waitForForeground() {
    if (_foreground || !mounted) return Future<void>.value();
    return (_resumed ??= Completer<void>()).future;
  }

  // A platform picker may return before resumed; defer analysis until foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resumed?.complete();
      _resumed = null;
    }
    if (!_foreground && _session?.running == true) {
      _session!.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumed?.complete();
    _resumed = null;
    _session?.removeListener(_refresh);
    _session?.dispose();
    final demo = _demoDirectory;
    if (demo != null) {
      unawaited(demo.delete(recursive: true).catchError((_) => demo));
    }
    super.dispose();
  }

  Future<void> _open(String method) async {
    if (_task!.outputs.isEmpty || _using || _preparing) return;
    setState(() {
      _error = null;
      _preparing = true;
    });
    try {
      List<String>? paths;
      if (method == 'openDemo') {
        _demoDirectory ??= await Directory(
                '${(await getTemporaryDirectory()).path}/photoid_finder_demo')
            .create(recursive: true);
        paths = await writeFinderDemo(_demoDirectory!);
      }
      if (!mounted) return;
      await _session!.open(method, recursive: _recursive, demoPaths: paths);
    } catch (_) {
      if (mounted) setState(() => _error = 'access');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _use(FinderCandidate candidate) async {
    if (_using || candidate.analysis.skip != null) return;
    final token = sourceSelectionToken(_task!),
        l = AppLocalizations.of(context);
    setState(() {
      _using = true;
      _error = null;
    });
    _session!.stop();
    try {
      final current = await widget.store.get(widget.taskId);
      if (sourceSelectionToken(current) != token) {
        if (mounted) setState(() => _invalid = true);
        return;
      }
      if (!mounted) return;
      if (current.hasSource) {
        final confirmed = await showAdaptiveDialog<bool>(
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
        if (confirmed != true || !mounted) return;
      }
      final path = await _session!.materialize(candidate);
      final bytes = await readBoundedPhoto(XFile(path));
      if (!mounted) return;
      await widget.store
          .setSource(widget.taskId, bytes, expectedSelectionToken: token);
      if (mounted) {
        setState(() => _using = false);
        Navigator.pop(context, PhotoFinderResult.used);
      }
    } on StateError {
      if (mounted) setState(() => _invalid = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'changed');
    } finally {
      if (mounted) setState(() => _using = false);
    }
  }

  String _group(FinderGroup g, AppLocalizations l) => switch (g) {
        FinderGroup.priority => l.finderPriority,
        FinderGroup.manual => l.finderManualGroup,
        FinderGroup.pixels => l.finderPixels,
        FinderGroup.unknown => l.finderUnknown
      };
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
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), s = _session;
    final busy =
        _using || _preparing || s?.running == true || s?.choosing == true;
    final results = s?.candidates
            .where((c) =>
                (_filter == null || c.group == _filter) &&
                '${c.analysis.name} ${c.analysis.relativePath}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList() ??
        <FinderCandidate>[];
    return PopScope(
        canPop: !_using,
        child: Scaffold(
            appBar: AppBar(title: Text(l.finderTitle)),
            body: SafeArea(
                top: false,
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      Text(_task?.name ?? l.finderTitle,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(l.finderIntro),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          key: const Key('finder-manual'),
                          onPressed: _using
                              ? null
                              : () => Navigator.pop(
                                  context, PhotoFinderResult.manual),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(l.finderManual)),
                      if (_task != null && _task!.outputs.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(l.finderNeedRequirements)),
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(l.taskOutputs),
                                        children: [
                                          for (final output in _task?.outputs ??
                                              <ApplicationOutput>[])
                                            ListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                    '${output.fileName}.jpg'),
                                                subtitle: Text(
                                                    '${output.spec.pixelWidth} × ${output.spec.pixelHeight} px')),
                                        ]),
                                    Text(l.finderScope),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                        key: const Key('finder-folder'),
                                        onPressed: busy ||
                                                _task == null ||
                                                _task!.outputs.isEmpty
                                            ? null
                                            : () => _open('chooseDirectory'),
                                        icon: const Icon(
                                            Icons.folder_open_outlined),
                                        label: Text(l.finderFolder)),
                                    OutlinedButton.icon(
                                        key: const Key('finder-files'),
                                        onPressed: busy ||
                                                _task == null ||
                                                _task!.outputs.isEmpty
                                            ? null
                                            : () => _open('chooseFiles'),
                                        icon: const Icon(
                                            Icons.photo_library_outlined),
                                        label: Text(l.finderFiles)),
                                    CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(l.finderRecursive),
                                        value: _recursive,
                                        onChanged: busy
                                            ? null
                                            : (v) => setState(
                                                () => _recursive = v ?? false)),
                                    Text(l.finderProvider,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    const SizedBox(height: 8),
                                    Text(l.finderLimits,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    TextButton.icon(
                                        onPressed: busy ||
                                                _task == null ||
                                                _task!.outputs.isEmpty
                                            ? null
                                            : () => _open('openDemo'),
                                        icon: const Icon(
                                            Icons.play_circle_outline),
                                        label: Text(l.finderDemo)),
                                    Text(l.finderDemoNote,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ]))),
                      if (s != null &&
                          (busy || s.processed > 0 || s.total > 0)) ...[
                        const SizedBox(height: 12),
                        if (busy)
                          LinearProgressIndicator(
                              value:
                                  s.total > 0 ? s.processed / s.total : null),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                                '${l.finderItems}: ${s.visited}\n${s.processed} / ${s.total} · ${l.finderUnknown}: ${s.skipped}')),
                        if (s.running)
                          OutlinedButton(
                              onPressed: s.stop, child: Text(l.finderStop)),
                        if (s.partial) Text(l.finderPartial),
                        if (!busy)
                          TextButton(
                              onPressed: () => s.clear(),
                              child: Text(l.finderClear)),
                      ],
                      if (_invalid)
                        Text(l.finderStale,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      if (_error != null || s?.error != null)
                        Text(_error == 'changed'
                            ? l.finderChanged
                            : l.finderFailed),
                      const SizedBox(height: 16),
                      Text(l.finderDisclaimer,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      if (s != null && s.candidates.isNotEmpty) ...[
                        TextField(
                            decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                labelText: l.finderSearch),
                            onChanged: (v) => setState(() => _query = v)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ChoiceChip(
                              label: Text(
                                  '${l.finderAll} (${s.candidates.length})'),
                              selected: _filter == null,
                              onSelected: (_) =>
                                  setState(() => _filter = null)),
                          for (final g in FinderGroup.values)
                            ChoiceChip(
                                label: Text(
                                    '${_group(g, l)} (${s.candidates.where((c) => c.group == g).length})'),
                                selected: _filter == g,
                                onSelected: (_) => setState(() => _filter = g)),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (results.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(s == null || s.candidates.isEmpty
                                ? l.finderEmpty
                                : l.finderNoMatches)),
                      for (final c in results) _candidate(c, l),
                    ]))));
  }

  Widget _candidate(FinderCandidate c, AppLocalizations l) {
    final a = c.analysis;
    return Card(
        key: ValueKey('finder-result-${a.name}'),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(a.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(a.relativePath,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (a.width > 0)
                    Text(
                        '${a.width} × ${a.height} px · ${a.faces.length} ${l.finderFaces} · ${c.coverage}/${_task!.outputs.length}'),
                  if (a.thumbnailPath.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                            height: 200,
                            child: Image.file(File(a.thumbnailPath),
                                cacheWidth: 500,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined)))),
                  if (a.thumbnailPath.isNotEmpty)
                    TextButton(
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                    title: Text(l.finderPreview),
                                    content: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: Image.file(File(a.thumbnailPath),
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons
                                                    .broken_image_outlined))),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(l.dialogCancel))
                                    ])),
                        child: Text(l.finderPreview)),
                  Text(_group(c.group, l),
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final reason in c.reasons)
                    Text('• ${_reason(reason, l)}'),
                  if (c.crops.isNotEmpty)
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(l.finderCrops),
                        children: [
                          Text(l.finderCropNote,
                              style: Theme.of(context).textTheme.bodySmall),
                          for (final crop in c.crops)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(children: [
                                  Text(
                                      '${crop.outputName}: ${crop.pixelWidth} × ${crop.pixelHeight} px'),
                                  if (a.thumbnailPath.isNotEmpty)
                                    SizedBox(
                                        height: 180,
                                        child: AspectRatio(
                                            aspectRatio: a.width / a.height,
                                            child: CustomPaint(
                                                foregroundPainter: _CropPainter(
                                                    crop,
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary),
                                                child: Image.file(
                                                    File(a.thumbnailPath),
                                                    fit: BoxFit.fill,
                                                    cacheWidth: 500,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        const SizedBox())))),
                                ])),
                        ]),
                  FilledButton(
                      onPressed: _using || _invalid || a.skip != null
                          ? null
                          : () => _use(c),
                      child: Text(l.finderUse)),
                ])));
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.crop, this.color);
  final FinderCrop crop;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(crop.left * size.width, crop.top * size.height,
            crop.width * size.width, crop.height * size.height),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.crop != crop || old.color != color;
}
