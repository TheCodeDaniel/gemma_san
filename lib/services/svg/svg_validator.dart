import 'package:flutter/foundation.dart';

class SvgValidationResult {
  const SvgValidationResult._({required this.valid, this.reason, this.sanitizedSvg});

  factory SvgValidationResult.ok({String? sanitized}) =>
      SvgValidationResult._(valid: true, sanitizedSvg: sanitized);
  factory SvgValidationResult.fail(String reason) =>
      SvgValidationResult._(valid: false, reason: reason);

  final bool valid;
  final String? reason;

  /// Non-null when the SVG was auto-corrected. Always prefer this over the
  /// original raw string when rendering.
  final String? sanitizedSvg;
}

class SvgValidator {
  static const _shapeTags = [
    'circle', 'rect', 'ellipse', 'path', 'polygon', 'line', 'polyline',
  ];

  static SvgValidationResult validate(String topic, String svg) {
    var s = svg.trim();
    var changed = false;

    if (!s.startsWith('<svg') || !s.endsWith('</svg>')) {
      debugPrint('[SvgValidator] "$topic": not wrapped in <svg>…</svg>');
      return SvgValidationResult.fail('not wrapped in <svg>');
    }

    // ── Fix 1: normalise a garbled xmlns URL ──────────────────────────────────
    // E4B sometimes generates "http://www.w3.3.org/20000/svg" etc.
    if (!s.contains('http://www.w3.org/2000/svg')) {
      s = s.replaceAll(
        RegExp(r'xmlns="[^"]*"'),
        'xmlns="http://www.w3.org/2000/svg"',
      );
      changed = true;
      debugPrint('[SvgValidator] "$topic": xmlns normalised');
    }

    // ── Fix 2: normalise the viewBox ──────────────────────────────────────────
    final vbMatch = RegExp(r'''viewBox\s*=\s*["']([^"']+)["']''').firstMatch(s);
    if (vbMatch == null) {
      debugPrint('[SvgValidator] "$topic": missing viewBox');
      return SvgValidationResult.fail('missing viewBox');
    }

    final rawVb = vbMatch.group(1)!.trim();
    final numbers = RegExp(r'[\d.]+')
        .allMatches(rawVb)
        .map((m) => double.tryParse(m.group(0)!) ?? -1)
        .where((n) => n >= 0)
        .toList();

    if (numbers.length < 4) {
      debugPrint('[SvgValidator] "$topic": invalid viewBox "$rawVb"');
      return SvgValidationResult.fail('viewBox must have 4 numeric values');
    }

    // Strip extra numbers (e.g. "0 0 20 20 20" → "0 0 20 20"), and normalise
    // small canvases to 200×200 so shapes aren't invisible.
    final vbW = numbers[2];
    final vbH = numbers[3];
    if (numbers.length != 4 || vbW < 100 || vbH < 100) {
      s = s.replaceFirst(vbMatch.group(0)!, 'viewBox="0 0 200 200"');
      changed = true;
      debugPrint('[SvgValidator] "$topic": viewBox fixed "$rawVb" → "0 0 200 200"');
    }

    // ── Shape count ───────────────────────────────────────────────────────────
    int count = 0;
    for (final tag in _shapeTags) {
      count += RegExp('<$tag[\\s>/]').allMatches(s).length;
    }
    if (count < 2) {
      debugPrint('[SvgValidator] "$topic": too few shapes ($count < 2)');
      return SvgValidationResult.fail('too few shapes ($count, need ≥ 2)');
    }
    if (count > 30) {
      debugPrint('[SvgValidator] "$topic": too many shapes ($count > 30)');
      return SvgValidationResult.fail('too many shapes ($count, max 30)');
    }

    // ── Fix 3: fill/stroke auto-inject ────────────────────────────────────────
    // Gemma sometimes emits shapes with valid coords but no fill/stroke at all —
    // they render structurally correct but invisible. Auto-inject a default so
    // the drawing is renderable instead of rejecting the whole SVG.
    final patched = _injectMissingFills(s);
    if (patched != s) {
      s = patched;
      changed = true;
      debugPrint('[SvgValidator] "$topic": auto-injected fill on bare shapes');
    }

    // ── Fix 4: visibility check ───────────────────────────────────────────────
    // The model sometimes generates r="1" or width="4" on every shape — valid
    // XML but renders as invisible specks. Reject if nothing is large enough to see.
    if (!_hasVisibleShape(s)) {
      debugPrint('[SvgValidator] "$topic": all shapes degenerate (too small to see)');
      return SvgValidationResult.fail('all shapes too small to see');
    }

    // ── Fix 5: compressed-coord check ─────────────────────────────────────────
    // Under thinking mode the model sometimes uses a 0–20 coord space even
    // though viewBox is 0–200 — shapes cluster in the top-left corner and the
    // drawing renders as a tiny speck. Reject if the bounding span of all
    // shapes is < 30% of the viewBox dimension (60 of 200).
    if (_coordsAreCompressed(s)) {
      debugPrint('[SvgValidator] "$topic": shapes compressed to a corner — not visually useful');
      return SvgValidationResult.fail('shapes compressed to a corner');
    }

    debugPrint('[SvgValidator] "$topic": valid ($count shapes${changed ? ", auto-fixed" : ""})');
    return SvgValidationResult.ok(sanitized: changed ? s : null);
  }

