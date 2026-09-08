import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/photo_spec.dart';

/// 内置证件照规格库（assets/photo_specs.json），纯端侧加载。
class SpecLibrary {
  SpecLibrary._();

  static List<PhotoSpec>? _specs;

  /// 加载全部规格（首次解析后缓存）。
  static Future<List<PhotoSpec>> load() async {
    if (_specs != null) return _specs!;
    final raw = await rootBundle.loadString('assets/photo_specs.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => PhotoSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _specs = list;
    return list;
  }

  /// 按名称关键字过滤（不区分大小写；空串返回全部）。
  static Future<List<PhotoSpec>> search(String keyword) async {
    final all = await load();
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return all;
    return all.where((s) => s.name.toLowerCase().contains(k)).toList();
  }
}
