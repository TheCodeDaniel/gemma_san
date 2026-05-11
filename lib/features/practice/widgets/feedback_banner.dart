import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({required this.correct, required this.text, super.key});

  final bool correct;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.deepGreen : AppColors.terracotta;
    final icon = correct ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.arrowCounterClockwise;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppText.label(color: color).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
