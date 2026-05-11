import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'mama_san_widget.dart';

class OwlStateOverlay extends StatelessWidget {
  const OwlStateOverlay({required this.state, required this.progress, super.key});

  final OwlState state;
  final double progress;

  @override
  Widget build(BuildContext context) => switch (state) {
        OwlState.listening => WaveformBars(progress: progress),
        OwlState.thinking  => ThinkingDots(progress: progress),
        _                  => const SizedBox.shrink(),
      };
}

class WaveformBars extends StatelessWidget {
  const WaveformBars({required this.progress, super.key});
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

class ThinkingDots extends StatelessWidget {
  const ThinkingDots({required this.progress, super.key});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = i / 3.0;
        final a = (0.25 + 0.75 * ((math.sin((progress - phase) * math.pi * 2) + 1) / 2)).clamp(0.25, 1.0);
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
