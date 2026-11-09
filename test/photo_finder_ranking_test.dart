import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/services/photo_finder_models.dart';
import 'package:photoid/services/photo_finder_ranking.dart';
import 'package:photoid/models/application_task.dart';
import 'package:photoid/services/demo_task.dart';
import 'package:photoid/models/photo_spec.dart';

void main() {
  final outputs = [
    ApplicationOutput(
        id: 'a',
        fileName: 'main',
        spec: DemoTask.spec('Main', 480, 640, 20, 100, idPhotoBlue))
  ];
  FinderAnalysis image({List<FinderFace>? faces, int w = 2000, int h = 3000}) =>
      FinderAnalysis(
          id: 'one',
          name: 'one.jpg',
          relativePath: 'one.jpg',
          width: w,
          height: h,
          thumbnailPath: 'thumb',
          fingerprint: 'sha',
          faces: faces ?? [const FinderFace(.3, .2, .4, .4, yaw: 0, roll: 0)],
          sharpness: 100,
          brightness: 125);
  test('single frontal face with enough crop pixels is a priority reference',
      () {
    final c = evaluatePhoto(image(), outputs);
    expect(c.group, FinderGroup.priority);
    expect(c.coverage, 1);
    expect(c.crops.single.fits, true);
    expect(c.crops.single.left, greaterThanOrEqualTo(0));
    expect(
        c.crops.single.top + c.crops.single.height, lessThanOrEqualTo(1.0001));
  });
  test('multiple, missing poses and no faces never become confident portraits',
      () {
    expect(
        evaluatePhoto(
                image(faces: [
                  const FinderFace(.1, .2, .3, .3, yaw: 0, roll: 0),
                  const FinderFace(.5, .2, .3, .3, yaw: 0, roll: 0)
                ]),
                outputs)
            .group,
        FinderGroup.manual);
    expect(
        evaluatePhoto(image(faces: [const FinderFace(.3, .2, .4, .4)]), outputs)
            .reasons,
        contains('poseUnknown'));
    final none = evaluatePhoto(image(faces: []), outputs);
    expect(none.group, FinderGroup.unknown);
    expect(none.reasons, contains('noFaceDetected'));
  });
  test('crop resolution, not source KB, decides pixel coverage', () {
    final c = evaluatePhoto(image(w: 200, h: 300), outputs);
    expect(c.group, FinderGroup.pixels);
    expect(c.coverage, 0);
  });
  test('edge faces get clamped crops and every output has its own estimate',
      () {
    final all = [
      ...outputs,
      ApplicationOutput(
          id: 'b',
          fileName: 'large',
          spec: DemoTask.spec('Large', 2000, 2000, 0, 0, idPhotoBlue))
    ];
    final c = evaluatePhoto(
        image(faces: [const FinderFace(.88, .01, .1, .1, yaw: 0, roll: 0)]),
        all);
    expect(c.crops.length, 2);
    for (final crop in c.crops) {
      expect(crop.left, greaterThanOrEqualTo(0));
      expect(crop.top, greaterThanOrEqualTo(0));
      expect(crop.left + crop.width, lessThanOrEqualTo(1.00001));
    }
  });
  test('invalid extra face or non-finite pose cannot turn into priority', () {
    expect(
        evaluatePhoto(
                image(faces: [
                  const FinderFace(.3, .2, .4, .4, yaw: 0, roll: 0),
                  const FinderFace(double.nan, .2, .1, .1, yaw: 0, roll: 0),
                ]),
                outputs)
            .group,
        isNot(FinderGroup.priority));
    expect(
        evaluatePhoto(
                image(faces: [
                  const FinderFace(.3, .2, .4, .4, yaw: double.nan, roll: 0)
                ]),
                outputs)
            .group,
        isNot(FinderGroup.priority));
    expect(evaluatePhoto(image(), []).group, isNot(FinderGroup.priority));
  });
  test('a pixel-rich crop that cuts a wide face is not priority', () {
    final candidate = evaluatePhoto(
        image(
            w: 3000,
            h: 2000,
            faces: [const FinderFace(.1, .2, .8, .4, yaw: 0, roll: 0)]),
        outputs);
    expect(candidate.coverage, 1);
    expect(candidate.group, FinderGroup.manual);
    expect(candidate.reasons, contains('cropFraming'));
  });
  test('native unknown/oversized results stay distinct from bad portraits', () {
    final a = FinderAnalysis.fromMap({
      'id': 'a',
      'name': 'huge.jpg',
      'relativePath': 'huge.jpg',
      'skip': 'oversized'
    });
    expect(evaluatePhoto(a, outputs).reasons, ['oversized']);
    expect(a.width, 0);
  });
}
