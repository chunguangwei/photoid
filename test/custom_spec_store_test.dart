import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/services/custom_spec_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PhotoSpec _spec(String id, String name) => PhotoSpec(
      id: id,
      name: name,
      pixelWidth: 480,
      pixelHeight: 640,
      minFileKb: 10,
      maxFileKb: 500,
      minWidth: 480,
      maxWidth: 480,
      minHeight: 640,
      maxHeight: 640,
      minRatio: 1.3,
      maxRatio: 1.4,
      background: idPhotoBlue,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('保存后可读取，JSON 往返字段完整', () async {
    await CustomSpecStore.save(_spec('c1', '测试规格'));
    final list = await CustomSpecStore.load();
    expect(list.length, 1);
    expect(list.first.name, '测试规格');
    expect(list.first.pixelWidth, 480);
    expect(list.first.background.name, '蓝底');
  });

  test('同名同尺寸去重：新覆盖旧', () async {
    await CustomSpecStore.save(_spec('c1', '同名'));
    await CustomSpecStore.save(_spec('c2', '同名'));
    final list = await CustomSpecStore.load();
    expect(list.length, 1);
    expect(list.first.id, 'c2');
  });

  test('删除按 id 生效', () async {
    await CustomSpecStore.save(_spec('c1', '甲'));
    await CustomSpecStore.save(_spec('c2', '乙'));
    await CustomSpecStore.delete('c1');
    final list = await CustomSpecStore.load();
    expect(list.length, 1);
    expect(list.first.id, 'c2');
  });

  test('脏数据返回空列表不崩', () async {
    SharedPreferences.setMockInitialValues({'custom_specs': '{broken'});
    expect(await CustomSpecStore.load(), isEmpty);
  });
}
