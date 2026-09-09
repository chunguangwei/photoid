import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/models/photo_spec.dart';

void main() {
  group('studentPhotoSpec 不变量', () {
    const s = studentPhotoSpec;

    test('宽高比约 0.75，高/宽比例落在 [1.2, 1.4]', () {
      expect(s.aspect, closeTo(0.75, 1e-9));
      expect(s.pixelHeight / s.pixelWidth, inInclusiveRange(1.2, 1.4));
    });

    test('像素尺寸落在允许区间内', () {
      expect(s.minWidth, lessThanOrEqualTo(s.pixelWidth));
      expect(s.pixelWidth, lessThanOrEqualTo(s.maxWidth));
      expect(s.minHeight, lessThanOrEqualTo(s.pixelHeight));
      expect(s.pixelHeight, lessThanOrEqualTo(s.maxHeight));
    });

    test('文件大小区间合法且覆盖常规交付体积', () {
      expect(s.minFileKb, lessThan(s.maxFileKb));
      expect(s.minFileKb, greaterThan(0));
    });

    test('底色为标准蓝底 RGB(67,142,219)', () {
      expect(s.background.name, '蓝底');
      expect(s.background.r, 67);
      expect(s.background.g, 142);
      expect(s.background.b, 219);
    });

    test('面向用户的要求清单非空', () {
      expect(s.requirements, isNotEmpty);
    });
  });

  group('PhotoSpec.fromJson', () {
    Map<String, Object?> studentJson() => {
          'id': 'student_edu_id',
          'name': '学生报名照',
          'pixelWidth': 480,
          'pixelHeight': 640,
          'minFileKb': 10,
          'maxFileKb': 500,
          'minWidth': 380,
          'maxWidth': 580,
          'minHeight': 540,
          'maxHeight': 740,
          'minRatio': 1.2,
          'maxRatio': 1.4,
          'background': {'name': '蓝底', 'r': 67, 'g': 142, 'b': 219},
          'requirements': ['文件大小在 10KB–500KB 之间'],
        };

    test('完整 JSON map 反序列化后字段值一一对应', () {
      final spec = PhotoSpec.fromJson(studentJson());

      expect(spec.id, 'student_edu_id');
      expect(spec.name, '学生报名照');
      expect(spec.pixelWidth, 480);
      expect(spec.pixelHeight, 640);
      expect(spec.minFileKb, 10);
      expect(spec.maxFileKb, 500);
      expect(spec.minWidth, 380);
      expect(spec.maxWidth, 580);
      expect(spec.minHeight, 540);
      expect(spec.maxHeight, 740);
      expect(spec.minRatio, closeTo(1.2, 1e-9));
      expect(spec.maxRatio, closeTo(1.4, 1e-9));
      expect(spec.background.name, '蓝底');
      expect(spec.background.r, 67);
      expect(spec.background.g, 142);
      expect(spec.background.b, 219);
      expect(spec.requirements, ['文件大小在 10KB–500KB 之间']);
    });

    test('JSON 数值带小数时比例字段仍解析为 double', () {
      final json = studentJson()
        ..['minRatio'] = 1.25
        ..['maxRatio'] = 1.35;
      final spec = PhotoSpec.fromJson(json);
      expect(spec.minRatio, isA<double>());
      expect(spec.maxRatio, isA<double>());
      expect(spec.minRatio, closeTo(1.25, 1e-9));
      expect(spec.maxRatio, closeTo(1.35, 1e-9));
    });

    test('缺省 requirements 时默认为空列表', () {
      final json = studentJson()..remove('requirements');
      final spec = PhotoSpec.fromJson(json);
      expect(spec.requirements, isEmpty);
    });
  });
}
