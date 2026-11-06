/// OCR text is evidence, never an accepted specification.
class DimensionCandidate {
  const DimensionCandidate(this.width, this.height, this.excerpt,
      {this.ambiguous = true});
  final int width, height;
  final String excerpt;
  final bool ambiguous;
}

class SizeCandidate {
  const SizeCandidate(this.min, this.max, this.excerpt);
  final int? min, max;
  final String excerpt;
}

class RequirementsDraft {
  const RequirementsDraft(
      this.text, this.dimensions, this.sizes, this.backgrounds, this.warnings);
  final String text;
  final List<DimensionCandidate> dimensions;
  final List<SizeCandidate> sizes;
  final List<String> backgrounds, warnings;
}

RequirementsDraft parseRequirements(String text) {
  if (text.length > 100000) throw ArgumentError('Text exceeds limit');
  final dimensions = <DimensionCandidate>[];
  final sizes = <SizeCandidate>[];
  final warnings = <String>[];
  final normalized = text.replaceAll('：', ':');
  const unit = r'(?:px|pixels?|像素)';
  final explicit = RegExp(
      r'(?:width|宽(?:度)?)\s*:?\s*(\d{2,5})\s*' +
          unit +
          r'[^\d\n]{0,16}(?:height|高(?:度)?)\s*:?\s*(\d{2,5})\s*' +
          unit,
      caseSensitive: false);
  for (final m in explicit.allMatches(normalized)) {
    final context =
        normalized.substring(m.start > 28 ? m.start - 28 : 0, m.end);
    const qualifier =
        r'minimum|maximum|at least|at most|no more than|no less than|最小|最大|至少|至多|不超过|不少于|不低于|不高于|以上|以下|以内|以外|[<>≤≥]';
    final trailing = normalized.substring(
        m.end, m.end + 24 < normalized.length ? m.end + 24 : normalized.length);
    if (RegExp(r'(?:' + qualifier + r'|min|max)\s*(?:width|height|宽|高)',
                caseSensitive: false)
            .hasMatch(context) ||
        RegExp(qualifier, caseSensitive: false).hasMatch(m[0]!) ||
        RegExp(r'^\s*(?:' + qualifier + r')', caseSensitive: false)
            .hasMatch(trailing)) {
      if (!warnings.contains('bounds')) warnings.add('bounds');
      continue;
    }
    dimensions.add(DimensionCandidate(int.parse(m[1]!), int.parse(m[2]!), m[0]!,
        ambiguous: false));
  }
  final pairs = RegExp(
      r'(?<![\d.,+\-–—])(\d{2,5})\s*[x×*]\s*(\d{2,5})\s*' + unit,
      caseSensitive: false);
  for (final m in pairs.allMatches(normalized)) {
    dimensions
        .add(DimensionCandidate(int.parse(m[1]!), int.parse(m[2]!), m[0]!));
  }
  final ranges = RegExp(
      r'(?<![\d.,+\-–—])(\d{1,5})\s*(?:KB|KiB)?\s*[-–—~至到]\s*(\d{1,5})\s*(?:KB|KiB)(?![A-Za-z])',
      caseSensitive: false);
  for (final m in ranges.allMatches(normalized)) {
    sizes.add(SizeCandidate(int.parse(m[1]!), int.parse(m[2]!), m[0]!));
  }
  final max = RegExp(
      r'(?:不超过|小于等于|至多|最多|上限|no more than|at most|max(?:imum)?|<=|≤)\s*:?\s*(\d{1,5})\s*(?:KB|KiB)(?![A-Za-z])',
      caseSensitive: false);
  for (final m in max.allMatches(normalized)) {
    sizes.add(SizeCandidate(null, int.parse(m[1]!), m[0]!));
  }
  final min = RegExp(
      r'(?:不少于|至少|下限|at least|min(?:imum)?|>=|≥)\s*:?\s*(\d{1,5})\s*(?:KB|KiB)(?![A-Za-z])',
      caseSensitive: false);
  for (final m in min.allMatches(normalized)) {
    sizes.add(SizeCandidate(int.parse(m[1]!), null, m[0]!));
  }
  final backgrounds = <String>[];
  for (final entry in {
    'blue': r'蓝(?:色)?(?:底|背景)|\bblue\b\s*(?:background)?',
    'white': r'白(?:色)?(?:底|背景)|\bwhite\b\s*(?:background)?',
    'red': r'红(?:色)?(?:底|背景)|\bred\b\s*(?:background)?',
    'gray': r'灰(?:色)?(?:底|背景)|\bgr[ae]y\b\s*(?:background)?'
  }.entries) {
    if (RegExp(entry.value, caseSensitive: false).hasMatch(normalized)) {
      backgrounds.add(entry.key);
    }
  }
  if (RegExp(r'\b(?:mm|cm|dpi|mb)\b|毫米|厘米|兆', caseSensitive: false)
          .hasMatch(normalized) ||
      RegExp(r'\d\s*(?:mm|cm|mb)', caseSensitive: false).hasMatch(normalized)) {
    warnings.add('units');
  }
  if (RegExp(r'\b(?:png|heic|webp|pdf|gif)\b', caseSensitive: false)
      .hasMatch(normalized)) {
    warnings.add('format');
  }
  return RequirementsDraft(text, dimensions, sizes, backgrounds, warnings);
}
