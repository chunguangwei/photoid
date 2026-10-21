import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/pages/camera_page.dart';

void main() {
  testWidgets('leaving while camera enumeration is pending is safe',
      (tester) async {
    final response = Completer<List<dynamic>>();
    const channel = MethodChannel('plugins.flutter.io/camera');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'availableCameras' ? response.future : null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CameraPage(spec: studentPhotoSpec),
    ));
    await tester.pumpWidget(const SizedBox());
    response.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
