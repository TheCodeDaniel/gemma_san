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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.warmCream,
        border: Border(top: BorderSide(color: AppColors.warmCreamDark, width: 1)),
        boxShadow: [
          BoxShadow(color: AppColors.charcoal.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onCameraTap != null) ...[
            _CameraButton(disabled: busy || !sessionReady || recording, onTap: onCameraTap!),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: _InputField(
              controller: controller,
              enabled: sessionReady && !busy && !recording,
              recording: recording,
              transcribing: transcribing,
              onSubmitted: canSend ? (_) => onSend() : null,
            ),
          ),
          const SizedBox(width: 8),
          // Mic and send share one button slot — animated swap based on text content.
          _ActionButton(
            canSend: canSend,
            recording: recording,
            transcribing: transcribing,
            disabled: !sessionReady || busy,
            onMicTap: onMicTap,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.enabled,
    required this.recording,
    required this.transcribing,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled, recording, transcribing;
  final ValueChanged<String>? onSubmitted;

  String get _hint {
    if (recording) return 'Listening… tap to stop';
    if (transcribing) return 'Transcribing…';
    return 'Type or speak…';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: recording ? Colors.red.shade300 : AppColors.warmCreamDark, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.charcoal.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: _hint,
          hintStyle: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.35)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
        style: AppText.body(),
        maxLines: 3,
        minLines: 1,
        enabled: enabled,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.send,
      ),
    );
  }
}

// ── Camera — compact ghost icon, no background circle ─────────────────────────

class _CameraButton extends StatefulWidget {
  const _CameraButton({required this.disabled, required this.onTap});
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_CameraButton> createState() => _CameraButtonState();
}

class _CameraButtonState extends State<_CameraButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.85,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.disabled ? AppColors.charcoal.withValues(alpha: 0.2) : AppColors.deepGreen;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
        // Fixed height to align baseline with text field
        child: SizedBox(width: 36, height: 44, child: Icon(PhosphorIconsRegular.camera, color: color, size: 24)),
      ),
    );
  }
}

// ── Action button — mic ↔ send with animated icon swap ────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.canSend,
    required this.recording,
    required this.transcribing,
    required this.disabled,
    required this.onMicTap,
    required this.onSend,
  });

  final bool canSend, recording, transcribing, disabled;
  final VoidCallback onMicTap;
  final VoidCallback onSend;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.90,
  ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _isMicMode => !widget.canSend;
  bool get _isInteractive => !widget.disabled || widget.recording;

  Color get _color {
    if (widget.recording) return Colors.red.shade600;
    if (widget.disabled) return AppColors.charcoal.withValues(alpha: 0.15);
    if (_isMicMode) return AppColors.terracotta;
    return AppColors.deepGreen;
  }

  void _onTap() {
    if (_isMicMode || widget.recording) {
      widget.onMicTap();
    } else {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return GestureDetector(
      onTapDown: _isInteractive ? (_) => _pressCtrl.forward() : null,
      onTapUp: _isInteractive
          ? (_) {
              _pressCtrl.reverse();
              _onTap();
            }
          : null,
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: _isInteractive && !widget.disabled ? AppShadows.button(color) : const [],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: widget.transcribing
                ? const SizedBox(
                    key: ValueKey('transcribing'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Icon(
                    key: ValueKey(
                      widget.recording
                          ? 'stop'
                          : _isMicMode
                          ? 'mic'
                          : 'send',
                    ),
                    widget.recording
                        ? PhosphorIconsRegular.stop
                        : _isMicMode
                        ? PhosphorIconsRegular.microphone
                        : PhosphorIconsRegular.paperPlaneTilt,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}
