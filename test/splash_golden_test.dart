import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/pages/splash_page.dart';

/// 启动页「Logo 自我组装」序列的视觉基线。
///
/// 这页全靠 `CustomPainter` 手绘，改坐标不会有任何编译或断言错误，只会
/// 「画歪」——只有 golden 拦得住。而且它是一段**四拍动画**，单帧截图证明
/// 不了序列是对的，所以这里按拍抓四帧分别存基线。
///
/// 更新基线：`flutter test --update-goldens`，提交前务必**肉眼看过**产物。
///
/// 注意产物里品牌名会渲染成一串实心方块——`flutter_test` 默认加载的是
/// Ahem 测试字体（所有字形都是方块），真机上显示正常。**这不是 bug**，
/// 所以这几张 golden 只用于校验几何与动画时序，字体外观不在其覆盖范围内。
void main() {
  // 主序列 _stage 全长 3600ms，四拍的时间切片见 _BrandPainter
  const shots = <(String, int)>[
    ('01_corners', 600), // ① 取景框四角滑入到位，轮廓刚起笔
    ('02_outline', 900), // ② 轮廓描边完成（累计 1500ms）
    ('03_scan', 600), // ③ 扫描光带推进中（累计 2100ms）
    ('04_done', 1400), // ④ 徽章弹入 + 打勾，定格（累计 3500ms）
  ];

  testWidgets('splash brand sequence goldens', (tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SplashPage(),
    ));

    for (final (name, advanceMs) in shots) {
      await tester.pump(Duration(milliseconds: advanceMs));
      await expectLater(
        find.byType(SplashPage),
        matchesGoldenFile('goldens/splash_$name.png'),
      );
    }
  });
}
