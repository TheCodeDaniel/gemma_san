import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class PracticeHeader extends StatelessWidget {
  const PracticeHeader({required this.score, required this.tried, required this.onEnd, super.key});

  final int score, tried;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEnd,
            child: Container(
              width: AppSpacing.minTap,
              height: AppSpacing.minTap,
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.charcoal, size: 22),
            ),
          ),
          Expanded(
            child: Text('Practice', style: AppText.title(), textAlign: TextAlign.center),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.terracottaLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tried == 0 ? 'Ready' : '$score / $tried',
              style: AppText.label(color: AppColors.terracotta).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
