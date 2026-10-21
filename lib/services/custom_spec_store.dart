import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_spec.dart';

/// 自定义规格持久化存储（SharedPreferences JSON 列表）。
/// 首页展示已保存规格，支持删除。
class CustomSpecStore {
  CustomSpecStore._();

  static const _key = 'custom_specs';
  static Future<void> _pendingWrite = Future.value();

  /// 读取全部已保存自定义规格（解析失败的脏数据自动剔除）。
  static Future<List<PhotoSpec>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final specs = <PhotoSpec>[];
      for (final entry in list) {
        try {
          final spec =
              PhotoSpec.fromJson((entry as Map).cast<String, dynamic>());
          if (spec.pixelWidth <= 0 ||
              spec.pixelHeight <= 0 ||
              spec.minFileKb < 0 ||
              spec.maxFileKb < 0 ||
              (spec.maxFileKb > 0 && spec.minFileKb > spec.maxFileKb)) {
            continue;
          }
          specs.add(spec);
        } catch (_) {
          // 一条损坏记录不应使其余用户规格消失。
        }
      }
      return specs;
    } catch (_) {
      return [];
    }
  }

  /// 保存（同名同尺寸去重，新的覆盖旧的）。
  static Future<void> save(PhotoSpec spec) => _serialize(() async {
        final list = await load();
        list.removeWhere((s) =>
            s.name == spec.name &&
            s.pixelWidth == spec.pixelWidth &&
            s.pixelHeight == spec.pixelHeight);
        list.insert(0, spec);
        await _write(list);
      });

  /// 按 id 删除。
  static Future<void> delete(String id) => _serialize(() async {
        final list = await load();
        list.removeWhere((s) => s.id == id);
        await _write(list);
      });

  static Future<void> _serialize(Future<void> Function() action) {
    final next = _pendingWrite.then((_) => action());
    _pendingWrite = next.catchError((Object _) {});
    return next;
  }

  static Future<void> _write(List<PhotoSpec> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(list.map((s) => s.toJson()).toList()));
  }
}
