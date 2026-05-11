import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/gemma/tutor_response.dart';

(String, IconData, Color) _modeAttrs(TutorMode mode) => switch (mode) {
      TutorMode.socratic => ('Socratic', PhosphorIconsRegular.question, AppColors.socratic),
      TutorMode.direct => ('Direct', PhosphorIconsRegular.bookOpen, AppColors.direct),
      TutorMode.encourage => ('Encouraging', PhosphorIconsRegular.heart, AppColors.encourage),
    };

/// Persistent header pill — faded dots when no mode, coloured when active.
class ConvModePill extends StatelessWidget {
  const ConvModePill({required this.mode, super.key});
  final TutorMode? mode;

  @override
  Widget build(BuildContext context) {
    if (mode == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warmCreamDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('· · ·', style: AppText.caption(color: AppColors.charcoal.withValues(alpha: 0.25))),
      );
    }
    final (label, icon, color) = _modeAttrs(mode!);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.caption(color: color).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Small inline tag rendered beneath each assistant bubble.
class ModeTag extends StatelessWidget {
  const ModeTag({required this.mode, super.key});
  final TutorMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _modeAttrs(mode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.caption(color: color).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
