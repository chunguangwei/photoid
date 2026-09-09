import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语言覆盖服务：null=跟随系统；持久化到 SharedPreferences。
/// MaterialApp 监听 [locale] 重建，设置页写入。
class LocaleService {
  LocaleService._();

  static const _key = 'locale_override';

  /// 当前语言覆盖（null = 跟随系统）。
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// 启动时读取持久化设置。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    locale.value = switch (v) {
      'en' => const Locale('en'),
      'zh' => const Locale('zh'),
      _ => null,
    };
  }

  /// 设置语言覆盖（null 恢复跟随系统）并持久化。
  static Future<void> setLocale(Locale? value) async {
    locale.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, value.languageCode);
    }
  }
}
