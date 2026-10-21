import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/application_task.dart';

typedef TaskDetails = ({
  String name,
  String notes,
  String reference,
  String date
});

class TaskDetailsDialog extends StatefulWidget {
  const TaskDetailsDialog({super.key, this.task});
  final ApplicationTask? task;
  @override
  State<TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<TaskDetailsDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.task?.name);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late final _reference =
      TextEditingController(text: widget.task?.sourceReference);
  late String _date = widget.task?.verifiedDate ?? '';
  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
        title: Text(l.taskDetails),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                              key: const Key('task-name'),
                              controller: _name,
                              maxLength: 80,
                              decoration:
                                  InputDecoration(labelText: l.taskName),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? l.taskRequiredName
                                  : null),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _notes,
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 4000,
                              decoration:
                                  InputDecoration(labelText: l.taskNotes)),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _reference,
                              maxLength: 1000,
                              maxLines: 2,
                              decoration: InputDecoration(
                                  labelText: l.taskSourceReference)),
                          Text(l.taskReferenceNote,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          Text(l.taskVerifiedDate),
                          Wrap(spacing: 8, children: [
                            TextButton.icon(
                                icon: const Icon(Icons.event_outlined),
                                label: Text(
                                    _date.isEmpty ? l.taskChooseDate : _date),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          DateTime.tryParse(_date) ?? now,
                                      firstDate: DateTime(2000),
                                      lastDate: now);
                                  if (picked != null && mounted) {
                                    setState(() => _date =
                                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                                  }
                                }),
                            if (_date.isNotEmpty)
                              TextButton(
                                  onPressed: () => setState(() => _date = ''),
                                  child: Text(l.taskClearDate))
                          ]),
                        ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.dialogCancel)),
          FilledButton(
              key: const Key('save-task-details'),
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, (
                    name: _name.text.trim(),
                    notes: _notes.text.trim(),
                    reference: _reference.text.trim(),
                    date: _date
                  ));
                }
              },
              child: Text(l.taskSave))
        ]);
  }
}

class OutputNameDialog extends StatefulWidget {
  const OutputNameDialog({super.key, required this.initialName});
  final String initialName;
  @override
  State<OutputNameDialog> createState() => _OutputNameDialogState();
}

class _OutputNameDialogState extends State<OutputNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
        title: Text(l.taskFilename),
        content: Form(
            key: _form,
            child: SizedBox(
                width: 360,
                child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 80,
                    decoration: InputDecoration(
                        suffixText: '.jpg',
                        helperText: l.taskFilenameHelp,
                        helperMaxLines: 4),
                    validator: (s) =>
                        RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(s ?? '')
                            ? null
                            : l.taskInvalidName))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.dialogCancel)),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _name.text);
                }
              },
              child: Text(l.taskSave))
        ]);
  }
}
