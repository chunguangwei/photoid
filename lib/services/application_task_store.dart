import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/application_task.dart';
import '../models/photo_spec.dart';
import 'photo_file_inspection.dart';

/// All mutations are serialized, including read/modify/write and file replacement.
/// Only application-owned copies are deleted. Metadata is atomically replaced.
class ApplicationTaskStore {
  ApplicationTaskStore(Directory documents)
      : _root = Directory(p.join(documents.path, 'tasks'));
  final Directory _root;
  static final Map<String, Future<void>> _pending = {};
  static Future<ApplicationTaskStore> open() async =>
      ApplicationTaskStore(await getApplicationDocumentsDirectory());
  static String _id() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static void _safeId(String id) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw ArgumentError('Invalid task ID');
    }
  }

  Directory _dir(String id) {
    _safeId(id);
    return Directory(p.join(_root.path, id));
  }

  File sourceFile(ApplicationTask task) =>
      File(p.join(_dir(task.id).path, 'source_${task.sourceRevision}.image'));
  File evidenceFile(ApplicationTask task) => File(p.join(
      _dir(task.id).path, 'requirements_${task.evidenceRevision}.image'));
  File outputFile(ApplicationTask task, ApplicationOutput output) {
    _safeId(output.id);
    return File(p.join(_dir(task.id).path, '${output.id}.jpg'));
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final key = _root.path;
    final next = (_pending[key] ?? Future<void>.value()).then((_) => action());
    late final Future<void> barrier;
    void release() {
      if (identical(_pending[key], barrier)) _pending.remove(key);
    }

    barrier = next.then<void>((_) => release(),
        onError: (Object _, StackTrace __) => release());
    _pending[key] = barrier;
    return next;
  }

  /// Keep reads and validation stable throughout delivery generation.
  Future<T> withTaskSnapshot<T>(
          String id, Future<T> Function(ApplicationTask) action) =>
      _serial(() async => action(await get(id)));

  Future<List<ApplicationTask>> list() async {
    if (!await _root.exists()) return [];
    final tasks = <ApplicationTask>[];
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      try {
        tasks.add(await get(p.basename(entity.path)));
      } catch (_) {/* isolate damaged records */}
    }
    tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tasks;
  }

  Future<ApplicationTask> get(String id) async {
    final j = jsonDecode(
            await File(p.join(_dir(id).path, 'task.json')).readAsString())
        as Map<String, dynamic>;
    final task = ApplicationTask.fromJson(j);
    if (task.id != id || task.name.trim().isEmpty || task.outputs.length > 5) {
      throw const FormatException('Invalid task');
    }
    final names = <String>{};
    for (final o in task.outputs) {
      _safeId(o.id);
      _validateName(o.fileName);
      _validateSpec(o.spec);
      if (!names.add(o.fileName.toLowerCase())) {
        throw const FormatException('Duplicate names');
      }
    }
    return task;
  }

  Future<void> _atomic(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.next');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }

  Future<ApplicationTask> _write(ApplicationTask t) async {
    final json = t.toJson()
      ..['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    final next = ApplicationTask.fromJson(json);
    await _atomic(File(p.join(_dir(t.id).path, 'task.json')),
        utf8.encode(jsonEncode(next.toJson())));
    return next;
  }

  Future<ApplicationTask> create(
          {required String name,
          String notes = '',
          String sourceReference = '',
          String verifiedDate = ''}) =>
      _serial(() async {
        _validateMetadata(name, notes, sourceReference, verifiedDate);
        return _write(ApplicationTask(
            id: _id(),
            name: name.trim(),
            notes: notes,
            sourceReference: sourceReference,
            verifiedDate: verifiedDate,
            updatedAt: DateTime.now().toUtc()));
      });
  Future<ApplicationTask> updateMetadata(String id,
          {required String name,
          required String notes,
          required String sourceReference,
          required String verifiedDate}) =>
      _serial(() async {
        _validateMetadata(name, notes, sourceReference, verifiedDate);
        final j = (await get(id)).toJson()
          ..addAll({
            'name': name.trim(),
            'notes': notes,
            'sourceReference': sourceReference,
            'verifiedDate': verifiedDate
          });
        return _write(ApplicationTask.fromJson(j));
      });
  static void _validateMetadata(
      String name, String notes, String source, String date) {
    if (name.trim().isEmpty ||
        name.length > 80 ||
        notes.length > 4000 ||
        source.length > 1000) {
      throw ArgumentError('Invalid task details');
    }
    if (date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      if (parsed == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          parsed.toIso8601String().substring(0, 10) != date) {
        throw ArgumentError('Invalid date');
      }
    }
  }

  static void _validateName(String name) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(name)) {
      throw ArgumentError('Invalid output name');
    }
  }

  static void _validateSpec(PhotoSpec s) {
    if (s.pixelWidth < 50 ||
        s.pixelHeight < 50 ||
        s.pixelWidth > 2000 ||
        s.pixelHeight > 2000 ||
        s.pixelWidth / s.pixelHeight < 0.5 ||
        s.pixelWidth / s.pixelHeight > 2 ||
        s.minFileKb < 0 ||
        s.maxFileKb < 0 ||
        s.minFileKb > 2048 ||
        s.maxFileKb > 2048 ||
        (s.maxFileKb > 0 && s.minFileKb > s.maxFileKb)) {
      throw ArgumentError('Invalid output requirements');
    }
  }

  Future<void> _validateImage(Uint8List bytes) async {
    final check =
        await compute(inspectPhotoFileWorker, (bytes, studentPhotoSpec));
    if (check.width == null) throw ArgumentError('Unreadable image');
  }

  Future<ApplicationTask> setSource(String id, Uint8List bytes) =>
      _serial(() async {
        await _validateImage(bytes);
        final t = await get(id);
        // Version the source first; metadata remains readable if the process stops.
        final nextRevision = t.sourceRevision + 1;
        await _atomic(
            File(p.join(_dir(id).path, 'source_$nextRevision.image')), bytes);
        final j = t.toJson()
          ..['hasSource'] = true
          ..['sourceRevision'] = nextRevision
          ..['outputs'] = [
            for (final o in t.outputs) o.toJson()..['ready'] = false
          ];
        final next = await _write(ApplicationTask.fromJson(j));
        // The canonical accessor uses sourceRevision, so stale editors keep their own path.
        return next;
      });
  Future<ApplicationTask> setEvidence(String id, Uint8List bytes) =>
      _serial(() async {
        await _validateImage(bytes);
        final t = await get(id);
        final j = t.toJson()
          ..['hasEvidence'] = true
          ..['evidenceRevision'] = t.evidenceRevision + 1;
        final next = ApplicationTask.fromJson(j);
        await _atomic(evidenceFile(next), bytes);
        return _write(next);
      });
  Future<ApplicationTask> addOutput(
          String id, PhotoSpec spec, String fileName) =>
      _serial(() async {
        final t = await get(id);
        if (t.outputs.length >= 5) throw StateError('Maximum five outputs');
        _validateSpec(spec);
        _uniqueName(t, fileName);
        final j = t.toJson()
          ..['outputs'] = [
            ...t.outputs.map((o) => o.toJson()),
            ApplicationOutput(id: _id(), spec: spec, fileName: fileName)
                .toJson()
          ];
        return _write(ApplicationTask.fromJson(j));
      });
  void _uniqueName(ApplicationTask t, String name, {String? except}) {
    _validateName(name);
    if (t.outputs.any((o) =>
        o.id != except && o.fileName.toLowerCase() == name.toLowerCase())) {
      throw ArgumentError('Duplicate output name');
    }
  }

  Future<ApplicationTask> updateOutput(
          String id, String outputId, PhotoSpec spec, String name) =>
      _serial(() async {
        final t = await get(id);
        _validateSpec(spec);
        _uniqueName(t, name, except: outputId);
        if (!t.outputs.any((o) => o.id == outputId)) {
          throw StateError('Missing output');
        }
        final j = t.toJson()
          ..['outputs'] = [
            for (final o in t.outputs)
              o.id != outputId
                  ? o.toJson()
                  : ApplicationOutput(
                          id: o.id,
                          spec: spec,
                          fileName: name,
                          revision: o.revision + 1)
                      .toJson()
          ];
        return _write(ApplicationTask.fromJson(j));
      });
  Future<ApplicationTask> removeOutput(String id, String outputId) =>
      _serial(() async {
        final t = await get(id);
        final j = t.toJson()
          ..['outputs'] = [
            for (final o in t.outputs)
              if (o.id != outputId) o.toJson()
          ];
        final next = await _write(ApplicationTask.fromJson(j));
        for (final o in t.outputs.where((o) => o.id == outputId)) {
          final file = outputFile(t, o);
          if (await file.exists()) await file.delete();
        }
        return next;
      });
  Future<ApplicationTask> saveOutput(
          String id, String outputId, Uint8List bytes, PhotoSpec usedSpec,
          {String? expectedRevision}) =>
      _serial(() async {
        final t = await get(id);
        final o = t.outputs.firstWhere((o) => o.id == outputId);
        if (!t.hasSource ||
            (expectedRevision != null && expectedRevision != t.tokenFor(o))) {
          throw StateError('Requirements or source changed');
        }
        final a = o.spec, b = usedSpec;
        if (a.pixelWidth != b.pixelWidth ||
            a.pixelHeight != b.pixelHeight ||
            a.minFileKb != b.minFileKb ||
            a.maxFileKb != b.maxFileKb ||
            a.background.r != b.background.r ||
            a.background.g != b.background.g ||
            a.background.b != b.background.b) {
          throw StateError('Output no longer matches requirements');
        }
        final check = await compute(inspectPhotoFileWorker, (bytes, o.spec));
        if (!check.hardAllPass) {
          throw StateError('File does not meet requirements');
        }
        await _atomic(outputFile(t, o), bytes);
        final j = t.toJson()
          ..['outputs'] = [
            for (final v in t.outputs)
              v.toJson()..['ready'] = (v.id == outputId ? true : v.ready)
          ];
        return _write(ApplicationTask.fromJson(j));
      });
  Future<void> delete(String id) => _serial(() async {
        final dir = _dir(id);
        if (await dir.exists()) await dir.delete(recursive: true);
      });
}
