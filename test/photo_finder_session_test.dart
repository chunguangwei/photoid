import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/photo_finder_session.dart';
import 'package:photoid/models/application_task.dart';

class FakeFinder implements FinderGateway {
  final calls = <String>[];
  final pending = Completer<Map>();
  bool wait = false;
  @override
  Future<dynamic> call(String method, Map<String, dynamic> args) async {
    calls.add(method);
    if (method == 'chooseDirectory') {
      return {
        'session': 's',
        'visited': 2,
        'truncated': false,
        'entries': [
          {'id': 'a', 'name': 'a', 'relativePath': 'a'},
          {'id': 'b', 'name': 'b', 'relativePath': 'b'}
        ]
      };
    }
    if (method == 'analyze') {
      if (wait) return pending.future;
      return {
        'id': args['id'],
        'name': args['id'],
        'relativePath': args['id'],
        'skip': 'unsupported'
      };
    }
    return null;
  }
}

void main() {
  test(
      'listing cannot start analysis until foreground and clear invalidates it',
      () async {
    final foreground = Completer<void>();
    final g = FakeFinder();
    final s = PhotoFinderSession([],
        gateway: g, waitUntilForeground: () => foreground.future);
    final run = s.open('chooseDirectory');
    await Future<void>.delayed(Duration.zero);
    expect(g.calls, isNot(contains('analyze')));
    await s.clear();
    foreground.complete();
    await run;
    expect(g.calls, isNot(contains('analyze')));
    expect(g.calls, contains('close'));
    s.dispose();
  });
  test('foreground return starts the explicitly selected source', () async {
    final foreground = Completer<void>();
    final g = FakeFinder();
    final s = PhotoFinderSession([],
        gateway: g, waitUntilForeground: () => foreground.future);
    final run = s.open('chooseDirectory');
    await Future<void>.delayed(Duration.zero);
    expect(g.calls, isNot(contains('analyze')));
    foreground.complete();
    await run;
    expect(g.calls.where((c) => c == 'analyze').length, 2);
    s.dispose();
  });

  test('scans sequentially, includes skips and closes permission session',
      () async {
    final g = FakeFinder();
    final s = PhotoFinderSession(const <ApplicationOutput>[], gateway: g);
    await s.open('chooseDirectory');
    expect(s.candidates.length, 2);
    expect(s.skipped, 2);
    expect(s.running, false);
    await s.clear();
    expect(g.calls.where((m) => m == 'close').length, 1);
    s.dispose();
  });
  test('stopping preserves completed results and ignores late inference',
      () async {
    final g = FakeFinder()..wait = true;
    final s = PhotoFinderSession([], gateway: g);
    final run = s.open('chooseDirectory');
    await Future<void>.delayed(Duration.zero);
    s.stop();
    g.pending.complete(
        {'id': 'a', 'name': 'a', 'relativePath': 'a', 'skip': 'unreadable'});
    await run;
    expect(s.candidates, isEmpty);
    expect(s.partial, true);
    await s.clear();
    s.dispose();
  });
  test('dispose ignores late results and releases scope', () async {
    final g = FakeFinder()..wait = true;
    final s = PhotoFinderSession([], gateway: g);
    final run = s.open('chooseDirectory');
    await Future<void>.delayed(Duration.zero);
    s.dispose();
    g.pending.complete(
        {'id': 'a', 'name': 'a', 'relativePath': 'a', 'skip': 'unreadable'});
    await run;
    expect(s.candidates, isEmpty);
    expect(g.calls, contains('close'));
  });
}
