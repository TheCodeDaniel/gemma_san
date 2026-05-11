import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/widgets/mama_san_widget.dart';
import '../practice_service.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({required this.stats, required this.onRestart, required this.onBack, super.key});

  final SessionStats stats;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pct = stats.itemsPracticed == 0 ? 0 : (stats.correct * 100 ~/ stats.itemsPracticed);
    final message = pct == 100
        ? 'You don pass all! You too much!'
        : pct >= 70
        ? 'Good work! Practice more, you go shine!'
        : 'No worry, try am again — you go get am!';

    final scoreColor = pct == 100
        ? AppColors.deepGreen
        : pct >= 70
        ? AppColors.sunYellow
        : AppColors.terracotta;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              _SummaryHeader(onBack: onBack),
              const Spacer(),
              MamaSanWidget(state: OwlState.idle, size: 130),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${stats.correct} / ${stats.itemsPracticed}',
                style: AppText.display(color: scoreColor),
              ),
              const SizedBox(height: 4),
              Text('correct', style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.6))),
              const SizedBox(height: AppSpacing.lg),
              _ResultCard(message: message, stats: stats),
              const Spacer(),
              _SummaryButton(label: 'Try Again', color: AppColors.terracotta, onTap: onRestart),
              const SizedBox(height: AppSpacing.md),
              _SummaryButton(label: 'Back to Home', color: AppColors.deepGreen, onTap: onBack),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: AppSpacing.minTap,
              height: AppSpacing.minTap,
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.charcoal, size: 22),
            ),
          ),
          Expanded(child: Text('Practice Done', style: AppText.title(), textAlign: TextAlign.center)),
          const SizedBox(width: AppSpacing.minTap),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.message, required this.stats});
  final String message;
  final SessionStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: AppText.body()),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatChip(
                icon: PhosphorIconsRegular.star,
                label: '${stats.masteredToday} mastered',
                color: AppColors.sunYellow,
              ),
              const SizedBox(width: AppSpacing.sm),
              StatChip(
                icon: PhosphorIconsRegular.calendarCheck,
                label: '${stats.reviewTomorrow} tomorrow',
                color: AppColors.deepGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({required this.icon, required this.label, required this.color, super.key});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.caption(color: color).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SummaryButton extends StatefulWidget {
  const _SummaryButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_SummaryButton> createState() => _SummaryButtonState();
}

class _SummaryButtonState extends State<_SummaryButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: AppSpacing.minTap + 8,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            boxShadow: AppShadows.button(widget.color),
          ),
          alignment: Alignment.center,
          child: Text(widget.label, style: AppText.button()),
        ),
      ),
    );
  }
}
