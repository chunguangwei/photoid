import 'dart:io';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photoid/pages/photo_check_page.dart';
import 'application_workflow_test.dart' show host, settleFiles;
import 'photo_file_inspection_test.dart' show requirement;

class SelectedFile extends FileSelectorPlatform {
  SelectedFile(this.path);
  final String? path;
  @override
  Future<XFile?> openFile(
          {List<XTypeGroup>? acceptedTypeGroups,
          String? initialDirectory,
          String? confirmButtonText}) async =>
      path == null ? null : XFile(path!);
}

void main() {
  late Directory dir;
  late File photo;
  late FileSelectorPlatform previous;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('existing_photo_');
    photo = File('${dir.path}/unchanged.jpg');
    await photo.writeAsBytes(img.encodeJpg(img.Image(width: 100, height: 140)));
    previous = FileSelectorPlatform.instance;
  });
  tearDown(() async {
    FileSelectorPlatform.instance = previous;
    await dir.delete(recursive: true);
  });
  testWidgets(
      'check selected Files bytes and cancelling picker preserves prior selection',
      (tester) async {
    FileSelectorPlatform.instance = SelectedFile(photo.path);
    final before = await tester.runAsync(() => photo.readAsBytes());
    await tester.pumpWidget(host(PhotoCheckPage(initialSpec: requirement())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose photo file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo file'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Files'));
    await settleFiles(tester);
    await tester.ensureVisible(find.text('Check selected file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check selected file'));
    await settleFiles(tester);
    await tester.scrollUntilVisible(
        find.text('Selected file properties match'), 150);
    expect(find.text('Selected file properties match'), findsOneWidget);
    expect(await tester.runAsync(() => photo.readAsBytes()), before);
    FileSelectorPlatform.instance = SelectedFile(null);
    await tester.ensureVisible(find.text('Choose photo file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo file'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Files'));
    await settleFiles(tester);
    await tester.scrollUntilVisible(find.text('unchanged.jpg'), -150);
    expect(find.text('unchanged.jpg'), findsOneWidget);
  });
}
