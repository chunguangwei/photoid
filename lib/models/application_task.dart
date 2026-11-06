import 'dart:convert';
import 'photo_spec.dart';

String requirementFingerprint(PhotoSpec s) => jsonEncode([
      s.pixelWidth,
      s.pixelHeight,
      s.minWidth,
      s.maxWidth,
      s.minHeight,
      s.maxHeight,
      s.minRatio,
      s.maxRatio,
      s.minFileKb,
      s.maxFileKb,
      s.background.r,
      s.background.g,
      s.background.b
    ]);

class OutputRequirementSource {
  const OutputRequirementSource(
      {required this.excerpt,
      required this.evidenceRevision,
      required this.specFingerprint,
      required this.confirmed});
  final String excerpt, specFingerprint;
  final int evidenceRevision;
  final bool confirmed;
  Map<String, dynamic> toJson() => {
        'excerpt': excerpt,
        'evidenceRevision': evidenceRevision,
        'specFingerprint': specFingerprint,
        'confirmed': confirmed
      };
  factory OutputRequirementSource.fromJson(Map<String, dynamic> j) =>
      OutputRequirementSource(
          excerpt: j['excerpt'] as String,
          evidenceRevision: j['evidenceRevision'] as int,
          specFingerprint: j['specFingerprint'] as String,
          confirmed: j['confirmed'] as bool);
  OutputRequirementSource invalidate() => OutputRequirementSource(
      excerpt: excerpt,
      evidenceRevision: evidenceRevision,
      specFingerprint: specFingerprint,
      confirmed: false);
}

class ApplicationOutput {
  const ApplicationOutput(
      {required this.id,
      required this.spec,
      required this.fileName,
      this.revision = 0,
      this.ready = false,
      this.requirementSource});
  final String id;
  final PhotoSpec spec;
  final String fileName;
  final int revision;
  final bool ready;
  final OutputRequirementSource? requirementSource;
  Map<String, dynamic> toJson() => {
        'id': id,
        'spec': spec.toJson(),
        'fileName': fileName,
        'revision': revision,
        'ready': ready,
        if (requirementSource != null)
          'requirementSource': requirementSource!.toJson()
      };
  factory ApplicationOutput.fromJson(Map<String, dynamic> json) =>
      ApplicationOutput(
          id: json['id'] as String,
          spec: PhotoSpec.fromJson(json['spec'] as Map<String, dynamic>),
          fileName: json['fileName'] as String,
          revision: json['revision'] as int,
          ready: json['ready'] as bool,
          requirementSource: json['requirementSource'] == null
              ? null
              : OutputRequirementSource.fromJson(
                  json['requirementSource'] as Map<String, dynamic>));
}

class ApplicationTask {
  const ApplicationTask(
      {required this.id,
      required this.name,
      required this.updatedAt,
      this.notes = '',
      this.sourceReference = '',
      this.verifiedDate = '',
      this.hasSource = false,
      this.isDemo = false,
      this.hasEvidence = false,
      this.evidenceRevision = 0,
      this.sourceRevision = 0,
      this.outputs = const []});
  final String id, name, notes, sourceReference, verifiedDate;
  final DateTime updatedAt;
  final bool hasSource, hasEvidence, isDemo;
  final int sourceRevision;
  final int evidenceRevision;
  final List<ApplicationOutput> outputs;
  String tokenFor(ApplicationOutput output) =>
      '$sourceRevision:${output.revision}';
  bool get complete => outputs.isNotEmpty && outputs.every((o) => o.ready);
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'notes': notes,
        'sourceReference': sourceReference,
        'verifiedDate': verifiedDate,
        'updatedAt': updatedAt.toIso8601String(),
        'hasSource': hasSource,
        'isDemo': isDemo,
        'hasEvidence': hasEvidence,
        'evidenceRevision': evidenceRevision,
        'sourceRevision': sourceRevision,
        'outputs': outputs.map((o) => o.toJson()).toList()
      };
  factory ApplicationTask.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported task');
    }
    return ApplicationTask(
        id: j['id'] as String,
        name: j['name'] as String,
        notes: j['notes'] as String,
        sourceReference: j['sourceReference'] as String,
        verifiedDate: j['verifiedDate'] as String,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        hasSource: j['hasSource'] as bool,
        isDemo: j['isDemo'] as bool? ?? false,
        hasEvidence: j['hasEvidence'] as bool,
        evidenceRevision: (j['evidenceRevision'] as int?) ?? 0,
        sourceRevision: j['sourceRevision'] as int,
        outputs: (j['outputs'] as List)
            .map((v) => ApplicationOutput.fromJson(v as Map<String, dynamic>))
            .toList());
  }
}
