import 'photo_spec.dart';

class ApplicationOutput {
  const ApplicationOutput(
      {required this.id,
      required this.spec,
      required this.fileName,
      this.revision = 0,
      this.ready = false});
  final String id;
  final PhotoSpec spec;
  final String fileName;
  final int revision;
  final bool ready;
  Map<String, dynamic> toJson() => {
        'id': id,
        'spec': spec.toJson(),
        'fileName': fileName,
        'revision': revision,
        'ready': ready
      };
  factory ApplicationOutput.fromJson(Map<String, dynamic> json) =>
      ApplicationOutput(
          id: json['id'] as String,
          spec: PhotoSpec.fromJson(json['spec'] as Map<String, dynamic>),
          fileName: json['fileName'] as String,
          revision: json['revision'] as int,
          ready: json['ready'] as bool);
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
      this.hasEvidence = false,
      this.evidenceRevision = 0,
      this.sourceRevision = 0,
      this.outputs = const []});
  final String id, name, notes, sourceReference, verifiedDate;
  final DateTime updatedAt;
  final bool hasSource, hasEvidence;
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
        hasEvidence: j['hasEvidence'] as bool,
        evidenceRevision: (j['evidenceRevision'] as int?) ?? 0,
        sourceRevision: j['sourceRevision'] as int,
        outputs: (j['outputs'] as List)
            .map((v) => ApplicationOutput.fromJson(v as Map<String, dynamic>))
            .toList());
  }
}
