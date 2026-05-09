import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import 'onboarding_prefs.dart';
import 'session_provider.dart';

class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  String? _tappedId;

  static const _avatars = [
    (emoji: '🦁', id: 'lion',      name: 'Lion'),
    (emoji: '🐘', id: 'elephant',  name: 'Elephant'),
    (emoji: '🦋', id: 'butterfly', name: 'Butterfly'),
    (emoji: '🐒', id: 'monkey',    name: 'Monkey'),
    (emoji: '🦜', id: 'parrot',    name: 'Parrot'),
    (emoji: '🐠', id: 'fish',      name: 'Fish'),
  ];

  static const _avatarColors = [
    AppColors.terracottaLight,
    AppColors.deepGreenLight,
    Color(0xFFFFF3CC),  // soft yellow
    AppColors.warmCreamDark,
    Color(0xFFD4EAD4),  // soft sage
    Color(0xFFCCE5FF),  // soft blue
  ];

  @override
  void initState() {
    super.initState();
    _loadAgeRange();
  }

  Future<void> _loadAgeRange() async {
    final range = await OnboardingPrefs.ageRange;
    if (mounted) {
      ref.read(currentAgeRangeProvider.notifier).state = range;
    }
  }

  Future<void> _onAvatarTap(String id) async {
    if (_tappedId != null) return;
    setState(() => _tappedId = id);
    ref.read(currentAvatarIdProvider.notifier).state = id;

    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Who you be today?', style: AppText.heading()),
              const SizedBox(height: 6),
              Text(
                'Pick your character for this session.',
                style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: _avatars.length,
                  itemBuilder: (_, i) {
                    final a = _avatars[i];
                    final selected = _tappedId == a.id;
                    return _AvatarCard(
                      emoji: a.emoji,
                      name: a.name,
                      bgColor: _avatarColors[i],
                      selected: selected,
                      onTap: () => _onAvatarTap(a.id),
                    );
                  },
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

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.emoji,
    required this.name,
    required this.bgColor,
    required this.selected,
    required this.onTap,
  });

  final String emoji, name;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.13 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? bgColor : Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: selected
                  ? AppColors.terracotta
                  : AppColors.warmCreamDark,
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: selected ? AppShadows.floating : AppShadows.card,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(
                name,
                style: AppText.label(
                  color: selected ? AppColors.terracotta : AppColors.charcoal,
                ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
