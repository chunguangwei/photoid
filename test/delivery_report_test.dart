import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photoid/models/photo_spec.dart';
import 'package:photoid/services/compliance_service.dart';
import 'package:photoid/services/delivery_report.dart';

void main() {
  test(
      'delivery report records actual byte count and distinguishes advisory failures',
      () {
    final report = ComplianceReport([
      const CheckItem('pixelSize', true, detail: '480×640'),
      const CheckItem('eyesOpen', false, soft: true, fixId: 'eyesClosed'),
    ]);
    final data = jsonDecode(buildDeliveryReport(
      fileName: 'applicant_123.jpg',
      jpgBytes: Uint8List(12500),
      spec: studentPhotoSpec,
      report: report,
    )) as Map<String, dynamic>;
    expect(data['file']['bytes'], 12500);
    expect(data['file']['name'], 'applicant_123.jpg');
    expect(data['checks'][1]['passed'], isFalse);
    expect(data['checks'][1]['advisory'], isTrue);
    expect(data['acceptanceGuaranteed'], isFalse);
  });
}
