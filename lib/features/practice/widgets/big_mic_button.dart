import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class BigMicButton extends StatefulWidget {
  const BigMicButton({required this.recording, required this.evaluating, required this.onTap, super.key});

  final bool recording;
  final bool evaluating;
  final VoidCallback? onTap;

  @override
  State<BigMicButton> createState() => _BigMicButtonState();
}

class _BigMicButtonState extends State<BigMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    if (widget.recording) return Colors.red.shade600;
    if (widget.onTap == null) return AppColors.charcoal.withValues(alpha: 0.15);
    return AppColors.terracotta;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
            boxShadow: enabled ? AppShadows.button(_color) : [],
          ),
          alignment: Alignment.center,
          child: widget.evaluating
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : Icon(
                  widget.recording ? PhosphorIconsRegular.stop : PhosphorIconsRegular.microphone,
                  size: 36,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}
