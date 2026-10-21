import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/services/photo_file_inspection.dart';

PhotoSpec requirement({int maxKb = 0}) => PhotoSpec(
    id: 'test',
    name: 'Application',
    pixelWidth: 100,
    pixelHeight: 140,
    minFileKb: 0,
    maxFileKb: maxKb,
    minWidth: 100,
    maxWidth: 100,
    minHeight: 140,
    maxHeight: 140,
    minRatio: 1.39,
    maxRatio: 1.41,
    background: idPhotoBackgrounds.first);

void main() {
  test('inspects actual JPEG dimensions and byte count without changing input',
      () {
    final bytes =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 140)));
    final original = Uint8List.fromList(bytes);
    final result = inspectPhotoFile(bytes, requirement());
    expect(result.hardAllPass, isTrue);
    expect((result.width, result.height, result.byteCount),
        (100, 140, bytes.length));
    expect(bytes, original);
    expect(result.readable('en'), contains('100 × 140'));
  });
  test('PNG retains measured dimensions but fails required JPEG format', () {
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 100, height: 140)));
    final result = inspectPhotoFile(bytes, requirement());
    expect(result.hardAllPass, isFalse);
    expect(result.width, 100);
    expect(result.checks.first.passed, isFalse);
  });
  test('mismatched dimensions and impossible byte ceiling are reported', () {
    final bytes =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 480, height: 640)));
    final result = inspectPhotoFile(bytes, requirement(maxKb: 1));
    expect(result.checks.where((c) => !c.passed).map((c) => c.id),
        containsAll(['fileSize', 'pixelSize', 'ratio']));
  });
  test('corrupt file returns failed report and no invented measurements', () {
    final result =
        inspectPhotoFile(Uint8List.fromList([255, 216, 255, 0]), requirement());
    expect(result.hardAllPass, isFalse);
    expect(result.width, isNull);
    expect(result.checks.any((c) => c.id == 'decodable' && !c.passed), isTrue);
  });
  test('rejects excessive declared JPEG pixels before allocating an image', () {
    final bytes = Uint8List.fromList(img.encodeJpg(img.Image(width:100,height:140)));
    final sof = List.generate(bytes.length - 1, (i) => i).firstWhere((i) => bytes[i] == 255 && bytes[i+1] == 192);
    bytes[sof+5]=0x13; bytes[sof+6]=0x88;
    bytes[sof+7]=0x13; bytes[sof+8]=0x88;
    expect(() => inspectPhotoFile(bytes, requirement()), throwsArgumentError);
  });
  test('rejects unsafe oversized input before decoding', () {
    expect(
        () => inspectPhotoFile(Uint8List(30 * 1024 * 1024 + 1), requirement()),
        throwsArgumentError);
  });
}
