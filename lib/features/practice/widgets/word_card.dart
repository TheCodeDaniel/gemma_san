import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class WordCard extends StatelessWidget {
  const WordCard({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius + 4),
        boxShadow: AppShadows.floating,
        border: Border.all(color: AppColors.warmCreamDark, width: 1.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
                height: 1.0,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.terracotta, AppColors.sunYellow],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
