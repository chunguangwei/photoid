import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/embedding_model_store.dart';

/// loopback 假源：按清单名提供字节，可注入 notfound（整站 404）/
/// bad（内容整体取反，size 一致但 SHA 不符）/ slow（分片+延时，供 pause）/
/// cut（传输中途 destroy socket，模拟断流）行为。
class FakeSource {
  FakeSource(this.files);

  final Map<String, Uint8List> files;
  final Set<String> notFoundPaths = {};
  final Set<String> badPaths = {};
  final Set<String> slowPaths = {};
  final Map<String, int> cutRemaining = {};

  int requests = 0;
  int rangeRequests = 0;

  late final HttpServer server;

  /// 源模板（{path} 占位符交给 EmbeddingModelStore 填充）。
  String get source => 'http://127.0.0.1:${server.port}/{path}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> stop() => server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    requests++;
    final res = req.response..bufferOutput = false;
    try {
      final path = Uri.decodeComponent(req.uri.path.substring(1));
      final all = files[path];
      if (all == null || notFoundPaths.contains(path)) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      // bad：忽略 Range，永远返回同尺寸的错内容（200）
      if (badPaths.contains(path)) {
        final body = Uint8List.fromList(
            all.map((b) => b ^ 0xFF).toList(growable: false));
        res.headers.contentLength = body.length;
        res.add(body);
        await res.close();
        return;
      }
      var start = 0;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        rangeRequests++;
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      }
      if (start >= all.length) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await res.close();
        return;
      }
      final tail = Uint8List.sublistView(all, start);
      if ((cutRemaining[path] ?? 0) > 0) {
        // 断流：声明全量长度但只发一半即 close——客户端流报
        // ClientException（contentLength 未收满），模拟中途掉线
        cutRemaining[path] = cutRemaining[path]! - 1;
        res.headers.contentLength = tail.length;
        res.add(Uint8List.sublistView(tail, 0, tail.length ~/ 2));
        await res.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // 服务端 close 自身会因字节不足抛错，忽略
        try {
          await res.close();
        } catch (_) {}
        return;
      }
      if (start > 0) {
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-${all.length - 1}/${all.length}');
      }
      res.headers.contentLength = tail.length;
      if (slowPaths.contains(path)) {
        final size = max(256, tail.length ~/ 20);
        for (var i = 0; i < tail.length; i += size) {
          res.add(Uint8List.sublistView(tail, i, min(i + size, tail.length)));
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      } else {
        res.add(tail);
      }
      await res.close();
    } catch (_) {
      // 客户端 abort/destroy 后写响应报错：忽略
    }
  }
}

Future<String> shaOf(File f) =>
    sha256.bind(f.openRead()).first.then((d) => d.toString());

