import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({required this.onDebugLongPress, required this.onSettings, super.key});

  final VoidCallback onDebugLongPress;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.minTap),
          Expanded(
            child: GestureDetector(
              onLongPress: onDebugLongPress,
              child: Text(
                'Gemma-San',
                style: AppText.title(color: AppColors.terracotta),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSettings,
            child: SizedBox(
              width: AppSpacing.minTap,
              height: AppSpacing.minTap,
              child: Icon(
                PhosphorIconsRegular.slidersHorizontal,
                color: AppColors.charcoal.withValues(alpha: 0.5),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