  /// True when every shape's coordinates fit in <30% of the (assumed 200×200)
  /// viewBox, meaning the drawing renders as a clump in one corner instead of
  /// using the full canvas.
  static bool _coordsAreCompressed(String s) {
    final xs = <double>[];
    final ys = <double>[];

    void addRect(String attrs) {
      final x = _numAttr(attrs, 'x');
      final y = _numAttr(attrs, 'y');
      final w = _numAttr(attrs, 'width');
      final h = _numAttr(attrs, 'height');
      if (x != null) xs.add(x);
      if (y != null) ys.add(y);
      if (x != null && w != null) xs.add(x + w);
      if (y != null && h != null) ys.add(y + h);
    }

    void addCircle(String attrs) {
      final cx = _numAttr(attrs, 'cx');
      final cy = _numAttr(attrs, 'cy');
      final r = _numAttr(attrs, 'r') ?? _numAttr(attrs, 'rx') ?? 0;
      if (cx != null) {
        xs.add(cx - r);
        xs.add(cx + r);
      }
      if (cy != null) {
        ys.add(cy - r);
        ys.add(cy + r);
      }
    }

    void addLine(String attrs) {
      for (final k in const ['x1', 'x2']) {
        final v = _numAttr(attrs, k);
        if (v != null) xs.add(v);
      }
      for (final k in const ['y1', 'y2']) {
        final v = _numAttr(attrs, k);
        if (v != null) ys.add(v);
      }
    }

    void addPolygon(String attrs) {
      final pts = RegExp(r'[\d.]+').allMatches(attrs).map((m) => double.tryParse(m.group(0)!) ?? -1).where((n) => n >= 0).toList();
      for (var i = 0; i + 1 < pts.length; i += 2) {
        xs.add(pts[i]);
        ys.add(pts[i + 1]);
      }
    }

    for (final m in RegExp(r'<rect\b([^>]*)>?').allMatches(s)) {
      addRect(m.group(1)!);
    }
    for (final m in RegExp(r'<(?:circle|ellipse)\b([^>]*)>?').allMatches(s)) {
      addCircle(m.group(1)!);
    }
    for (final m in RegExp(r'<line\b([^>]*)>?').allMatches(s)) {
      addLine(m.group(1)!);
    }
    for (final m in RegExp(r'<polygon\b([^>]*)>?').allMatches(s)) {
      addPolygon(m.group(1)!);
    }

    if (xs.isEmpty || ys.isEmpty) return false;

    final spanX = xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
    final spanY = ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b);

