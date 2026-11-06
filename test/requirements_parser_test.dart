import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/requirements_parser.dart';

void main() {
  test('explicit Chinese dimensions and range keep original evidence', () {
    final d = parseRequirements('照片宽480像素，高640像素；20–100 KB；蓝底，JPG');
    expect(d.dimensions.single.width, 480);
    expect(d.dimensions.single.height, 640);
    expect(d.dimensions.single.ambiguous, false);
    expect(d.sizes.single.min, 20);
    expect(d.sizes.single.max, 100);
    expect(d.backgrounds, ['blue']);
    expect(d.text, contains('宽480'));
  });
  test('English dimensions and max only do not invent minimum', () {
    final d = parseRequirements(
        'Width: 300 px, height: 400 px. No more than 100 KB. White background. JPEG');
    expect(d.dimensions.single.width, 300);
    expect(d.sizes.single.min, isNull);
    expect(d.sizes.single.max, 100);
    expect(d.backgrounds, ['white']);
  });
  test('unlabelled pair is ambiguous and multiple candidates stay separate',
      () {
    final d = parseRequirements(
        '480 x 640 px, 300×400像素; 20-100 KB / 10-80KB; 蓝底或白底');
    expect(d.dimensions.length, 2);
    expect(d.dimensions.every((v) => v.ambiguous), true);
    expect(d.sizes.length, 2);
    expect(d.backgrounds.toSet(), {'blue', 'white'});
  });
  test('millimetres, MB and PNG are unsupported, unrelated numbers ignored',
      () {
    final d = parseRequirements('报名2026年 35×45mm, 2 MB, PNG 证件号码123456789');
    expect(d.dimensions, isEmpty);
    expect(d.sizes, isEmpty);
    expect(d.warnings.toSet(), containsAll(['units', 'format']));
  });
  test('plain KB amount does not imply max or range', () {
    expect(parseRequirements('文件 100KB').sizes, isEmpty);
    expect(parseRequirements('尺寸480×640').dimensions, isEmpty);
  });
  test('English background names do not match inside other words', () {
    expect(
        parseRequirements('A JPEG is required. Whiteboard reference.')
            .backgrounds,
        isEmpty);
  });
  test('decimal and negative values are never parsed as integer suffixes', () {
    for (final text in [
      '10.5–100 KB',
      '1,020–100 KB',
      '-20-100 KB',
      '100000-100 KB',
      '20-100KBps'
    ]) {
      expect(parseRequirements(text).sizes, isEmpty, reason: text);
    }
    expect(parseRequirements('4.480×640px').dimensions, isEmpty);
  });
  test('dimension bounds do not become exact dimensions', () {
    expect(
        parseRequirements('minimum width 480px, maximum height 640px')
            .dimensions,
        isEmpty);
    expect(parseRequirements('最小宽480像素，最大高640像素').dimensions, isEmpty);
  });
  test('trailing minimum and Chinese dimension bounds are not exact values',
      () {
    for (final text in [
      'Width: 480px minimum, height: 640px',
      '宽480像素以上，高640像素',
      '宽480像素，高640像素以内'
    ]) {
      expect(parseRequirements(text).dimensions, isEmpty, reason: text);
    }
  });
  test('unrecognized OCR units stay unfilled rather than being guessed', () {
    expect(parseRequirements('宽480像秦,高640像素').dimensions, isEmpty);
  });
  test('reversed range remains visible for validation, bounded input', () {
    expect(parseRequirements('100-20KB').sizes.single.min, 100);
    expect(() => parseRequirements('x' * 100001), throwsArgumentError);
  });
}
