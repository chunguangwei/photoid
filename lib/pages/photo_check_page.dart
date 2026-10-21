import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/photo_spec.dart';
import '../services/photo_file_inspection.dart';
import '../widgets/photo_input.dart';
import 'custom_spec_page.dart';
import 'edit_page.dart';

class PhotoCheckPage extends StatefulWidget {
  const PhotoCheckPage({super.key, this.initialSpec});
  final PhotoSpec? initialSpec;
  @override
  State<PhotoCheckPage> createState() => _PhotoCheckPageState();
}

class _PhotoCheckPageState extends State<PhotoCheckPage> {
  PhotoSpec? _spec;
  Uint8List? _bytes;
  String? _path, _name;
  PhotoFileInspection? _report;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _spec = widget.initialSpec;
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await choosePhotoInput(context);
      if (file == null || !mounted) return;
      final bytes = await readBoundedPhoto(file);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _path = file.path;
        _name = file.name;
        _report = null;
      });
    } catch (e) {
      if (mounted) showPhotoActionError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requirements() async {
    final spec = await Navigator.push<PhotoSpec>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CustomSpecPage(returnSpec: true, initialSpec: _spec)));
    if (spec != null && mounted) {
      setState(() {
        _spec = spec;
        _report = null;
      });
    }
  }

  Future<void> _check() async {
    if (_busy || _bytes == null || _spec == null) return;
    setState(() {
      _busy = true;
      _report = null;
    });
    try {
      final report = await compute(inspectPhotoFileWorker, (_bytes!, _spec!));
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) showPhotoActionError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(l.checkExistingTitle)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(l.checkExistingDesc,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.checkActual,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        if (_path != null) ...[
                          if (_report?.width != null)
                            Image.file(File(_path!),
                                height: 150,
                                fit: BoxFit.contain,
                                cacheWidth: 400,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48)),
                          const SizedBox(height: 8),
                          Text(_name!,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 12)
                        ],
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.folder_open),
                            label: Text(l.checkChooseFile)),
                        const SizedBox(height: 8),
                        Text(l.checkByteNote,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]))),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.checkRequirements,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (_spec != null) ...[
                          const SizedBox(height: 8),
                          Text(
                              '${_spec!.name}\n${_spec!.pixelWidth} × ${_spec!.pixelHeight} px · ${_spec!.minFileKb}–${_spec!.maxFileKb} KB')
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _requirements,
                            icon: const Icon(Icons.tune),
                            label: Text(l.checkSetRequirements))
                      ]))),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed:
                  _busy || _bytes == null || _spec == null ? null : _check,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(_busy ? l.taskBusy : l.checkRun)),
          if (_report == null && !_busy)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l.checkNoFile)),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
          if (_report != null) ...[
            const SizedBox(height: 20),
            Text(_report!.hardAllPass ? l.checkPassed : l.checkFailed,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.checkScope),
            const SizedBox(height: 12),
            for (final c in _report!.checks)
              Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                c.passed
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: c.passed
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(c.label(l.localeName),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${l.checkRequired}: ${c.expected}\n${l.checkActual}: ${c.actual}')
                                ]))
                          ]))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _busy || _path == null
                    ? null
                    : () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EditPage(
                                    sourcePath: _path!, spec: _spec!)));
                      },
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.checkMakeCopy)),
          ],
          const SizedBox(height: 24),
        ]));
  }
}
