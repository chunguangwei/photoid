// EmbeddingGemma 2 分词器：tokenizer.json（HuggingFace tokenizers 导出，BPE，
// vocab 262144，merges 514906，byte_fallback，added tokens）的纯 Dart 实现。
//
// 对齐 HF tokenizers（0.23 / python `tokenizers` 实测行为，golden 对拍
// test/fixtures/tokenizer_golden.json 16/16）：
//  - normalizer Replace(" " → "▁")：整段替换（U+2581 记号）。
//  - pre_tokenizer Split(" ", MergedWithPrevious)：正则只匹配字面空格，而
//    normalizer 已把全部空格换成 "▁"，故实际不切分——整段作为单个 BPE 输入
//    （与去掉 pre_tokenizer 的 tokenizers 输出逐 id 相同，已实测）。
//  - added tokens：24 个 special（<|image|>=258880 等）在原文上做最长匹配整体
//    切分（可出现在词中，single_word=false），前后文本各自继续走 BPE。
//  - BPE 初始 pieces：按 Unicode 码点查 vocab；未命中的码点走 byte_fallback，
//    展开为其 UTF-8 字节的 <0xNN>（大写十六进制）token。合并严格按 merges
//    文件顺序（rank）全局贪心：每轮取当前相邻 pair 中最小 rank，合并其全部
//    出现，循环至无可合并。ignore_merges=false，无 word 前后缀。
//  - fuse_unk=true：连续 <unk> 融合为一个（本表 256 个 <0xNN> 全在 vocab 中，
//    byte_fallback 永不产生 <unk>，保留融合仅为保真）。
//  - post_processor TemplateProcessing：输出 [bos] + tokens + [eos]。
//
// 加载策略：一次性读入全 vocab/merges 建表（~100MB，秒级），在 worker isolate
// 内只加载一次，耗时不敏感；之后 encode 为纯查表。
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

class GemmaTokenizer {
  GemmaTokenizer._({
    required HashMap<String, int> vocab,
    required int bos,
    required int eos,
    required int unk,
    required List<String> addedTokensLongestFirst,
    required Map<String, int> addedIds,
    required this.pairRank,
    required this.pairTo,
    required this.pairBase,
    required List<int> byteIds,
    required bool fuseUk,
  })  : _vocab = vocab,
        _bos = bos,
        _eos = eos,
        _unk = unk,
        _addedTokens = addedTokensLongestFirst,
        _addedIds = addedIds,
        _byteIds = byteIds,
        _fuseUk = fuseUk,
        _addedAllStartWithLt =
            addedTokensLongestFirst.every((t) => t.codeUnitAt(0) == 0x3C);

  final HashMap<String, int> _vocab;
  final int _bos;
  final int _eos;
  final int _unk;
  final List<String> _addedTokens; // 按长度降序，保证最长匹配
  final Map<String, int> _addedIds;
  /// key = a * pairBase + b（a、b 为 token id），value = merge rank（越小越先）
  final HashMap<int, int> pairRank;
  /// key 同上，value = 合并后的 token id
  final HashMap<int, int> pairTo;
  final int pairBase;
  final List<int> _byteIds;
  final bool _fuseUk;
  final bool _addedAllStartWithLt;

  /// 码点 → 初始 token ids 缓存（ASCII 高频，重复文本/循环下省 utf8 开销）
  final Map<int, List<int>> _pieceCache = HashMap<int, List<int>>();

