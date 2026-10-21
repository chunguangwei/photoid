import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/application_task.dart';
import '../services/application_task_store.dart';
import '../widgets/task_details_dialog.dart';
import '../widgets/photo_input.dart';
import 'application_task_page.dart';

class ApplicationTasksPage extends StatefulWidget {
  const ApplicationTasksPage({super.key, this.store});
  final ApplicationTaskStore? store;
  @override
  State<ApplicationTasksPage> createState() => _ApplicationTasksPageState();
}

class _ApplicationTasksPageState extends State<ApplicationTasksPage> {
  ApplicationTaskStore? _store;
  List<ApplicationTask>? _tasks;
  bool _error = false, _creating = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _store ??= widget.store ?? await ApplicationTaskStore.open();
      final list = await _store!.list();
      if (mounted) {
        setState(() {
          _tasks = list;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _create() async {
    if (_creating || _store == null) return;
    final details = await showDialog<TaskDetails>(
        context: context, builder: (_) => const TaskDetailsDialog());
    if (details == null || !mounted) return;
    setState(() => _creating = true);
    try {
      final t = await _store!.create(
          name: details.name,
          notes: details.notes,
          sourceReference: details.reference,
          verifiedDate: details.date);
      if (!mounted) return;
      await _open(t);
    } catch (e) {
      if (mounted) showPhotoActionError(context, e);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _open(ApplicationTask t) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ApplicationTaskPage(taskId: t.id, store: _store)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(l.tasksTitle)),
        floatingActionButton: FloatingActionButton.extended(
            key: const Key('new-task'),
            onPressed: _creating || _store == null ? null : _create,
            icon: const Icon(Icons.add),
            label: Text(l.taskNew)),
        body: _error
            ? Center(child: TextButton(onPressed: _load, child: Text(l.retry)))
            : _tasks == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    children: [
                        Text(l.tasksDesc,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 20),
                        if (_tasks!.isEmpty)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.folder_copy_outlined,
                                            size: 36),
                                        const SizedBox(height: 16),
                                        Text(l.taskEmpty,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        const SizedBox(height: 8),
                                        Text(l.taskEmptyHint)
                                      ]))),
                        for (final t in _tasks!)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                  child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: Icon(t.complete
                                          ? Icons.task_alt
                                          : Icons.folder_outlined),
                                      title: Text(t.name),
                                      subtitle: Text(
                                          '${t.outputs.where((o) => o.ready).length} / ${t.outputs.length} ${l.taskFilesCount}'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _open(t)))),
                      ]));
  }
}
