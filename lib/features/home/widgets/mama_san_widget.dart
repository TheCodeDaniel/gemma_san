import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ── Public API ─────────────────────────────────────────────────────────────

enum OwlState { idle, listening, thinking, speaking }

class MamaSanWidget extends StatefulWidget {
  const MamaSanWidget({required this.state, this.size = 170, super.key});

  final OwlState state;
  final double size;

  @override
  State<MamaSanWidget> createState() => _MamaSanWidgetState();
}

// ── State ──────────────────────────────────────────────────────────────────

class _MamaSanWidgetState extends State<MamaSanWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;

  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;

  late AnimationController _stateCtrl;

  Timer? _blinkTimer;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _blinkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_blinkCtrl);
    _scheduleBlink();

    _stateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _applyState();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 4000 + _rng.nextInt(2000)),
      () {
        if (!mounted) return;
        _blinkCtrl
            .forward()
            .then((_) => _blinkCtrl.reverse().then((_) => _scheduleBlink()));
      },
    );
  }

  @override
  void didUpdateWidget(MamaSanWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _applyState();
  }

  void _applyState() {
    _stateCtrl.stop();
    switch (widget.state) {
      case OwlState.idle:
        break;
      case OwlState.listening:
        _stateCtrl.duration = const Duration(milliseconds: 750);
        _stateCtrl.repeat(reverse: true);
      case OwlState.thinking:
        _stateCtrl.duration = const Duration(milliseconds: 1100);
        _stateCtrl.repeat();
      case OwlState.speaking:
        _stateCtrl.duration = const Duration(milliseconds: 320);
        _stateCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathCtrl.dispose();
    _blinkCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathAnim, _blinkAnim, _stateCtrl]),
      builder: (context, _) {
        double scale = _breathAnim.value;
        double rotation = 0;

        switch (widget.state) {
          case OwlState.thinking:
            scale *= 0.975 + _stateCtrl.value * 0.04;
          case OwlState.listening:
            rotation = (_stateCtrl.value - 0.5) * 0.08;
          case OwlState.speaking:
            scale *= 1.0 + _stateCtrl.value * 0.012;
          case OwlState.idle:
            break;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: rotation,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _OwlPainter(
                    blinkProgress: _blinkAnim.value,
                    beakOpen: widget.state == OwlState.speaking
                        ? _stateCtrl.value * 0.3
                        : 0.0,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 28,
              child: _StateOverlay(state: widget.state, progress: _stateCtrl.value),
            ),
          ],
        );
      },
    );
  }
}

// ── Owl painter ────────────────────────────────────────────────────────────
// Proportions are normalised to `s` (the canvas side length).
//
// Anatomy (back → front draw order):
//   1. Ear tufts     — drawn before head so head circle hides their bases
//   2. Wings         — dark ovals peeking from body sides
//   3. Body oval     — tall ellipse, bottom-heavy (pear silhouette)
//   4. Head circle   — sits on top of body, covers tuft bases
//   5. Facial disc   — prominent cream ellipse, the #1 owl feature
//   6. Belly         — warmCreamDark oval on lower body
//   7. Eyes          — amber iris, clip-blink via canvas.clipPath
//   8. Beak          — small terracotta triangle below eyes

class _OwlPainter extends CustomPainter {
  const _OwlPainter({required this.blinkProgress, required this.beakOpen});

  final double blinkProgress;
  final double beakOpen;

  // Earth-tone browns (owl anatomy — not UI chrome)
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

    // ── 1. Ear tufts ──────────────────────────────────────────────────
    _drawTuft(canvas, s, cx, left: true);
    _drawTuft(canvas, s, cx, left: false);

    // ── 2. Wings ──────────────────────────────────────────────────────
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

    // ── 3. Body oval ──────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.685),
        width: s * 0.66,
        height: s * 0.53,
      ),
      bodyPaint,
    );

    // ── 4. Head circle ────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, s * 0.383), s * 0.245, bodyPaint);

    // ── 5. Facial disc ────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.393),
        width: s * 0.415,
        height: s * 0.390,
      ),
      Paint()..color = AppColors.warmCream,
    );
    // Rim — subtle dark border that frames the face
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.393),
        width: s * 0.415,
        height: s * 0.390,
      ),
      Paint()
        ..color = _midBrown
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022,
    );

    // ── 6. Belly ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.770),
        width: s * 0.365,
        height: s * 0.285,
      ),
      Paint()..color = AppColors.warmCreamDark,
    );

    // ── 7. Eyes ───────────────────────────────────────────────────────
    _drawEye(canvas, s, cx - s * 0.110, s * 0.368);
    _drawEye(canvas, s, cx + s * 0.110, s * 0.368);

    // ── 8. Beak ───────────────────────────────────────────────────────
    _drawBeak(canvas, s, cx);
  }

  void _drawTuft(Canvas canvas, double s, double cx, {required bool left}) {
    final sign = left ? -1.0 : 1.0;
    final tc = cx + sign * s * 0.132; // horizontal center of this tuft

    // Outer dark shape
    canvas.drawPath(
      Path()
        ..moveTo(tc, s * 0.042)
        ..lineTo(tc + sign * s * 0.092, s * 0.280)
        ..lineTo(tc - sign * s * 0.040, s * 0.232)
        ..close(),
      Paint()..color = _darkBrown,
    );
    // Inner lighter stripe — gives the tuft a feathery split
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

    // Clip everything to the eye circle so the eyelid is perfectly bounded
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: outerR)),
    );

    // Sclera
    canvas.drawCircle(Offset(x, y), outerR, Paint()..color = Colors.white);

    // Amber iris — warm and inviting
    canvas.drawCircle(
      Offset(x, y),
      s * 0.053,
      Paint()..color = AppColors.sunYellow,
    );

    // Pupil (slightly off-centre for life)
    canvas.drawCircle(
      Offset(x + s * 0.010, y + s * 0.007),
      s * 0.028,
      Paint()..color = AppColors.charcoal,
    );

    // Catchlight
    canvas.drawCircle(
      Offset(x + s * 0.026, y - s * 0.016),
      s * 0.013,
      Paint()..color = Colors.white,
    );

    // Eyelid (sweeps down from top on blink)
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
  bool shouldRepaint(_OwlPainter old) =>
      old.blinkProgress != blinkProgress || old.beakOpen != beakOpen;
}

// ── State overlay (below owl) ──────────────────────────────────────────────

class _StateOverlay extends StatelessWidget {
  const _StateOverlay({required this.state, required this.progress});
  final OwlState state;
  final double progress;

  @override
  Widget build(BuildContext context) => switch (state) {
    OwlState.listening => _WaveformBars(progress: progress),
    OwlState.thinking  => _ThinkingDots(progress: progress),
    _                  => const SizedBox.shrink(),
  };
}

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(5, (i) {
        final phase = i / 5.0;
        final h = 6.0 + 14.0 * math.sin((progress + phase) * math.pi * 2).abs();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Container(
            width: 5,
            height: h,
            decoration: BoxDecoration(
              color: AppColors.terracotta,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = i / 3.0;
        final a = (0.25 + 0.75 * ((math.sin((progress - phase) * math.pi * 2) + 1) / 2))
            .clamp(0.25, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: a,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }),
    );
  }
}
