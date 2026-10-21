import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/application_task.dart';
import '../models/photo_spec.dart';
import '../services/application_task_store.dart';
import '../services/application_delivery.dart';
import '../services/photo_file_inspection.dart';
import '../widgets/photo_input.dart';
import '../widgets/task_details_dialog.dart';
import 'custom_spec_page.dart';
import 'edit_page.dart';

class ApplicationTaskPage extends StatefulWidget {
  const ApplicationTaskPage({super.key, required this.taskId, this.store});
  final String taskId;
  final ApplicationTaskStore? store;
  @override
  State<ApplicationTaskPage> createState() => _ApplicationTaskPageState();
}

class _ApplicationTaskPageState extends State<ApplicationTaskPage> {
  ApplicationTaskStore? _store;
  ApplicationTask? _task;
  bool _busy = false, _error = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _store ??= widget.store ?? await ApplicationTaskStore.open();
      final task = await _store!.get(widget.taskId);
      if (mounted) {
        setState(() {
          _task = task;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _act(Future<void> Function() action,
      {bool exporting = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) showPhotoActionError(context, e, exporting: exporting);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async {
    final l = AppLocalizations.of(context);
    return await showAdaptiveDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog.adaptive(
                    title: Text(title),
                    content: Text(text),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l.dialogCancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l.confirm))
                    ])) ??
        false;
  }

  Future<void> _metadata() async {
    final details = await showDialog<TaskDetails>(
        context: context, builder: (_) => TaskDetailsDialog(task: _task));
    if (details == null || !mounted) return;
    await _act(() async {
      await _store!.updateMetadata(widget.taskId,
          name: details.name,
          notes: details.notes,
          sourceReference: details.reference,
          verifiedDate: details.date);
    });
  }

  Future<void> _source({bool evidence = false}) async {
    final l = AppLocalizations.of(context);
    if (!evidence &&
        _task!.hasSource &&
        !await _confirm(l.taskReplaceSource, l.taskReplaceWarning)) {
      return;
    }
    if (!mounted) return;
    await _act(() async {
      final selected = await choosePhotoInput(context, allowCamera: !evidence);
      if (selected == null || !mounted) return;
      final bytes = await readBoundedPhoto(selected);
      if (evidence) {
        await _store!.setEvidence(widget.taskId, bytes);
      } else {
        await _store!.setSource(widget.taskId, bytes);
      }
    });
  }

