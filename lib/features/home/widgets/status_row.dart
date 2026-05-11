import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StatusRow extends StatelessWidget {
  const StatusRow({required this.text, required this.pct, super.key});

  final String text;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: AppText.caption()),
        if (pct > 0 && pct < 100) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 5,
              backgroundColor: AppColors.warmCreamDark,
              valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
            ),
          ),
        ],
      ],
    );
  }
}