    // viewBox is normalised to 0–200 by Fix 2 above. 60 = 30% of 200.
    const minSpan = 60.0;
    return spanX < minSpan && spanY < minSpan;
  }

  /// Inject `fill="#444"` (or `stroke="#444"` for lines) on shapes that have
  /// neither attribute, OR have `fill="none"` with no stroke. Prevents
  /// "valid coordinates, no color" SVGs from rendering blank.
  static String _injectMissingFills(String svg) {
    return svg.replaceAllMapped(
      RegExp(r'<(rect|circle|ellipse|polygon|line)\b([^>]*?)(/?)>'),
      (m) {
        final tag = m.group(1)!;
        final attrs = m.group(2)!;
        final selfClose = m.group(3)!;
        if (_hasFillOrStroke(attrs)) return m.group(0)!;
        final inject = tag == 'line'
            ? ' stroke="#444" stroke-width="2"'
            : ' fill="#444"';
        return '<$tag$attrs$inject$selfClose>';
      },
    );
  }

  /// True when the attribute string contains a meaningful fill or stroke
  /// (not `fill="none"` on its own).
  static bool _hasFillOrStroke(String attrs) {
    final hasFill = RegExp(r'\bfill\s*=\s*"([^"]+)"').firstMatch(attrs);
    final hasStroke = RegExp(r'\bstroke\s*=\s*"([^"]+)"').firstMatch(attrs);
    final fillValid = hasFill != null && hasFill.group(1)!.trim().toLowerCase() != 'none';
    final strokeValid = hasStroke != null && hasStroke.group(1)!.trim().toLowerCase() != 'none';
    return fillValid || strokeValid;
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  /// Returns true if at least one shape is large enough to be visible.
  static bool _hasVisibleShape(String s) {
    // Circle or ellipse with meaningful radius.
    for (final m in RegExp(r'<(?:circle|ellipse)\b([^>]*)>?').allMatches(s)) {
      final attrs = m.group(1)!;
      final r = _numAttr(attrs, 'r') ?? _numAttr(attrs, 'rx') ?? 0;
      if (r >= 5) return true;
    }
    // Rect with meaningful width AND height.
    for (final m in RegExp(r'<rect\b([^>]*)>?').allMatches(s)) {
      final attrs = m.group(1)!;
      final w = _numAttr(attrs, 'width') ?? 0;
      final h = _numAttr(attrs, 'height') ?? 0;
      if (w >= 10 && h >= 10) return true;
    }
    // Line with meaningful length.
    for (final m in RegExp(r'<line\b([^>]*)>?').allMatches(s)) {
      final attrs = m.group(1)!;
      final x1 = _numAttr(attrs, 'x1') ?? 0;
      final x2 = _numAttr(attrs, 'x2') ?? 0;
      final y1 = _numAttr(attrs, 'y1') ?? 0;
      final y2 = _numAttr(attrs, 'y2') ?? 0;
      if ((x2 - x1).abs() >= 10 || (y2 - y1).abs() >= 10) return true;
    }
    // Polygon with a reasonable bounding span.
    for (final m in RegExp(r'<polygon\b([^>]*)>?').allMatches(s)) {
      final pts = RegExp(r'[\d.]+').allMatches(m.group(1)!).map((p) => double.parse(p.group(0)!)).toList();
      if (pts.length >= 4) {
        final xs = [for (var i = 0; i < pts.length - 1; i += 2) pts[i]];
        final ys = [for (var i = 1; i < pts.length; i += 2) pts[i]];
        final span = [xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b),
                      ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b)];
        if (span.any((v) => v >= 10)) return true;
      }
    }
    return false;
  }

  static double? _numAttr(String attrs, String name) =>
      double.tryParse(RegExp('\\b$name="([\\d.]+)"').firstMatch(attrs)?.group(1) ?? '');
}
