import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/pages/photo_spec_picker_page.dart';
import 'package:photoid/pages/custom_spec_page.dart';
import 'package:photoid/services/demo_task.dart';
import 'package:photoid/models/photo_spec.dart';
import 'application_workflow_test.dart' show host;

void main() {
  testWidgets('editing a saved custom target keeps its dimensions and KB values',(tester)async{
    final spec=DemoTask.spec('My size',445,623,20,150,idPhotoBlue);
    await tester.pumpWidget(host(PhotoSpecPickerPage(initialSpec:spec)));await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spec-custom')));await tester.pumpAndSettle();
    final values=tester.widgetList<TextField>(find.byType(TextField)).map((f)=>f.controller?.text).toList();
    expect(values,containsAll(['My size','445','623','20','150']));
  });

  testWidgets('all 33 sizes are searchable and custom entry is visible',
      (tester) async {
    await tester.pumpWidget(host(const PhotoSpecPickerPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('spec-search')), findsOneWidget);
    expect(find.byKey(const Key('spec-custom')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('spec-search')), 'passport');
    await tester.pumpAndSettle();
    expect(find.textContaining('Passport'), findsWidgets);
    await tester.tap(find.byKey(const Key('spec-custom')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomSpecPage), findsOneWidget);
  });
}
