import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';
import '../conversation/conversation_screen.dart';
import '../diagnostic/diagnostic_screen.dart';
import '../practice/practice_screen.dart';
import 'widgets/mama_san_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _gemmaService = GemmaService();
  final _sttService = SttService();
  final _ttsService = TtsService();

  OwlState _owlState = OwlState.idle;
  bool _gemmaReady = false;
  bool _sttReady = false;
  int _downloadPct = 0;
  String _statusText = 'Waking up…';
  StreamSubscription<bool>? _ttsSub;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _ttsSub?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _owlState = OwlState.thinking;
      _statusText = 'Loading…';
    });

    await _ttsService.initialize();

    _ttsSub = _ttsService.speakingStream.listen((speaking) {
      if (!mounted) return;
      setState(() => _owlState = speaking ? OwlState.speaking : OwlState.idle);
    });

    await Future.wait([
      _gemmaService.initialize(
        onProgress: (pct) {
          if (!mounted) return;
          setState(() {
            _downloadPct = pct;
            _statusText = 'Downloading model… $pct%';
          });
        },
      ).then((_) {
        if (!mounted) return;
        setState(() {
          _gemmaReady = true;
          _statusText = _sttReady ? '' : 'Loading voice…';
        });
      }),
      _sttService.initialize(
        onProgress: (pct) {
          if (!mounted) return;
          setState(() {
            _statusText = 'Downloading voice… $pct%';
          });
        },
      ).then((_) {
        if (!mounted) return;
        setState(() {
          _sttReady = true;
          _statusText = _gemmaReady ? '' : 'Loading AI…';
        });
      }),
    ]);

    if (!mounted) return;
    setState(() {
      _owlState = OwlState.idle;
      _statusText = '';
    });
  }

  bool get _ready => _gemmaReady && _sttReady;

  void _goConversation() {
    if (!_ready) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          gemmaService: _gemmaService,
          sttService: _sttService,
          ttsService: _ttsService,
        ),
      ),
    );
  }

  void _goPractice() {
    if (!_sttReady) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(sttService: _sttService),
      ),
    );
  }

  void _goDiagnostic() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TopBar(onDebugLongPress: _goDiagnostic),
              const SizedBox(height: AppSpacing.lg),

              // ── Owl ──────────────────────────────────────────────────────
              Expanded(
                flex: 5,
                child: Center(
                  child: MamaSanWidget(state: _owlState, size: 200),
                ),
              ),

              // ── Greeting ─────────────────────────────────────────────────
              Text(
                'Mama San',
                style: AppText.caption(color: AppColors.terracotta),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back, my pikin!',
                style: AppText.heading(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'What do you want to do today?',
                style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),

              // ── Status / progress ─────────────────────────────────────────
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _statusText.isNotEmpty
                    ? _StatusRow(text: _statusText, pct: _downloadPct)
                    : const SizedBox(height: 20),
              ),

              // ── Buttons ───────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              _AppButton(
                label: 'Make I teach you',
                icon: PhosphorIconsRegular.chatsCircle,
                color: AppColors.terracotta,
                enabled: _ready,
                onTap: _goConversation,
              ),
              const SizedBox(height: AppSpacing.md),
              _AppButton(
                label: 'Practice',
                icon: PhosphorIconsRegular.pencilSimpleLine,
                color: AppColors.deepGreen,
                enabled: _sttReady,
                onTap: _goPractice,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onDebugLongPress});
  final VoidCallback onDebugLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GestureDetector(
        onLongPress: onDebugLongPress,
        child: Text('Gemma-San', style: AppText.title(color: AppColors.terracotta)),
      ),
    );
  }
}

// ── Status row ─────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.text, required this.pct});
  final String text;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: AppText.caption()),
        if (pct > 0 && pct < 100) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 5,
              backgroundColor: AppColors.warmCreamDark,
              valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Button ─────────────────────────────────────────────────────────────────

class _AppButton extends StatefulWidget {
  const _AppButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<_AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? widget.color : AppColors.charcoal.withValues(alpha: 0.2);
    final textColor = widget.enabled ? Colors.white : AppColors.charcoal.withValues(alpha: 0.4);

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _pressCtrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _pressCtrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: AppSpacing.minTap + 8, // 64dp
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
