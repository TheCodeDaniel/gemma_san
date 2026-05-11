import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// Anatomy (back → front draw order):
//   1. Ear tufts     — drawn before head so head circle hides their bases
//   2. Wings         — dark ovals peeking from body sides
//   3. Body oval     — tall ellipse, bottom-heavy (pear silhouette)
//   4. Head circle   — sits on top of body, covers tuft bases
//   5. Facial disc   — prominent cream ellipse, the #1 owl feature
//   6. Belly         — warmCreamDark oval on lower body
//   7. Eyes          — amber iris, clip-blink via canvas.clipPath
//   8. Beak          — small terracotta triangle below eyes

class OwlPainter extends CustomPainter {
  const OwlPainter({required this.blinkProgress, required this.beakOpen});

  final double blinkProgress;
  final double beakOpen;

  static const _bodyBrown = Color(0xFF9B6A3E);
  static const _darkBrown = Color(0xFF3D2008);
  static const _midBrown  = Color(0xFF6B3D15);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s * 0.5;

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.45),
        radius: 0.85,
        colors: [_bodyBrown, _darkBrown],
      ).createShader(Rect.fromLTWH(0, s * 0.10, s, s * 0.84));

    _drawTuft(canvas, s, cx, left: true);
    _drawTuft(canvas, s, cx, left: false);

    final wingPaint = Paint()..color = _darkBrown;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + sign * s * 0.345, s * 0.685),
          width: s * 0.24,
          height: s * 0.46,
        ),
        wingPaint,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, s * 0.685), width: s * 0.66, height: s * 0.53),
      bodyPaint,
    );

    canvas.drawCircle(Offset(cx, s * 0.383), s * 0.245, bodyPaint);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, s * 0.393), width: s * 0.415, height: s * 0.390),
      Paint()..color = AppColors.warmCream,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, s * 0.393), width: s * 0.415, height: s * 0.390),
      Paint()
        ..color = _midBrown
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022,
    );

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, s * 0.770), width: s * 0.365, height: s * 0.285),
      Paint()..color = AppColors.warmCreamDark,
    );

    _drawEye(canvas, s, cx - s * 0.110, s * 0.368);
    _drawEye(canvas, s, cx + s * 0.110, s * 0.368);
    _drawBeak(canvas, s, cx);
  }

  void _drawTuft(Canvas canvas, double s, double cx, {required bool left}) {
    final sign = left ? -1.0 : 1.0;
    final tc = cx + sign * s * 0.132;

    canvas.drawPath(
      Path()
        ..moveTo(tc, s * 0.042)
        ..lineTo(tc + sign * s * 0.092, s * 0.280)
        ..lineTo(tc - sign * s * 0.040, s * 0.232)
        ..close(),
      Paint()..color = _darkBrown,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tc, s * 0.088)
        ..lineTo(tc + sign * s * 0.048, s * 0.258)
        ..lineTo(tc - sign * s * 0.016, s * 0.214)
        ..close(),
      Paint()..color = _bodyBrown,
    );
  }

  void _drawEye(Canvas canvas, double s, double x, double y) {
    final outerR = s * 0.073;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: outerR)));

    canvas.drawCircle(Offset(x, y), outerR, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, y), s * 0.053, Paint()..color = AppColors.sunYellow);
    canvas.drawCircle(Offset(x + s * 0.010, y + s * 0.007), s * 0.028, Paint()..color = AppColors.charcoal);
    canvas.drawCircle(Offset(x + s * 0.026, y - s * 0.016), s * 0.013, Paint()..color = Colors.white);

    if (blinkProgress > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(x - outerR, y - outerR, outerR * 2, outerR * 2 * blinkProgress),
        Paint()..color = _midBrown,
      );
    }

    canvas.restore();
  }

  void _drawBeak(Canvas canvas, double s, double cx) {
    final topY = s * 0.468;
    final bottomY = topY + s * 0.072 + beakOpen * s * 0.042;

    canvas.drawPath(
      Path()
        ..moveTo(cx - s * 0.052, topY)
        ..lineTo(cx + s * 0.052, topY)
        ..lineTo(cx, bottomY)
        ..close(),
      Paint()..color = AppColors.terracotta,
    );
  }

  @override
  bool shouldRepaint(OwlPainter old) =>
      old.blinkProgress != blinkProgress || old.beakOpen != beakOpen;
}
