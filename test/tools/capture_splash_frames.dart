import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/pages/splash_page.dart';

/// 开发工具（**不是回归测试**）：把启动页动画按 20fps 抓成连续帧，
/// 供 ffmpeg 合成预览 GIF / MP4，用来在不装真机的情况下审动效节奏。
///
/// 文件名刻意**不带 `_test` 后缀**——否则 `flutter test` 全量跑时会把它
/// 也带上，白白多花 40 多秒去写 80 多张 PNG。需要时显式指定路径运行：
///
/// ```bash
/// flutter test test/tools/capture_splash_frames.dart --update-goldens
/// cd /tmp/splash_frames
/// # GIF（体积大、任何地方都能看）
/// ffmpeg -y -framerate 20 -i f%03d.png \
///   -vf "scale=390:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" \
///   -loop 0 /tmp/photoid-splash.gif
/// # MP4（体积约 GIF 的 1/20，便于分享）
/// ffmpeg -y -framerate 20 -i f%03d.png \
///   -vf "scale=440:-1:flags=lanczos,format=yuv420p" \
///   -c:v libx264 -crf 20 -movflags +faststart /tmp/photoid-splash.mp4
/// ```
///
/// 产物写到 `/tmp`，不入库。
void main() {
  testWidgets('capture splash frames', (tester) async {
    // 抓 4.2 秒：主序列 3.6s 跑完后多留 0.6s 定格
    const fps = 20;
    const totalMs = 4200;
    const stepMs = 1000 ~/ fps;

    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SplashPage(),
    ));

    final dir = Directory('/tmp/splash_frames');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    for (var i = 0; i * stepMs < totalMs; i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
      await expectLater(
        find.byType(SplashPage),
        matchesGoldenFile(
            '/tmp/splash_frames/f${i.toString().padLeft(3, '0')}.png'),
      );
    }
  });
}
