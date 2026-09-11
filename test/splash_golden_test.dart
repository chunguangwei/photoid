import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/pages/splash_page.dart';

/// 启动页吉祥物的视觉基线。
///
/// 这页全靠 `CustomPainter` 手绘，改坐标不会有任何编译/断言错误，
/// 只会「画歪」——只有 golden 能拦住。用 `--update-goldens` 更新基线前
/// 务必先肉眼看过产物。
void main() {
  testWidgets('splash mascot golden', (tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SplashPage(),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(SplashPage),
      matchesGoldenFile('goldens/splash_mascot.png'),
    );
  });
}
