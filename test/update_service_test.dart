import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/update_service.dart';

void main() {
  group('isNewer', () {
    test('compares numeric segments, not strings', () {
      expect(UpdateService.isNewer('0.2.0', '0.1.0'), isTrue);
      expect(UpdateService.isNewer('0.1.10', '0.1.9'), isTrue);
      expect(UpdateService.isNewer('10.0.0', '9.9.9'), isTrue);
      expect(UpdateService.isNewer('0.0.9', '0.1.0'), isFalse);
      expect(UpdateService.isNewer('0.1.0', '0.1.0'), isFalse);
    });

    test('pads missing segments with zero and strips prerelease suffix', () {
      expect(UpdateService.isNewer('0.1', '0.1.0'), isFalse);
      expect(UpdateService.isNewer('0.1.1', '0.1'), isTrue);
      expect(UpdateService.isNewer('0.2.0-beta', '0.1.0'), isTrue);
    });
  });

  group('parseRelease', () {
    Map<String, dynamic> release(String tag, List<Map<String, String>> assets,
            {String? body}) =>
        {
          'tag_name': tag,
          'body': body,
          'assets': assets,
        };

    test('returns UpdateInfo when remote is newer and apk asset exists', () {
      final info = UpdateService.parseRelease(
        release('v0.2.0', [
          {'name': 'app-release.apk', 'browser_download_url': 'https://x/a.apk'},
        ], body: '  修复若干问题  '),
        currentVersion: '0.1.0',
      );
      expect(info, isNotNull);
      expect(info!.version, '0.2.0');
      expect(info.downloadUrl, 'https://x/a.apk');
      expect(info.releaseNotes, '修复若干问题');
    });

    test('returns null when already up to date', () {
      expect(
        UpdateService.parseRelease(
          release('v0.1.0', [
            {'name': 'a.apk', 'browser_download_url': 'https://x/a.apk'},
          ]),
          currentVersion: '0.1.0',
        ),
        isNull,
      );
    });

    test('returns null when release has no apk asset', () {
      expect(
        UpdateService.parseRelease(
          release('v0.2.0', [
            {'name': 'source.zip', 'browser_download_url': 'https://x/s.zip'},
          ]),
          currentVersion: '0.1.0',
        ),
        isNull,
      );
    });

    test('returns null on malformed payload', () {
      expect(
        UpdateService.parseRelease({'assets': []}, currentVersion: '0.1.0'),
        isNull,
      );
    });
  });

  test('parseRelease 优先 arm64 包，不依赖资产排序', () {
    final info = UpdateService.parseRelease({
      'tag_name': 'v9.9.9',
      'body': '',
      'assets': [
        // 通用包在前（字母序场景）
        {'name': 'app-release.apk', 'browser_download_url': 'https://x/universal.apk'},
        {'name': 'app-arm64-v8a-release.apk', 'browser_download_url': 'https://x/arm64.apk'},
      ],
    }, currentVersion: '1.0.0');
    expect(info!.downloadUrl, 'https://x/arm64.apk');
  });

  test('parseRelease 无 arm64 时回退通用包', () {
    final info = UpdateService.parseRelease({
      'tag_name': 'v9.9.9',
      'body': '',
      'assets': [
        {'name': 'app-release.apk', 'browser_download_url': 'https://x/universal.apk'},
      ],
    }, currentVersion: '1.0.0');
    expect(info!.downloadUrl, 'https://x/universal.apk');
  });
}
