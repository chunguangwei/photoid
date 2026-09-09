import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/album_service.dart';

void main() {
  // AlbumService 的文件操作依赖 path_provider 平台通道，测试环境无
  // MethodChannel 实现，故不测文件创建/读写；这里只测抽出的纯函数
  // 文件名生成规则。
  group('AlbumService.buildFileName 文件名规则', () {
    test('格式为 {yyyyMMdd_HHmmss}_{baseName}.jpg', () {
      final t = DateTime(2026, 3, 9, 6, 7, 8);
      expect(AlbumService.buildFileName(t, '123456'), '20260309_060708_123456.jpg');
    });

    test('月/日/时/分/秒零填充', () {
      final t = DateTime(2026, 1, 2, 3, 4, 5);
      expect(AlbumService.buildFileName(t, 'edu'), '20260102_030405_edu.jpg');
    });

    test('保留 baseName 原样（含中文、连字符）', () {
      final t = DateTime(2025, 12, 31, 23, 59, 59);
      expect(AlbumService.buildFileName(t, '学生-001'), '20251231_235959_学生-001.jpg');
    });
  });
}
