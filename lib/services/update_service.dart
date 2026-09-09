import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 新版本信息。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isForceUpdate,
  });

  /// 远程最新版本号（已去掉 v 前缀）。
  final String version;

  /// APK 下载地址（GitHub Release asset 直连）。
  final String downloadUrl;

  /// Release notes。
  final String releaseNotes;

  /// 是否强制更新。
  final bool isForceUpdate;

  @override
  String toString() =>
      'UpdateInfo(version: $version, downloadUrl: $downloadUrl, '
      'releaseNotes: $releaseNotes, isForceUpdate: $isForceUpdate)';
}

/// GitHub Release 自升级检查服务。
///
/// 静默失败：任何网络/解析异常都返回 null，不打扰用户。
class UpdateService {
  static const String repoOwner = 'chunguangwei';
  static const String repoName = 'photoid';

  static const String _apiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const Duration _timeout = Duration(seconds: 15);

  /// 检查是否有新版本。无新版本或出错时返回 null。
  /// 仅 Android 支持 APK 自升级；iOS 走 App Store，直接返回 null。
  Future<UpdateInfo?> checkUpdate() async {
    if (!Platform.isAndroid) return null;
    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final currentVersion =
          stripVPrefix((await PackageInfo.fromPlatform()).version.trim());
      return parseRelease(release, currentVersion: currentVersion);
    } catch (_) {
      // 静默失败：无网络、解析失败、超时等都不打扰用户。
      return null;
    }
  }

  /// 从 GitHub Release JSON 解析出升级信息；无 APK 资源或版本不更新时返回
  /// null。纯函数，便于脱离平台测试。
  static UpdateInfo? parseRelease(
    Map<String, dynamic> release, {
    required String currentVersion,
  }) {
    final tagName = release['tag_name'] as String?;
    if (tagName == null || tagName.isEmpty) return null;

    final remoteVersion = stripVPrefix(tagName.trim());
    if (!isNewer(remoteVersion, stripVPrefix(currentVersion.trim()))) {
      return null;
    }

    final assets = release['assets'] as List<dynamic>? ?? const [];
    String? apkUrl;
    for (final asset in assets) {
      final assetMap = asset as Map<String, dynamic>;
      final name = assetMap['name'] as String? ?? '';
      if (name.toLowerCase().contains('apk')) {
        apkUrl = assetMap['browser_download_url'] as String?;
        break;
      }
    }
    if (apkUrl == null || apkUrl.isEmpty) return null;

    return UpdateInfo(
      version: remoteVersion,
      downloadUrl: apkUrl,
      releaseNotes: (release['body'] as String?)?.trim() ?? '',
      isForceUpdate: false,
    );
  }

  /// 去掉版本号前缀 v/V。
  static String stripVPrefix(String version) {
    if (version.startsWith('v') || version.startsWith('V')) {
      return version.substring(1);
    }
    return version;
  }

  /// 简单 semver 比较：按 '.' 分段逐段比较数字段，远程版本必须严格大于
  /// 当前版本才返回 true。每段只取其开头的数字（"3-beta" 视为 3）；缺失的
  /// 段按 0 补齐（1.2 == 1.2.0）。
  static bool isNewer(String remote, String current) {
    final remoteParts = _splitVersion(remote);
    final currentParts = _splitVersion(current);
    final length =
        remoteParts.length > currentParts.length
            ? remoteParts.length
            : currentParts.length;
    for (var i = 0; i < length; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r != c) return r > c;
    }
    return false;
  }

  /// 把版本字符串拆成数字段："1.2.3-beta" -> [1, 2, 3]。
  static List<int> _splitVersion(String version) {
    return version
        .split('.')
        .map((segment) {
          final digits = RegExp(r'^\d+').firstMatch(segment)?.group(0) ?? '0';
          return int.tryParse(digits) ?? 0;
        })
        .toList();
  }
}
