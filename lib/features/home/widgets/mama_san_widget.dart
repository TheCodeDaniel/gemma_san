import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'owl_painter.dart';
import 'owl_state_overlay.dart';

export 'owl_state_overlay.dart' show WaveformBars, ThinkingDots;

enum OwlState { idle, listening, thinking, speaking }

class MamaSanWidget extends StatefulWidget {
  const MamaSanWidget({required this.state, this.size = 170, super.key});

  final OwlState state;
  final double size;

  @override
  State<MamaSanWidget> createState() => _MamaSanWidgetState();
}

class _MamaSanWidgetState extends State<MamaSanWidget> with TickerProviderStateMixin {
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

    _breathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _blinkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_blinkCtrl);
    _scheduleBlink();

    _stateCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _applyState();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 4000 + _rng.nextInt(2000)),
      () {
        if (!mounted) return;
        _blinkCtrl.forward().then((_) => _blinkCtrl.reverse().then((_) => _scheduleBlink()));
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
                  painter: OwlPainter(
                    blinkProgress: _blinkAnim.value,
                    beakOpen: widget.state == OwlState.speaking ? _stateCtrl.value * 0.3 : 0.0,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 28,
              child: OwlStateOverlay(state: widget.state, progress: _stateCtrl.value),
            ),
          ],
        );
      },
    );
  }
}
