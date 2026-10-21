import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/services/compliance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('photoid_check_test_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temp.path);
    messenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_face_detector'),
        (call) async => call.method == 'vision#startFaceDetector' ? [] : null);
  });
  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_face_detector'), null);
    await temp.delete(recursive: true);
  });

  test('non-JPEG input never receives a passed format check', () async {
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 10, height: 10)));
    final report = await ComplianceService().check(bytes, studentPhotoSpec);
    expect(report.items.singleWhere((i) => i.id == 'format').pass, isFalse);
    expect(report.hardAllPass, isFalse);
  });

  test('zero file-size ceiling means no maximum', () async {
    final image = img.Image(width: 50, height: 50);
    final bytes = Uint8List.fromList(img.encodeJpg(image));
    final report = await ComplianceService()
        .check(bytes, studentPhotoSpec.copyWith(minFileKb: 0, maxFileKb: 0));
    expect(report.items.singleWhere((i) => i.id == 'fileSize').pass, isTrue);
  });

  test('one-pixel JPEG reports dimensions without dividing by zero', () async {
    final bytes =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 1, height: 1)));
    final report = await ComplianceService().check(bytes, studentPhotoSpec);
    expect(report.items.singleWhere((i) => i.id == 'pixelSize').pass, isFalse);
  });
}
