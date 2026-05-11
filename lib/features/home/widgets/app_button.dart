import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
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
    final color = widget.enabled ? widget.color : AppColors.charcoal.withValues(alpha: 0.2);
    final textColor = widget.enabled ? Colors.white : AppColors.charcoal.withValues(alpha: 0.4);

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: AppSpacing.minTap + 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            boxShadow: widget.enabled ? AppShadows.button(widget.color) : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: textColor, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(widget.label, style: AppText.button(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
