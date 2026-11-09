class FinderFace {
  const FinderFace(this.left, this.top, this.width, this.height,
      {this.yaw, this.roll});
  final double left, top, width, height;
  final double? yaw, roll;
  factory FinderFace.fromMap(Map m) => FinderFace(
      (m['x'] as num).toDouble(),
      (m['y'] as num).toDouble(),
      (m['w'] as num).toDouble(),
      (m['h'] as num).toDouble(),
      yaw: (m['yaw'] as num?)?.toDouble(),
      roll: (m['roll'] as num?)?.toDouble());
}

class FinderAnalysis {
  const FinderAnalysis(
      {required this.id,
      required this.name,
      required this.relativePath,
      this.width = 0,
      this.height = 0,
      this.thumbnailPath = '',
      this.fingerprint = '',
      this.faces = const [],
      this.sharpness,
      this.brightness,
      this.skip});
  final String id, name, relativePath, thumbnailPath, fingerprint;
  final int width, height;
  final List<FinderFace> faces;
  final double? sharpness, brightness;
  final String? skip;
  factory FinderAnalysis.fromMap(Map m) => FinderAnalysis(
      id: m['id'] as String,
      name: m['name'] as String,
      relativePath: m['relativePath'] as String,
      width: (m['width'] as num?)?.toInt() ?? 0,
      height: (m['height'] as num?)?.toInt() ?? 0,
      thumbnailPath: m['thumbnailPath'] as String? ?? '',
      fingerprint: m['fingerprint'] as String? ?? '',
      faces: [
        for (final f in m['faces'] as List? ?? []) FinderFace.fromMap(f as Map)
      ],
      sharpness: (m['sharpness'] as num?)?.toDouble(),
      brightness: (m['brightness'] as num?)?.toDouble(),
      skip: m['skip'] as String?);
  FinderAnalysis withQuality(double sharpness, double brightness) =>
      FinderAnalysis(
          id: id,
          name: name,
          relativePath: relativePath,
          width: width,
          height: height,
          thumbnailPath: thumbnailPath,
          fingerprint: fingerprint,
          faces: faces,
          sharpness: sharpness,
          brightness: brightness,
          skip: skip);
}

enum FinderGroup { priority, manual, pixels, unknown }

class FinderCrop {
  const FinderCrop(this.outputName, this.left, this.top, this.width,
      this.height, this.pixelWidth, this.pixelHeight, this.fits);
  final String outputName;
  final double left, top, width, height;
  final int pixelWidth, pixelHeight;
  final bool fits;
}

class FinderCandidate {
  const FinderCandidate(this.analysis, this.group, this.reasons, this.crops,
      this.coverage, this.order);
  final FinderAnalysis analysis;
  final FinderGroup group;
  final List<String> reasons;
  final List<FinderCrop> crops;
  final int coverage;

  /// Heuristic ordering only; never presented as an acceptance probability.
  final double order;
}
