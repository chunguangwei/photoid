import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter does not expose iOS Reduce Transparency through MediaQuery.
class GlassPreferences {
  GlassPreferences._();
  static final reduceTransparency = ValueNotifier<bool>(false);
  static const _channel = MethodChannel('photoid/accessibility');

  static Future<void> load() async {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reduceTransparencyChanged' &&
          call.arguments is bool) {
        reduceTransparency.value = call.arguments as bool;
      }
    });
    try {
      reduceTransparency.value =
          await _channel.invokeMethod<bool>('getReduceTransparency') ?? false;
    } on MissingPluginException {
      // Tests/older installed builds can still render an opaque fallback.
      reduceTransparency.value = true;
    } on PlatformException {
      reduceTransparency.value = true;
    }
  }
}
