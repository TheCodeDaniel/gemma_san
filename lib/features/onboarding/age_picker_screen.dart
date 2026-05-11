import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'onboarding_prefs.dart';
import 'permissions_screen.dart';
import 'session_provider.dart';

class AgePickerScreen extends ConsumerWidget {
  const AgePickerScreen({super.key, this.isFromSettings = false});

  final bool isFromSettings;

  static const _ages = [
    (label: '6 – 7', emoji: '🌱', hint: 'Just starting out'),
    (label: '8 – 9', emoji: '⭐', hint: 'Growing learner'),
    (label: '10 – 11', emoji: '📖', hint: 'Getting smarter'),
    (label: '12+', emoji: '🚀', hint: 'Almost a pro'),
  ];

  Future<void> _onPick(BuildContext context, WidgetRef ref, String range) async {
    await OnboardingPrefs.setAgeRange(range);
    ref.read(currentAgeRangeProvider.notifier).state = range;

    if (!context.mounted) return;
    if (isFromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PermissionsScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFromSettings) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: AppSpacing.minTap,
                    height: AppSpacing.minTap,
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.charcoal, size: 20),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('How old you be?', style: AppText.heading()),
              const SizedBox(height: 6),
              Text(
                'I go teach you the right way for your age.',
                style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.1,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: _ages
                      .map(
                        (a) => _AgeCard(
                          label: a.label,
                          emoji: a.emoji,
                          hint: a.hint,
                          onTap: () => _onPick(context, ref, a.label),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeCard extends StatefulWidget {
  const _AgeCard({required this.label, required this.emoji, required this.hint, required this.onTap});

  final String label, emoji, hint;
  final VoidCallback onTap;

  @override
  State<_AgeCard> createState() => _AgeCardState();
}

class _AgeCardState extends State<_AgeCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.warmCreamDark, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: AppSpacing.sm),
              Text(widget.label, style: AppText.title()),
              const SizedBox(height: 2),
              Text(widget.hint, style: AppText.caption(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
