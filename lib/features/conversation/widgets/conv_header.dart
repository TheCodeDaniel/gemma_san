import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class ConvHeader extends StatelessWidget {
  const ConvHeader({required this.speaking, required this.onStopTts, super.key});

  final bool speaking;
  final VoidCallback onStopTts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppSpacing.minTap,
              height: AppSpacing.minTap,
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.charcoal, size: 22),
            ),
          ),
          Expanded(
            child: Text('Conversation', style: AppText.title(), textAlign: TextAlign.center),
          ),
          if (speaking)
            GestureDetector(
              onTap: onStopTts,
              child: Container(
                width: AppSpacing.minTap,
                height: AppSpacing.minTap,
                alignment: Alignment.center,
                child: const Icon(PhosphorIconsRegular.speakerX, color: AppColors.terracotta, size: 22),
              ),
            )
          else
            const SizedBox(width: AppSpacing.minTap),
        ],
      ),
    );
  }
}