void main() {
  late Directory root;
  late Map<String, Uint8List> pool;
  late List<EmbeddingFileSpec> manifest;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('embedding_store_test');
    final rnd = Random(7);
    Uint8List bytes(int n) =>
        Uint8List.fromList(List.generate(n, (_) => rnd.nextInt(256)));
    pool = {
      'onnx/model.onnx': bytes(2048),
      'onnx/model.onnx_data': bytes(40960),
      'tokenizer.json': bytes(8192),
    };
    manifest = pool.entries
        .map((e) =>
            EmbeddingFileSpec(e.key, e.value.length, sha256.convert(e.value).toString()))
        .toList();
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<EmbeddingModelStore> openStore(List<FakeSource> sources) async {
    final store = await EmbeddingModelStore.open(
      root: root,
      manifest: manifest,
      sources: sources.map((s) => s.source).toList(),
    );
    return store;
  }

  Future<void> expectAllShaOk() async {
    for (final s in manifest) {
      final f = File('${root.path}/${s.localName}');
      expect(f.existsSync(), isTrue, reason: s.localName);
      expect(await shaOf(f), s.sha256, reason: s.localName);
    }
  }

  test('fresh store is notInstalled; file() rejects non-manifest names', () async {
    final store = await EmbeddingModelStore.open(
        root: root, manifest: manifest, sources: ['http://127.0.0.1:1/{path}']);
    expect(store.status, EmbeddingModelStatus.notInstalled);
    expect(store.totalBytes, 2048 + 40960 + 8192);
    expect(store.installedBytes, 0);
    expect(store.directoryPath, root.absolute.path);
    expect(store.file('tokenizer.json').path,
        '${root.path}${Platform.pathSeparator}tokenizer.json');
    expect(store.file('onnx/model.onnx').path,
        '${root.path}${Platform.pathSeparator}model.onnx');
    expect(() => store.file('onnx/evil'), throwsArgumentError);
    expect(() => store.file('../../etc/passwd'), throwsArgumentError);
  });

  test('断流后 Range 续传完成且 SHA 通过（源A 掐流，源B 续传）', () async {
    final a = FakeSource(pool);
    final b = FakeSource(pool);
    await a.start();
    await b.start();
    a.cutRemaining['onnx/model.onnx_data'] = 1; // 大文件第一刀
    final store = await openStore([a, b]);
    final progress = <EmbeddingModelProgress>[];
    await store.startDownload(onProgress: progress.add);
    expect(store.status, EmbeddingModelStatus.ready);
    await expectAllShaOk();
    expect(b.rangeRequests, greaterThan(0), reason: '续传必须带 Range');
    expect(progress.last.receivedBytes, store.totalBytes);
    await a.stop();
    await b.stop();
  });

  test('源1 挂（404）→ 源2 成功', () async {
    final a = FakeSource(pool);
    final b = FakeSource(pool);
    a.notFoundPaths.addAll(pool.keys);
    await a.start();
    await b.start();
    final store = await openStore([a, b]);
    await store.startDownload();
    expect(store.status, EmbeddingModelStatus.ready);
    await expectAllShaOk();
    expect(b.requests, manifest.length);
    await a.stop();
    await b.stop();
  });

  test('SHA 不符 → 删断点换新源整文件重下', () async {
    final a = FakeSource(pool);
    final b = FakeSource(pool);
    a.badPaths.addAll(pool.keys); // 源1 内容全部损坏（尺寸一致）
    await a.start();
    await b.start();
    final store = await openStore([a, b]);
    await store.startDownload();
    expect(store.status, EmbeddingModelStatus.ready);
    await expectAllShaOk();
    // 源1 收过首个文件的完整传输；此后源2 成为首选源（一次会话记住
    // 可用源），其余文件直接走源2
    expect(a.requests, 1);
    expect(b.requests, manifest.length);
    expect(root.listSync().whereType<File>().where((f) => f.path.endsWith('.part')), isEmpty);
    await a.stop();
    await b.stop();
  });

  test('pause 保留 .part；resume 带 Range 补完', () async {
    final a = FakeSource(pool)..slowPaths.add('onnx/model.onnx_data');
    await a.start();
    final store = await openStore([a]);
    final running = store.startDownload();
    // 等大文件断点出现并已有内容
    final part = File('${root.path}${Platform.pathSeparator}model.onnx_data.part');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!(part.existsSync() && part.lengthSync() > 0)) {
      expect(DateTime.now().isBefore(deadline), isTrue, reason: '断点未出现');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(store.status, EmbeddingModelStatus.downloading);
    await store.pauseDownload();
    await running; // 暂停正常返回，不抛
    final pausedLength = part.lengthSync();
    expect(part.existsSync(), isTrue);
    expect(pausedLength, lessThan(manifest[1].bytes));
    expect(store.status, EmbeddingModelStatus.partial);
    // 续传（不再限速）
    a.slowPaths.clear();
    await store.startDownload();
    expect(store.status, EmbeddingModelStatus.ready);
    await expectAllShaOk();
    expect(a.rangeRequests, greaterThan(0));
    await a.stop();
  });

  test('delete 清干净文件与 .part', () async {
    final a = FakeSource(pool);
    await a.start();
    final store = await openStore([a]);
    await store.startDownload();
    // 再制造一个断点：删掉大文件（尺寸不符触发重下）+ 限速以便中途暂停
    File('${root.path}${Platform.pathSeparator}model.onnx_data')
        .writeAsBytesSync([1, 2, 3]);
    a.slowPaths.add('onnx/model.onnx_data');
    final running = store.startDownload();
    final part = File('${root.path}${Platform.pathSeparator}model.onnx_data.part');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!(part.existsSync() && part.lengthSync() > 0)) {
      expect(DateTime.now().isBefore(deadline), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await store.pauseDownload();
    await running;
    expect(part.existsSync(), isTrue);
    await store.delete();
    final left = root
        .listSync()
        .whereType<File>()
        .where((f) => manifest.any((s) => f.path.endsWith(s.localName)) ||
            f.path.endsWith('.part'))
        .toList();
    expect(left, isEmpty);
    expect(store.status, EmbeddingModelStatus.notInstalled);
    await a.stop();
  });

  test('status 迁移：notInstalled→downloading→ready；坏尺寸→corrupt→修复回 ready', () async {
    final a = FakeSource(pool)..slowPaths.addAll(pool.keys);
    await a.start();
    final store = await openStore([a]);
    expect(store.status, EmbeddingModelStatus.notInstalled);
    final running = store.startDownload();
    expect(store.status, EmbeddingModelStatus.downloading,
        reason: '调用后同步即为 downloading');
    await store.pauseDownload();
    await running;
    // 清空断点，走快速路径：先写好正确尺寸的文件再下载
    await store.delete();
    for (final s in manifest) {
      File(store.file(s.name).path)
          .writeAsBytesSync(pool[s.name]!, flush: true);
    }
    expect(store.status, EmbeddingModelStatus.ready);
    final damaged = File(store.file('tokenizer.json').path);
    final goodBytes = damaged.readAsBytesSync();
    damaged.writeAsBytesSync([0xAA, 0xBB], flush: true);
    expect(store.status, EmbeddingModelStatus.corrupt);
    expect(store.installedBytes, 2048 + 40960 + 2);
    await store.startDownload(); // 尺寸不符 → 整文件重下修复
    expect(store.status, EmbeddingModelStatus.ready);
    expect(damaged.readAsBytesSync(), goodBytes);
    await a.stop();
  });

  test('wifiOnly 为文档性 no-op：照常下载', () async {
    final a = FakeSource(pool);
    await a.start();
    final store = await openStore([a]);
    await store.startDownload(wifiOnly: true);
    expect(store.status, EmbeddingModelStatus.ready);
    await a.stop();
  });

  test('进度为全文件累计值且单调不回退', () async {
    final a = FakeSource(pool);
    await a.start();
    final store = await openStore([a]);
    final progress = <EmbeddingModelProgress>[];
    await store.startDownload(onProgress: progress.add);
    expect(progress, isNotEmpty);
    var prev = 0;
    for (final p in progress) {
      expect(p.receivedBytes, greaterThanOrEqualTo(prev));
      expect(p.receivedBytes, lessThanOrEqualTo(store.totalBytes));
      prev = p.receivedBytes;
    }
    expect(progress.last.receivedBytes, store.totalBytes);
    // 跨文件累计：中间某个时刻 receivedBytes 覆盖超过第一个文件大小
    expect(progress.any((p) => p.receivedBytes > manifest[0].bytes), isTrue);
    await a.stop();
  });

  test('全部源失败：抛异常且保留进度，修复后续传完成', () async {
    // 全 404：抛 HTTP 错误，无进度
    final a = FakeSource(pool)..notFoundPaths.addAll(pool.keys);
    await a.start();
    final store = await openStore([a]);
    await expectLater(store.startDownload(), throwsA(isA<FormatException>()));
    expect(store.status, EmbeddingModelStatus.notInstalled);
    await a.stop();

    // 断流且无备选源：抛传输异常；首个文件已下齐 + 大文件 .part 保留
    final b = FakeSource(pool)..cutRemaining['onnx/model.onnx_data'] = 99;
    await b.start();
    final store2 = await openStore([b]);
    await expectLater(store2.startDownload(), throwsA(anything));
    final part = File('${root.path}${Platform.pathSeparator}model.onnx_data.part');
    expect(part.existsSync(), isTrue);
    expect(part.lengthSync(), greaterThan(0));
    expect(part.lengthSync(), lessThan(manifest[1].bytes));
    expect(store2.status, EmbeddingModelStatus.partial);
    // 修好后继续：Range 续传补完且 SHA 通过
    b.cutRemaining.clear();
    await store2.startDownload();
    expect(store2.status, EmbeddingModelStatus.ready);
    await expectAllShaOk();
    expect(b.rangeRequests, greaterThan(0));
    await b.stop();
  });
}
