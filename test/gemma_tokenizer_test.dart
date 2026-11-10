import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/gemma_tokenizer.dart';

void main() {
  group('GemmaTokenizer（HF tokenizer.json 对拍）', () {
    late GemmaTokenizer tok;
    var loadMs = 0;

    setUpAll(() {
      final sw = Stopwatch()..start();
      tok = GemmaTokenizer.fromJsonFile('test/fixtures/tokenizer.json');
      sw.stop();
      loadMs = sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('tokenizer.json 加载耗时: ${sw.elapsedMilliseconds}ms '
          '(${File('test/fixtures/tokenizer.json').statSync().size} bytes)');
    });

    test('golden 16/16 逐 id 完全一致（python tokenizers 官方实现生成）', () {
      final raw = File('test/fixtures/tokenizer_golden.json').readAsStringSync();
      final cases = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => (
                text: e['text'] as String,
                ids: (e['ids'] as List).cast<int>(),
              ))
          .toList();
      expect(cases, hasLength(16));
      for (final c in cases) {
        expect(tok.encode(c.text), c.ids, reason: 'text=${c.text}');
      }
    });

    test('模板：<bos>…<eos> 包裹，空文本只剩模板', () {
      expect(tok.encode(''), [2, 1]);
      expect(tok.encode('portrait photo').first, 2);
      expect(tok.encode('portrait photo').last, 1);
    });

    test('byte_fallback：vocab 外码点 → UTF-8 字节 <0xNN> token', () {
      // U+1E2F ḯ 不在 vocab（无 NFC 分解 token）→ e1 b8 af = <0xE1><0xB8><0xAF>
      expect(tok.encode('\u1e2f'), [2, 463, 422, 413, 1]);
      // NUL / CR / NBSP 均不在 vocab → 字节 token
      expect(tok.encode('\x00a\u00a0b'), [2, 238, 236746, 432, 398, 236763, 1]);
      expect(tok.encode('a\rb'), [2, 236746, 251, 236763, 1]);
    });

    test('added tokens：最长匹配优先且可嵌在词中', () {
      expect(tok.encode('<|image|>'), [2, 258880, 1]);
      // <|image|>（长）必须赢过 <|image>（短前缀）
      expect(tok.encode('<|image|><|image>'), [2, 258880, 255999, 1]);
      expect(tok.encode('a<|image>b'), [2, 236746, 255999, 236763, 1]);
      expect(tok.encode('q<|image|>z'), [2, 236809, 258880, 236802, 1]);
      expect(tok.encode('<|audio|>'), [2, 258881, 1]);
      expect(tok.encode('<|video|>'), [2, 258884, 1]);
      // added tokens 表里是 <mask>（无竖线），整词匹配；<|mask|> 不是 added token
      expect(tok.encode('<mask>'), [2, 4, 1]);
      expect(tok.encode('a<mask>b'), [2, 236746, 4, 236763, 1]);
      expect(tok.encode('<|mask>'), [2, 236820, 236909, 1080, 236813, 1]);
      expect(tok.encode('<pad>'), [2, 0, 1]);
      expect(tok.encode('<|tool>'), [2, 46, 1]);
    });

    test('空格/制表/换行：空格→▁ 记号，tab/\\n 是独立 vocab 项', () {
      expect(tok.encode('   leading and trailing   '),
          [2, 139, 26016, 532, 45330, 139, 1]);
      expect(tok.encode('a\t\nb'), [2, 236746, 255968, 107, 236763, 1]);
      expect(tok.encode('  '), [2, 138, 1]);
    });

    test('maxTokens：含模板总长截断', () {
      final full = tok.encode('task: search result | query: a photo of me');
      expect(full.length, greaterThan(6));
      final cut = tok.encode('task: search result | query: a photo of me',
          maxTokens: 6);
      expect(cut, hasLength(6));
      expect(cut.first, 2);
      expect(cut.last, 1);
      expect(cut.sublist(0, 5), full.sublist(0, 5));
      // 不超限原样返回
      expect(tok.encode('hello', maxTokens: 512), tok.encode('hello'));
    });

    test('结构与 python tokenizers 参考一致（代理集）', () {
      // 这些 id 由 python tokenizers 0.23 对同表实测固定
      expect(tok.encode('aaa\t\t\tbbb'), [2, 72004, 255970, 187852, 1]);
      expect(tok.encode('\u{1F600}\u{1F600}'), [2, 242398, 242398, 1]);
      expect(tok.encode('a  b  c'), [2, 236746, 138, 236763, 138, 236755, 1]);
      expect(tok.encode('\u2603'), [2, 246690, 1]);
      expect(tok.encode('\ufffd'), [2, 238479, 1]);
      expect(tok.encode('x<|tool>y'), [2, 236781, 46, 236762, 1]);
      expect(tok.encode('\u{1F468}\u200d\u{1F469}\u200d\u{1F467}'),
          [2, 243874, 237243, 243767, 237243, 244814, 1]);
    });

    test('性能：512-token 查询级文本 encode 远低于交互预算', () {
      final text = List.filled(20,
              'task: search result | query: 去年在办公室穿正装的照片，portrait photo of business suit')
          .join(' ');
      final sw = Stopwatch()..start();
      final ids = tok.encode(text);
      sw.stop();
      // ignore: avoid_print
      print('encode ${text.length} chars → ${ids.length} tokens: '
          '${sw.elapsedMicroseconds}µs');
      expect(ids.length, greaterThan(256));
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('加载耗时可接受（isolate 一次性）', () {
      expect(loadMs, lessThan(60000));
    });
  });
}
