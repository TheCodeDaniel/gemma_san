import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';

class ConvInputRow extends StatelessWidget {
  const ConvInputRow({
    required this.controller,
    required this.recording,
    required this.transcribing,
    required this.busy,
    required this.sessionReady,
    required this.canSend,
    required this.onMicTap,
    required this.onSend,
    this.onCameraTap,
    super.key,
  });

  final TextEditingController controller;
  final bool recording, transcribing, busy, sessionReady, canSend;
  final VoidCallback onMicTap;
  final VoidCallback onSend;
  final VoidCallback? onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warmCream,
        border: Border(top: BorderSide(color: AppColors.warmCreamDark, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onCameraTap != null) ...[
            _CameraButton(
              disabled: busy || !sessionReady || recording,
              onTap: onCameraTap!,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          MicPill(
            recording: recording,
            transcribing: transcribing,
            disabled: busy || !sessionReady,
            onTap: onMicTap,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.warmCreamDark, width: 1.5),
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: recording
                      ? 'Listening… tap mic to stop'
                      : transcribing
                      ? 'Transcribing…'
                      : 'Type or speak…',
                  hintStyle: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.35)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                style: AppText.body(),
                maxLines: 4,
                minLines: 1,
                enabled: sessionReady && !busy && !recording,
                onSubmitted: canSend ? (_) => onSend() : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SendButton(enabled: canSend, onTap: onSend),
        ],
      ),
    );
  }
}

class MicPill extends StatefulWidget {
  const MicPill({
    required this.recording,
    required this.transcribing,
    required this.disabled,
    required this.onTap,
    super.key,
  });

  final bool recording, transcribing, disabled;
  final VoidCallback onTap;

  @override
  State<MicPill> createState() => _MicPillState();
}

class _MicPillState extends State<MicPill> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    if (widget.disabled) return AppColors.charcoal.withValues(alpha: 0.15);
    return AppColors.terracotta;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => _ctrl.forward(),
      onTapUp: widget.disabled
          ? null
          : (_) {
              _ctrl.reverse();
              widget.onTap();
            },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: AppSpacing.minTap,
          height: AppSpacing.minTap,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: widget.disabled ? [] : AppShadows.button(_color),
          ),
          alignment: Alignment.center,
          child: widget.transcribing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Icon(
                  widget.recording ? PhosphorIconsRegular.stop : PhosphorIconsRegular.microphone,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

class _CameraButton extends StatefulWidget {
  const _CameraButton({required this.disabled, required this.onTap});
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<_CameraButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    final color = widget.disabled
        ? AppColors.charcoal.withValues(alpha: 0.15)
        : AppColors.deepGreen;
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => _ctrl.forward(),
      onTapUp: widget.disabled
          ? null
          : (_) {
              _ctrl.reverse();
              widget.onTap();
            },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: AppSpacing.minTap,
          height: AppSpacing.minTap,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: widget.disabled ? [] : AppShadows.button(color),
          ),
          alignment: Alignment.center,
          child: Icon(PhosphorIconsRegular.camera, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class SendButton extends StatefulWidget {
  const SendButton({required this.enabled, required this.onTap, super.key});
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: AppSpacing.minTap,
          height: AppSpacing.minTap,
          decoration: BoxDecoration(
            color: widget.enabled ? AppColors.deepGreen : AppColors.charcoal.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: widget.enabled ? AppShadows.button(AppColors.deepGreen) : [],
          ),
          alignment: Alignment.center,
          child: Icon(PhosphorIconsRegular.paperPlaneTilt, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
