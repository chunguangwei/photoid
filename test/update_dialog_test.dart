import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/l10n/app_localizations.dart';
import 'package:photoid/pages/update_dialog.dart';
import 'package:photoid/services/update_service.dart';

const _optional = UpdateInfo(
  version: '0.2.0',
  downloadUrl: 'https://example.invalid/a.apk',
  releaseNotes: 'RELEASE_NOTES_MARKER',
  isForceUpdate: false,
);

const _forced = UpdateInfo(
  version: '0.2.0',
  downloadUrl: 'https://example.invalid/a.apk',
  releaseNotes: '',
  isForceUpdate: true,
);

/// 用与 main.dart 相同的方式（MaterialApp.navigatorKey 指向的 context）弹框，
/// 覆盖真实调用路径上 Localizations 祖先可用的前提。
Future<AppLocalizations> _show(
  WidgetTester tester,
  UpdateInfo info,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  showUpdateDialog(navigatorKey.currentContext!, info);
  await tester.pump();
  return l10n;
}

void main() {
  testWidgets('shows localized title, version and release notes',
      (tester) async {
    final l = await _show(tester, _optional);

    expect(find.text(l.updateTitle), findsOneWidget);
    expect(find.text('v0.2.0'), findsOneWidget);
    expect(find.text('RELEASE_NOTES_MARKER'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, l.updateLater))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, l.updateNow))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('稍后 dismisses the dialog', (tester) async {
    final l = await _show(tester, _optional);

    await tester.tap(find.text(l.updateLater));
    await tester.pumpAndSettle();
    expect(find.text(l.updateTitle), findsNothing);
  });

  testWidgets('立即更新 switches to downloading state', (tester) async {
    // 测试环境没有 path_provider 插件，下载不会完成；只验证进入下载态：
    // 进度指示出现、「立即更新」禁用、「稍后」隐藏。
    final l = await _show(tester, _optional);

    await tester.tap(find.text(l.updateNow));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, l.updateNow))
          .onPressed,
      isNull,
    );
    expect(find.text(l.updateLater), findsNothing);
  });

  testWidgets('force update disables 稍后 and hides empty notes', (tester) async {
    final l = await _show(tester, _forced);

    // releaseNotes 为空：不渲染可滚动的说明区块
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, l.updateLater))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, l.updateNow))
          .onPressed,
      isNotNull,
    );
  });
}
