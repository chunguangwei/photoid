import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// App 内相册：成片双写一份到私有文档目录，供「我的相册」浏览/删除。
/// 文件名 {yyyyMMdd_HHmmss}_{baseName}.jpg，baseName 通常为教育ID或原图名。
class AlbumService {
  AlbumService._();

  static Directory? _cachedDir;

  /// 相册目录（`<documents>/album`），不存在则创建。
  static Future<Directory> albumDir() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}album');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _cachedDir = dir;
  }

  /// 纯函数：文件名规则 {yyyyMMdd_HHmmss}_{baseName}.jpg（本地时区）。
  static String buildFileName(DateTime t, String baseName) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '${ts}_$baseName.jpg';
  }

  /// 保存成片，返回写入的文件。
  static Future<File> save(Uint8List bytes, String baseName) async {
    final dir = await albumDir();
    final file = File('${dir.path}${Platform.pathSeparator}'
        '${buildFileName(DateTime.now(), baseName)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 全部成片，按修改时间倒序（最新在前）。
  static Future<List<File>> list() async {
    final dir = await albumDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// 按路径删除单张（不存在时静默）。
  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
