import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/splash_page.dart';
import 'application_workflow_test.dart' show host;

void main() {
  testWidgets('startup has no timer gate and exposes home actions',
      (tester) async {
    await tester.pumpWidget(host(const SplashPage()));
    await tester.pumpAndSettle();
    expect(find.text('Application tasks'), findsOneWidget);
    expect(find.text('Try a demo task'), findsOneWidget);
    expect(
        find
            .byType(TextButton)
            .evaluate()
            .any((e) => e.widget.toString().contains('Skip')),
        false);
  });
}
