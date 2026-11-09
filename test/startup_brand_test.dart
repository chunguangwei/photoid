import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/splash_page.dart';
import 'application_workflow_test.dart' show host;

void main() {
  testWidgets('brand intro is visible once and completes promptly',
      (tester) async {
    await tester.pumpWidget(host(const SplashPage()));
    expect(find.byKey(const Key('brand-intro')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('brand-intro')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brand-intro')), findsNothing);
    expect(find.text('Application tasks'), findsOneWidget);
  });
  testWidgets('continue immediately dismisses brand intro', (tester) async {
    await tester.pumpWidget(host(const SplashPage()));
    await tester.tap(find.byKey(const Key('startup-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brand-intro')), findsNothing);
    expect(find.text('Application tasks'), findsOneWidget);
  });
  testWidgets('reduce motion immediately shows home', (tester) async {
    await tester.pumpWidget(host(const MediaQuery(
        data: MediaQueryData(disableAnimations: true), child: SplashPage())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('brand-intro')), findsNothing);
    expect(find.text('Application tasks'), findsOneWidget);
  });
}
