import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../home/widgets/mama_san_widget.dart';
import 'avatar_picker_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _requesting = false;

  void _proceed() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AvatarPickerScreen()),
    );
  }

  Future<void> _requestMic() async {
    setState(() => _requesting = true);
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No worries! You can still type your answers.',
            style: AppText.body(color: Colors.white),
          ),
          backgroundColor: AppColors.charcoal,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (mounted) _proceed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Owl with mic icon badge
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  const MamaSanWidget(state: OwlState.idle, size: 160),
                  Positioned(
                    bottom: 28,
                    right: 0,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.terracotta,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.button(AppColors.terracotta),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        PhosphorIconsRegular.microphone,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                'I need to hear you!',
                style: AppText.heading(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'So I fit hear you when you talk,\nI need to use the phone mic.',
                style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Primary CTA
              _PillButton(
                label: 'Okay, give access',
                color: AppColors.terracotta,
                loading: _requesting,
                onTap: _requesting ? null : _requestMic,
              ),
              const SizedBox(height: AppSpacing.md),

              // Secondary — skip
              GestureDetector(
                onTap: _requesting ? null : _proceed,
                child: Container(
                  width: double.infinity,
                  height: AppSpacing.minTap + 8,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.charcoal.withValues(alpha: 0.25), width: 1.5),
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Not now',
                    style: AppText.button(color: AppColors.charcoal.withValues(alpha: 0.5)),
                  ),
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

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> with SingleTickerProviderStateMixin {
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
      onTapDown: widget.onTap != null ? (_) => _ctrl.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _ctrl.reverse();
              widget.onTap!();
            }
          : null,
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
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(widget.label, style: AppText.button()),
        ),
      ),
    );
  }
}
