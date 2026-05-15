import 'package:flutter/foundation.dart';

class SvgValidationResult {
  const SvgValidationResult._({required this.valid, this.reason});

  factory SvgValidationResult.ok() => const SvgValidationResult._(valid: true);
  factory SvgValidationResult.fail(String reason) =>
      SvgValidationResult._(valid: false, reason: reason);

  final bool valid;
  final String? reason;
}

class SvgValidator {
  static const _shapeTags = [
    'circle', 'rect', 'ellipse', 'path', 'polygon', 'line', 'polyline',
  ];

  static SvgValidationResult validate(String topic, String svg) {
    final s = svg.trim();

    if (!s.startsWith('<svg') || !s.endsWith('</svg>')) {
      debugPrint('[SvgValidator] "$topic": not wrapped in <svg>…</svg>');
      return SvgValidationResult.fail('not wrapped in <svg>');
    }

    final vbMatch = RegExp(r'''viewBox\s*=\s*["']([^"']+)["']''').firstMatch(s);
    if (vbMatch == null) {
      debugPrint('[SvgValidator] "$topic": missing viewBox');
      return SvgValidationResult.fail('missing viewBox');
    }
    final parts = vbMatch.group(1)!.trim().split(RegExp(r'[\s,]+'));
    if (parts.length != 4 || parts.any((p) => double.tryParse(p) == null)) {
      debugPrint('[SvgValidator] "$topic": invalid viewBox "${vbMatch.group(1)}"');
      return SvgValidationResult.fail('viewBox must have exactly 4 numeric values');
    }

    int count = 0;
    for (final tag in _shapeTags) {
      count += RegExp('<$tag[\\s>/]').allMatches(s).length;
    }
    if (count < 3) {
      debugPrint('[SvgValidator] "$topic": too few shapes ($count < 3)');
      return SvgValidationResult.fail('too few shapes ($count, need ≥ 3)');
    }
    if (count > 30) {
      debugPrint('[SvgValidator] "$topic": too many shapes ($count > 30)');
      return SvgValidationResult.fail('too many shapes ($count, max 30)');
    }

    debugPrint('[SvgValidator] "$topic": valid ($count shapes)');
    return SvgValidationResult.ok();
  }
}