  /// 解析 HF tokenizer.json（BPE + byte_fallback）。结构不符即抛 StateError
  /// （调用侧视为“模型损坏”，禁用加强版）。
  static GemmaTokenizer fromJsonFile(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw StateError('tokenizer.json 根节点不是对象');
    }
    final model = decoded['model'];
    if (model is! Map<String, dynamic> || model['type'] != 'BPE') {
      throw StateError('tokenizer.json model.type 不是 BPE');
    }
    if (model['byte_fallback'] != true) {
      throw StateError('tokenizer.json byte_fallback 未启用');
    }
    // 本表 ignore_merges=false、无 continuing/end 词缀；有则本实现未覆盖
    if (model['ignore_merges'] == true) {
      throw StateError('tokenizer.json ignore_merges=true 未支持');
    }
    if (model['continuing_subword_prefix'] != null ||
        model['end_of_word_suffix'] != null) {
      throw StateError('tokenizer.json 词缀方案未支持');
    }
    final fuseUk = model['fuse_unk'] == true;
    final vocabJson = model['vocab'];
    if (vocabJson is! Map<String, dynamic>) {
      throw StateError('tokenizer.json 缺少 vocab');
    }
    final vocab = HashMap<String, int>();
    var maxId = 0;
    vocabJson.forEach((token, id) {
      final v = id as int;
      vocab[token] = v;
      if (v > maxId) maxId = v;
    });

    int requireId(String token) {
      final id = vocab[token];
      if (id == null) throw StateError('tokenizer.json 缺少 token $token');
      return id;
    }

    final bos = requireId('<bos>');
    final eos = requireId('<eos>');
    final unk = requireId('<unk>');
    // byte_fallback 的 <0xNN>：大写十六进制，256 个必须齐全
    final byteIds = List<int>.filled(256, 0);
    for (var b = 0; b < 256; b++) {
      byteIds[b] = requireId('<0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}>');
    }

    // added tokens：按长度降序做最长匹配（<|image|> 必须优先于 <|image>）
    final addedJson = decoded['added_tokens'];
    final addedTokens = <String>[];
    final addedIds = <String, int>{};
    if (addedJson is List) {
      for (final entry in addedJson) {
        if (entry is! Map) continue;
        final content = entry['content'];
        final id = entry['id'];
        if (content is String && id is int) {
          addedTokens.add(content);
          addedIds[content] = id;
        }
      }
    }
    addedTokens.sort((a, b) =>
        b.length != a.length ? b.length - a.length : a.compareTo(b));

    final base = maxId + 1;
    final pairRank = HashMap<int, int>();
    final pairTo = HashMap<int, int>();
    final merges = model['merges'];
    if (merges is! List) throw StateError('tokenizer.json 缺少 merges');
    var rank = 0;
    for (final merge in merges) {
      final String left;
      final String right;
      if (merge is List) {
        left = merge[0] as String;
        right = merge[1] as String;
      } else if (merge is String) {
        // 少数导出格式用 "a b" 空格连接（本表无空格 token，可安全切分）
        final sp = merge.indexOf(' ');
        if (sp < 0) {
          left = merge;
          right = '';
        } else {
          left = merge.substring(0, sp);
          right = merge.substring(sp + 1);
        }
      } else {
        rank++;
        continue;
      }
      final a = vocab[left];
      final b = vocab[right];
      final merged = vocab[left + right];
      // 实测本表：全部 piece 与合并结果都在 vocab 中；缺任一说明表损坏
      if (a == null || b == null || merged == null) {
        throw StateError('tokenizer.json merge($rank) 引用了 vocab 外的 token: '
            '"$left" + "$right"');
      }
      final key = a * base + b;
      if (!pairRank.containsKey(key)) {
        pairRank[key] = rank;
        pairTo[key] = merged;
      }
      rank++;
    }

