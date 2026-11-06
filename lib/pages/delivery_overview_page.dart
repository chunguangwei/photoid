import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/application_task.dart';
import '../services/application_task_store.dart';
import '../services/delivery_overview.dart';

class DeliveryOverviewPage extends StatefulWidget {
  const DeliveryOverviewPage(
      {super.key,
      required this.taskId,
      required this.store,
      required this.onPrepare,
      required this.onEdit});
  final String taskId;
  final ApplicationTaskStore store;
  final Future<void> Function(ApplicationOutput) onPrepare, onEdit;
  @override
  State<DeliveryOverviewPage> createState() => _DeliveryOverviewPageState();
}

class _DeliveryOverviewPageState extends State<DeliveryOverviewPage> {
  List<DeliveryOverviewItem>? _rows;
  bool _error = false, _acting = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _rows = null;
        _error = false;
      });
    }
    try {
      final task = await widget.store.get(widget.taskId);
      final rows = await inspectTaskDelivery(task, widget.store);
      if (mounted && generation == _generation) setState(() => _rows = rows);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _acting = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tr = Tr.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(l.workflowOverview), actions: [
          IconButton(
              onPressed: _acting ? null : _load,
              tooltip: l.workflowRefresh,
              icon: const Icon(Icons.refresh))
        ]),
        body: _error
            ? Center(child: TextButton(onPressed: _load, child: Text(l.retry)))
            : _rows == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(l.checkScope),
                    const SizedBox(height: 16),
                    for (final row in _rows!)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('${row.output.fileName}.jpg',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    Text(
                                        switch (row.status) {
                                          DeliveryStatus.unprepared =>
                                            l.workflowUnprepared,
                                          DeliveryStatus.missing =>
                                            l.workflowMissing,
                                          DeliveryStatus.failed =>
                                            l.workflowFailed,
                                          DeliveryStatus.passed =>
                                            l.workflowPassed
                                        },
                                        style: TextStyle(
                                            color: row.status ==
                                                    DeliveryStatus.passed
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface)),
                                    const SizedBox(height: 12),
                                    Text(l.workflowRequired,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    Text(
                                        '${row.output.spec.pixelWidth} × ${row.output.spec.pixelHeight} px · ${row.output.spec.minFileKb}–${row.output.spec.maxFileKb == 0 ? "∞" : row.output.spec.maxFileKb} KB · JPEG'),
                                    Text(
                                        '${l.workflowBackground}: ${tr.bgName(row.output.spec.background)}'),
                                    if (row.inspection != null) ...[
                                      const SizedBox(height: 12),
                                      Text(l.workflowActual,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      Text(
                                          '${row.inspection!.width ?? "—"} × ${row.inspection!.height ?? "—"} px · ${(row.inspection!.byteCount / 1024).toStringAsFixed(2)} KB (${row.inspection!.byteCount} bytes) · ${row.inspection!.format}'),
                                      for (final check in row.inspection!.checks
                                          .where((c) => !c.passed))
                                        Text(
                                            '${check.label(l.localeName)}: ${check.actual} / ${check.expected}')
                                    ],
                                    if (row.output.requirementSource
                                        case final source?)
                                      ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: Text(source.confirmed
                                              ? l.workflowConfirmed
                                              : l.workflowStale),
                                          children: [
                                            Text(l.workflowExcerpt),
                                            SelectableText(source.excerpt)
                                          ]),
                                    Wrap(spacing: 8, children: [
                                      TextButton(
                                          onPressed: _acting
                                              ? null
                                              : () => _act(() =>
                                                  widget.onPrepare(row.output)),
                                          child: Text(l.workflowPrepare)),
                                      TextButton(
                                          onPressed: _acting
                                              ? null
                                              : () => _act(() =>
                                                  widget.onEdit(row.output)),
                                          child: Text(l.workflowEdit))
                                    ])
                                  ])))
                  ]));
  }
}