  Future<void> _requirement({ApplicationOutput? existing}) async {
    final l = AppLocalizations.of(context);
    if (existing != null &&
        existing.ready &&
        !await _confirm(l.taskEditRequirement, l.taskRequirementsChanged)) {
      return;
    }
    if (!mounted) return;
    final spec = await Navigator.push<PhotoSpec>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CustomSpecPage(returnSpec: true, initialSpec: existing?.spec)));
    if (spec == null || !mounted) return;
    final name = await showDialog<String>(
        context: context,
        builder: (_) => OutputNameDialog(
            initialName:
                existing?.fileName ?? 'photo_${_task!.outputs.length + 1}'));
    if (name == null || !mounted) return;
    await _act(() async {
      if (existing == null) {
        await _store!.addOutput(widget.taskId, spec, name);
      } else {
        await _store!.updateOutput(widget.taskId, existing.id, spec, name);
      }
    });
  }

  Future<void> _prepare(ApplicationOutput output) async {
    final snapshot = _task!;
    if (!snapshot.hasSource) return;
    await _act(() async {
      final file = _store!.sourceFile(snapshot);
      if (!await file.exists()) throw StateError('Missing source');
      if (!mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EditPage(
                    sourcePath: file.path,
                    spec: output.spec,
                    fixedRequirements: true,
                    onDelivered: (bytes, spec) async {
                      await _store!.saveOutput(
                          snapshot.id, output.id, bytes, spec,
                          expectedRevision: snapshot.tokenFor(output));
                    },
                  )));
    });
  }

  Future<void> _export() async {
    final locale = AppLocalizations.of(context).localeName;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await _act(() async {
      final zip = await ApplicationDelivery.build(
          _task!, _store!, await getTemporaryDirectory(), locale);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await SharePlus.instance.share(ShareParams(
          files: [XFile(zip.path, mimeType: 'application/zip')],
          sharePositionOrigin: origin));
    }, exporting: true);
  }

  Future<void> _inspect(ApplicationOutput output) async {
    final l = AppLocalizations.of(context);
    await _act(() async {
      final file = _store!.outputFile(_task!, output);
      if (await file.length() > 30 * 1024 * 1024) {
        throw ArgumentError('Image exceeds limit');
      }
      final report = await compute(
          inspectPhotoFileWorker, (await file.readAsBytes(), output.spec));
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text('${output.fileName}.jpg'),
                  content: SingleChildScrollView(
                      child: SelectableText(report.readable(l.localeName))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l.dialogCancel))
                  ]));
    });
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(l.taskDelete, l.taskDeleteConfirm) || !mounted) return;
    await _act(() async {
      await _store!.delete(widget.taskId);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tr = Tr.of(context);
    final task = _task;
    return Scaffold(
        appBar: AppBar(title: Text(l.tasksTitle), actions: [
          if (task != null) ...[
            IconButton(
                onPressed: _busy ? null : _metadata,
                tooltip: l.taskEdit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                onPressed: _busy ? null : _delete,
                tooltip: l.taskDelete,
                icon: const Icon(Icons.delete_outline))
          ],
        ]),
        body: _error
            ? Center(child: TextButton(onPressed: _load, child: Text(l.retry)))
            : task == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                        Text(task.name,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        if (task.notes.isNotEmpty) ...[
                          SelectableText(task.notes),
                          const SizedBox(height: 12)
                        ],
                        if (task.sourceReference.isNotEmpty) ...[
                          Text(l.taskSourceReference,
                              style: Theme.of(context).textTheme.labelLarge),
                          SelectableText(task.sourceReference),
                          Text(l.taskReferenceNote,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12)
                        ],
                        if (task.verifiedDate.isNotEmpty) ...[
                          Text('${l.taskVerifiedDate}: ${task.verifiedDate}'),
                          const SizedBox(height: 12)
                        ],
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(l.taskEvidence,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 8),
                                      if (task.hasEvidence)
                                        TextButton.icon(
                                            icon: const Icon(
                                                Icons.image_outlined),
                                            label: Text(l.taskViewEvidence),
                                            onPressed: () => showDialog<void>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                    content: Image.file(
                                                        _store!
                                                            .evidenceFile(task),
                                                        cacheWidth: 1000,
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            Text(l
                                                                .taskActionFailed))))),
                                      OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _source(evidence: true),
                                          icon: const Icon(Icons.attach_file),
                                          label: Text(l.taskAttachEvidence)),
                                    ]))),
                        const SizedBox(height: 16),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(l.taskOriginal,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 12),
                                      if (task.hasSource) ...[
                                        Image.file(_store!.sourceFile(task),
                                            height: 170,
                                            cacheWidth: 500,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                Text(l.taskInvalidFile)),
                                        const SizedBox(height: 12)
                                      ],
                                      OutlinedButton.icon(
                                          onPressed:
                                              _busy ? null : () => _source(),
                                          icon: const Icon(Icons
                                              .add_photo_alternate_outlined),
                                          label: Text(task.hasSource
                                              ? l.taskReplaceSource
                                              : l.taskChooseSource)),
                                      if (!task.hasSource)
                                        Text(l.taskNoSource,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                    ]))),
                        const SizedBox(height: 24),
                        Text(l.taskOutputs,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                            '${task.outputs.where((o) => o.ready).length} / ${task.outputs.length} ${l.taskFilesCount}'),
                        const SizedBox(height: 12),
                        if (task.outputs.isEmpty)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(l.taskNoOutputs)),
                        for (final output in task.outputs)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text('${output.fileName}.jpg',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium),
                                            const SizedBox(height: 6),
                                            Text(
                                                '${output.spec.name}\n${output.spec.pixelWidth} × ${output.spec.pixelHeight} px · ${output.spec.minFileKb}–${output.spec.maxFileKb} KB · ${tr.bgName(output.spec.background)}'),
                                            const SizedBox(height: 8),
                                            Row(children: [
                                              Icon(
                                                  output.ready
                                                      ? Icons
                                                          .check_circle_outline
                                                      : Icons.pending_outlined,
                                                  size: 18),
                                              const SizedBox(width: 6),
                                              Text(output.ready
                                                  ? l.taskReady
                                                  : l.taskPending)
                                            ]),
                                            const SizedBox(height: 12),
                                            FilledButton.tonalIcon(
                                                onPressed: _busy ||
                                                        !task.hasSource
                                                    ? null
                                                    : () => _prepare(output),
                                                icon: const Icon(Icons.crop),
                                                label: Text(output.ready
                                                    ? l.taskRedo
                                                    : l.taskPrepare)),
                                            Wrap(spacing: 8, children: [
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _requirement(
                                                          existing: output),
                                                  child: Text(
                                                      l.taskEditRequirement)),
                                              if (output.ready)
                                                TextButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () =>
                                                            _inspect(output),
                                                    child: Text(l.resultTitle)),
                                              IconButton(
                                                  tooltip: l.taskRemoveOutput,
                                                  onPressed: _busy
                                                      ? null
                                                      : () async {
                                                          if (await _confirm(
                                                                  l.taskRemoveOutput,
                                                                  l.taskRemoveConfirm) &&
                                                              mounted) {
                                                            await _act(
                                                                () async {
                                                              await _store!
                                                                  .removeOutput(
                                                                      widget
                                                                          .taskId,
                                                                      output
                                                                          .id);
                                                            });
                                                          }
                                                        },
                                                  icon: const Icon(
                                                      Icons.delete_outline))
                                            ]),
                                          ])))),
                        OutlinedButton.icon(
                            key: const Key('add-output'),
                            onPressed: _busy || task.outputs.length >= 5
                                ? null
                                : () => _requirement(),
                            icon: const Icon(Icons.add),
                            label: Text(l.taskAddOutput)),
                        const SizedBox(height: 8),
                        Text(l.taskOutputLimit,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 24),
                        Text(l.taskExportHint),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: _busy || !task.complete ? null : _export,
                            icon: const Icon(Icons.folder_zip_outlined),
                            label: Text(_busy ? l.taskBusy : l.taskExport)),
                        const SizedBox(height: 12),
                        Text(l.checkScope,
                            style: Theme.of(context).textTheme.bodySmall),
                        if (_busy)
                          const Padding(
                              padding: EdgeInsets.all(12),
                              child:
                                  Center(child: CircularProgressIndicator())),
                      ]));
  }
}