    return GemmaTokenizer._(
      vocab: vocab,
      bos: bos,
      eos: eos,
      unk: unk,
      addedTokensLongestFirst: List.unmodifiable(addedTokens),
      addedIds: Map.unmodifiable(addedIds),
      pairRank: pairRank,
      pairTo: pairTo,
      pairBase: base,
      byteIds: byteIds,
      fuseUk: fuseUk,
    );
  }

  /// text → token ids：`[<bos>, ..., <eos>]`。
  /// [maxTokens] 为含首尾模板的总长上限：超长时保留 bos + 前 maxTokens-2 个
  /// 内容 token + eos（截断发生在 BPE 之后，与 HF truncation 的整 token 截断一致）。
  List<int> encode(String text, {int? maxTokens}) {
    final content = <int>[];
    _forEachSegment(text, (specialId, plain) {
      if (specialId != null) {
        content.add(specialId);
        return;
      }
      final normalized = plain.replaceAll(' ', '\u2581');
      if (normalized.isEmpty) return;
      content.addAll(_bpe(_initialPieces(normalized)));
    });
    if (maxTokens != null && content.length > maxTokens - 2) {
      if (maxTokens <= 1) return [if (maxTokens == 1) _bos];
      content.length = maxTokens - 2;
    }
    return <int>[_bos, ...content, _eos];
  }

  /// 原文上最长匹配切出 added tokens（special），其余按原样交给 [onSegment]。
  void _forEachSegment(
      String text, void Function(int? specialId, String plain) onSegment) {
    if (_addedTokens.isEmpty) {
      onSegment(null, text);
      return;
    }
    final plain = StringBuffer();
    var i = 0;
    while (i < text.length) {
      String? match;
      // added tokens 全是 ASCII；本表全部以 '<' 开头，可跳过非 '<' 位置的扫描
      // （若表里有不以 '<' 开头的 added token，_addedAllStartWithLt=false，全位置扫描）
      if (!_addedAllStartWithLt || text.codeUnitAt(i) == 0x3C) {
        for (final token in _addedTokens) {
          if (text.startsWith(token, i)) {
            match = token;
            break;
          }
        }
      }
      if (match != null) {
        if (plain.isNotEmpty) {
          onSegment(null, plain.toString());
          plain.clear();
        }
        onSegment(_addedIds[match], '');
        i += match.length;
      } else {
        plain.writeCharCode(text.codeUnitAt(i));
        i++;
      }
    }
    if (plain.isNotEmpty) onSegment(null, plain.toString());
  }

  List<int> _initialPieces(String normalized) {
    final out = <int>[];
    for (final cp in normalized.runes) {
      final cached = _pieceCache[cp];
      if (cached != null) {
        out.addAll(cached);
        continue;
      }
      final id = _vocab[String.fromCharCode(cp)];
      final List<int> pieces;
      if (id != null) {
        pieces = [id];
      } else {
        // byte_fallback：UTF-8 字节 → <0xNN>（大写），全部命中 vocab
        pieces = utf8
            .encode(String.fromCharCode(cp))
            .map((b) => _byteIds[b])
            .toList(growable: false);
      }
      _pieceCache[cp] = pieces;
      out.addAll(pieces);
    }
    return out;
  }

  /// 全局贪心 BPE：每轮找相邻 pair 的最小 rank，合并其全部出现，直至无可合并。
  List<int> _bpe(List<int> pieces) {
    var cur = pieces;
    while (cur.length > 1) {
      int? bestKey;
      var bestRank = 1 << 62;
      for (var i = 0; i + 1 < cur.length; i++) {
        final key = cur[i] * pairBase + cur[i + 1];
        final r = pairRank[key];
        if (r != null && r < bestRank) {
          bestRank = r;
          bestKey = key;
        }
      }
      if (bestKey == null) break;
      final left = bestKey ~/ pairBase;
      final right = bestKey - left * pairBase;
      final merged = pairTo[bestKey]!;
      final next = <int>[];
      var i = 0;
      while (i < cur.length) {
        if (i + 1 < cur.length && cur[i] == left && cur[i + 1] == right) {
          next.add(merged);
          i += 2;
        } else {
          next.add(cur[i]);
          i++;
        }
      }
      cur = next;
    }
    // fuse_unk：连续 <unk> 只留一个（本表 byte_fallback 全命中，实际不触发）
    if (_fuseUk && cur.length > 1) {
      final fused = <int>[];
      for (final id in cur) {
        if (id == _unk && fused.isNotEmpty && fused.last == _unk) continue;
        fused.add(id);
      }
      cur = fused;
    }
    return cur;
  }
}
