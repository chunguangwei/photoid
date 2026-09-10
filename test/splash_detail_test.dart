import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/pages/splash_page.dart';
import 'package:photoid/pages/spec_detail_page.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('启动页：倒计时+跳过按钮+广告占位渲染，点跳过离开', (tester) async {
    await tester.pumpWidget(_wrap(const SplashPage()));
    await tester.pump();
    final l = await AppLocalizations.delegate
        .load(const Locale('zh'));

    // 倒计时跳过按钮
    expect(find.text(l.splashSkip(6)), findsOneWidget);
    // 广告占位
    expect(find.text(l.splashAdPlaceholder), findsOneWidget);

    await tester.tap(find.text(l.splashSkip(6)));
    await tester.pumpAndSettle();
    // 离开后启动页不再存在
    expect(find.byType(SplashPage), findsNothing);
  });

  testWidgets('规格详情页：冲印尺寸/可设置大小/文件格式/背景色块渲染', (tester) async {
    const spec = PhotoSpec(
      id: 't1',
      name: '一寸',
      pixelWidth: 295,
      pixelHeight: 413,
      minFileKb: 0,
      maxFileKb: 0,
      minWidth: 295,
      maxWidth: 295,
      minHeight: 413,
      maxHeight: 413,
      minRatio: 1.3,
      maxRatio: 1.5,
      background: idPhotoBlue,
      requirements: ['免冠'],
    );
    await tester.pumpWidget(_wrap(const SpecDetailPage(spec: spec)));
    await tester.pump();
    final l = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(find.text(l.specPrintSize), findsOneWidget);
    // 295px@300DPI ≈ 25mm
    expect(find.text('25×35mm'), findsOneWidget);
    expect(find.text(l.specKbEditable), findsOneWidget);
    expect(find.text(l.specFileFormat), findsOneWidget);
    expect(find.text('JPG'), findsOneWidget);
  });

  testWidgets('可设置大小对话框：设置 KB 区间后行内显示更新', (tester) async {
    const spec = PhotoSpec(
      id: 't1',
      name: '一寸',
      pixelWidth: 295,
      pixelHeight: 413,
      minFileKb: 0,
      maxFileKb: 0,
      minWidth: 295,
      maxWidth: 295,
      minHeight: 413,
      maxHeight: 413,
      minRatio: 1.3,
      maxRatio: 1.5,
      background: idPhotoBlue,
    );
    await tester.pumpWidget(_wrap(const SpecDetailPage(spec: spec)));
    await tester.pump();
    final l = await AppLocalizations.delegate.load(const Locale('zh'));

    await tester.tap(find.text(l.specKbEditable));
    await tester.pumpAndSettle();
    // 输入 min/max 并确认
    await tester.enterText(
        find.widgetWithText(TextField, l.customMinKb), '20');
    await tester.enterText(
        find.widgetWithText(TextField, l.customMaxKb), '300');
    await tester.tap(find.text(l.confirm));
    await tester.pumpAndSettle();
    // 行内区间文本更新
    expect(find.text(l.specKbRange('20', '300')), findsOneWidget);
  });
}
