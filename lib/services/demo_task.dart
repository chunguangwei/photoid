import 'package:flutter/services.dart';
import '../models/application_task.dart';
import '../models/photo_spec.dart';
import 'application_task_store.dart';

class DemoTask {
  static PhotoSpec spec(
          String name, int w, int h, int min, int max, SpecBackground bg) =>
      PhotoSpec(
          id: 'demo_$name',
          name: name,
          nameEn: name,
          pixelWidth: w,
          pixelHeight: h,
          minFileKb: min,
          maxFileKb: max,
          minWidth: w,
          maxWidth: w,
          minHeight: h,
          maxHeight: h,
          minRatio: h / w - 0.05,
          maxRatio: h / w + 0.05,
          background: bg);
  static Future<ApplicationTask> open(
      ApplicationTaskStore store, String locale) async {
    final source = await rootBundle.load('assets/demo/portrait.jpg');
    final evidence = await rootBundle.load('assets/demo/requirements.png');
    return store.createDemo(
        name: locale == 'zh' ? '示例 · 报名照片' : 'Demo · Application photos',
        notes: locale == 'zh'
            ? '虚构演示要求，并非机构标准。确认两份要求 → 分别制作 → 核对并导出。'
            : 'Fictional requirements, not an institution standard. Confirm both requirements → prepare each file → review and export.',
        source: source.buffer
            .asUint8List(source.offsetInBytes, source.lengthInBytes),
        evidence: evidence.buffer
            .asUint8List(evidence.offsetInBytes, evidence.lengthInBytes),
        outputs: [
          (spec('Main', 480, 640, 20, 100, idPhotoBlue), 'photo_main'),
          (
            spec('Profile', 300, 400, 10, 100,
                const SpecBackground('white', 255, 255, 255)),
            'photo_profile'
          )
        ]);
  }
}
