import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/glass_preferences.dart';
import 'package:photoid/widgets/glass_surface.dart';

void main() {
  for (final (name, highContrast, reduceTransparency) in [
    ('default glass', false, false),
    ('high contrast', true, false),
    ('reduced transparency', false, true),
  ]) {
    testWidgets('$name keeps controls usable and respects opacity preferences',
        (tester) async {
      GlassPreferences.reduceTransparency.value = reduceTransparency;
      addTearDown(() => GlassPreferences.reduceTransparency.value = false);
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(highContrast: highContrast),
        child: Scaffold(
            body: GlassSurface(
          child: TextButton(
              onPressed: () => tapped = true, child: const Text('Continue')),
        )),
      )));
      expect(find.byType(BackdropFilter),
          highContrast || reduceTransparency ? findsNothing : findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(tapped, isTrue);
    });
  }
}
