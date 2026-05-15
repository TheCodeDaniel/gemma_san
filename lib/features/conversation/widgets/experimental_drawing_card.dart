import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';

class ExperimentalDrawingCard extends StatefulWidget {
  const ExperimentalDrawingCard({
    required this.svgCode,
    required this.topic,
    super.key,
  });

  final String svgCode;
  final String topic;

  @override
  State<ExperimentalDrawingCard> createState() => _ExperimentalDrawingCardState();
}

class _ExperimentalDrawingCardState extends State<ExperimentalDrawingCard> {
  double _opacity = 0.0;
  bool? _vote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  Future<void> _castVote(bool up) async {
    if (_vote != null) return;
    setState(() => _vote = up);
    final prefs = await SharedPreferences.getInstance();
    final key = up ? 'svg_thumbsUp' : 'svg_thumbsDown';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  void _openFullscreen() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: SvgPicture.string(widget.svgCode, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
              left: 0,
              right: 0,
              child: const Text(
                'Pinch to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.65;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
      child: Container(
        width: w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.warmCreamDark, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _openFullscreen,
              child: SvgPicture.string(widget.svgCode, width: w, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Experimental drawing',
                      style: AppText.caption(
                        color: AppColors.charcoal.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  _ThumbButton(
                    icon: Icons.thumb_up_outlined,
                    selectedIcon: Icons.thumb_up_rounded,
                    selected: _vote == true,
                    activeColor: AppColors.deepGreen,
                    onTap: () => _castVote(true),
                  ),
                  const SizedBox(width: 2),
                  _ThumbButton(
                    icon: Icons.thumb_down_outlined,
                    selectedIcon: Icons.thumb_down_rounded,
                    selected: _vote == false,
                    activeColor: AppColors.terracotta,
                    onTap: () => _castVote(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          selected ? selectedIcon : icon,
          size: 18,
          color: selected ? activeColor : AppColors.charcoal.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
