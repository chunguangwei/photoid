import 'dart:convert';
import 'dart:typed_data';

import '../models/photo_spec.dart';
import 'compliance_service.dart';

/// A portable record of this file's checks, not institutional certification.
String buildDeliveryReport(
        {required String fileName,
        required Uint8List jpgBytes,
        required PhotoSpec spec,
        required ComplianceReport report}) =>
    const JsonEncoder.withIndent('  ').convert({
      'reportVersion': 1,
      'file': {
        'name': fileName,
        'bytes': jpgBytes.lengthInBytes,
        'kilobytes': jpgBytes.lengthInBytes / 1024,
        'format': 'JPEG'
      },
      'requestedSpecification': spec.toJson(),
      'checks': [
        for (final item in report.items)
          {
            'id': item.id,
            'passed': item.pass,
            'advisory': item.soft,
            if (item.detail != null) 'measured': item.detail,
            if (!item.pass && item.fixId != null) 'suggestion': item.fixId,
          }
      ],
      'acceptanceGuaranteed': false,
      'note': 'File checks and general framing estimates only. Not government '
          'certification. Verify current requirements with the receiving organization.',
    });
