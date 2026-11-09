import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/application_task.dart';
import 'photo_finder_models.dart';
import 'photo_finder_ranking.dart';

abstract interface class FinderGateway {
  Future<dynamic> call(String method, Map<String, dynamic> args);
}

class NativeFinderGateway implements FinderGateway {
  static const channel = MethodChannel('photoid/photo_finder');
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) =>
      channel.invokeMethod(method, args);
}

class PhotoFinderSession extends ChangeNotifier {
  PhotoFinderSession(this.outputs,
      {FinderGateway? gateway, this.waitUntilForeground})
      : gateway = gateway ?? NativeFinderGateway();
  final List<ApplicationOutput> outputs;
  final FinderGateway gateway;
  final Future<void> Function()? waitUntilForeground;
  final candidates = <FinderCandidate>[];
  String? _session, error;
  int _scope = 0, _scan = 0;
  int visited = 0, total = 0, processed = 0, skipped = 0;
  bool running = false, choosing = false, partial = false, _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open(String method,
      {bool recursive = false, List<String>? demoPaths}) async {
    await clear();
    if (_disposed) return;
    final scope = ++_scope, scan = ++_scan;
    choosing = true;
    error = null;
    _notify();
    try {
      final result = await gateway.call(method,
          {'recursive': recursive, if (demoPaths != null) 'paths': demoPaths});
      if (result == null) {
        if (_disposed || scope != _scope) return;
        choosing = false;
        _notify();
        return;
      }
      final id = result['session'] as String;
      if (_disposed || scope != _scope) {
        await gateway.call('close', {'session': id});
        return;
      }
      _session = id;
      await waitUntilForeground?.call();
      if (_disposed || scope != _scope || scan != _scan) return;
      choosing = false;
      running = true;
      visited = (result['visited'] as num?)?.toInt() ?? 0;
      partial = result['truncated'] == true;
      final entries = (result['entries'] as List).take(500).toList();
      total = entries.length;
      if ((result['entries'] as List).length > 500) partial = true;
      _notify();
      for (final raw in entries) {
        if (_disposed || scope != _scope || scan != _scan) break;
        final entry = Map<String, dynamic>.from(raw as Map);
        FinderAnalysis analysis;
        try {
          final data =
              await gateway.call('analyze', {'session': id, 'id': entry['id']});
          analysis = FinderAnalysis.fromMap(
              {...entry, ...Map<String, dynamic>.from(data as Map)});
          if (analysis.skip == null && analysis.thumbnailPath.isNotEmpty) {
            final file = File(analysis.thumbnailPath);
            if (await file.length() <= 8 * 1024 * 1024) {
              final q = await compute(finderImageQuality,
                  (await file.readAsBytes(), analysis.faces));
              if (q != null) analysis = analysis.withQuality(q.$1, q.$2);
            }
          }
        } catch (_) {
          analysis = FinderAnalysis.fromMap({...entry, 'skip': 'unreadable'});
        }
        if (_disposed || scope != _scope || scan != _scan) break;
        candidates.add(evaluatePhoto(analysis, outputs));
        processed++;
        if (analysis.skip != null) skipped++;
        candidates.sort((a, b) => b.order.compareTo(a.order));
        _notify();
        if (analysis.skip == 'cacheLimit') {
          partial = true;
          break;
        }
      }
    } on PlatformException catch (e) {
      if (!_disposed && scope == _scope) error = e.code;
    } catch (_) {
      if (!_disposed && scope == _scope) error = 'access';
    } finally {
      if (!_disposed && scope == _scope) {
        choosing = false;
        running = false;
        _notify();
      }
    }
  }

  void stop() {
    if (running || choosing) partial = true;
    _scan++;
    running = false;
    _notify();
    if (_session != null) {
      unawaited(gateway
          .call('interrupt', {'session': _session}).catchError((_) => null));
    }
  }

  Future<String> materialize(FinderCandidate candidate) async {
    final id = _session, scope = _scope;
    if (id == null || _disposed) throw StateError('Scan session ended');
    final result = await gateway.call('materialize', {
      'session': id,
      'id': candidate.analysis.id,
      'fingerprint': candidate.analysis.fingerprint
    });
    if (_disposed || scope != _scope) throw StateError('Scan session changed');
    return result['path'] as String;
  }

  Future<void> clear() async {
    _scope++;
    _scan++;
    final id = _session;
    _session = null;
    running = false;
    choosing = false;
    partial = false;
    candidates.clear();
    visited = 0;
    total = 0;
    processed = 0;
    skipped = 0;
    error = null;
    _notify();
    if (id != null) await gateway.call('close', {'session': id});
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(clear().catchError((_) {}));
    super.dispose();
  }
}
