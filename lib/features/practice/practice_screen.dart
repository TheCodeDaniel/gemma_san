import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_database.dart';
import '../../services/stt/stt_service.dart';
import '../home/widgets/mama_san_widget.dart';
import 'practice_service.dart';

const _maxTriesPerItem = 2;

enum _Phase { ready, recording, evaluating, feedback }

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.sttService});

  final SttService sttService;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _service = PracticeService();
  final _recorder = AudioRecorder();

  _Phase _phase = _Phase.ready;
  bool _lastCorrect = false;
  String _feedbackText = '';
  bool _loaded = false;

  OwlState get _owlState => switch (_phase) {
    _Phase.recording => OwlState.listening,
    _Phase.evaluating => OwlState.thinking,
    _Phase.feedback => _lastCorrect ? OwlState.speaking : OwlState.idle,
    _Phase.ready => OwlState.idle,
  };

  @override
  void initState() {
    super.initState();
    _initService();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _initService() async {
    final db = await AppDatabase.get();
    await _service.initialize('default', rootBundle, db);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _onMicTap() async {
    if (_phase == _Phase.ready) {
      await _startRecording();
    } else if (_phase == _Phase.recording) {
      await _stopAndEvaluate();
    }
  }

  Future<void> _startRecording() async {
    setState(() => _phase = _Phase.recording);
    final dir = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: '${dir.path}/practice_input.wav',
    );
  }

  Future<void> _stopAndEvaluate() async {
    setState(() => _phase = _Phase.evaluating);

    String transcribed = '';
    try {
      final path = await _recorder.stop();
      if (path != null) transcribed = await widget.sttService.transcribe(path);
    } catch (_) {}

    final result = await _service.evaluate(transcribed);

    setState(() {
      _lastCorrect = result.correct;
      _feedbackText = result.feedback;
      _phase = _Phase.feedback;
    });

    await Future.delayed(Duration(milliseconds: result.correct ? 700 : 800));
    if (!mounted) return;

    if (result.correct || _service.tries >= _maxTriesPerItem) {
      _service.advance();
    }

    if (!_service.hasMore) await _service.debugDump();

    setState(() => _phase = _Phase.ready);
  }

  void _endPractice() => Navigator.of(context).pop();

  Future<void> _restartPractice() async {
    setState(() => _loaded = false);
    await _initService();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.warmCream,
        body: Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
      );
    }

    if (!_service.hasMore) {
      return _SummaryScreen(stats: _service.sessionStats, onRestart: _restartPractice, onBack: _endPractice);
    }

    final item = _service.currentItem!;
    final busy = _phase == _Phase.evaluating || _phase == _Phase.feedback;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              _PracticeHeader(score: _service.score, tried: _service.tried, onEnd: _endPractice),

              // ── Progress bar ─────────────────────────────────────────────
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _service.tried / 15,
                  minHeight: 6,
                  backgroundColor: AppColors.warmCreamDark,
                  valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
                ),
              ),

              // ── Owl ──────────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.md),
              MamaSanWidget(state: _owlState, size: 130),

              // ── Word card ────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      final rotate = Tween(
                        begin: math.pi,
                        end: 0.0,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                      return AnimatedBuilder(
                        animation: rotate,
                        child: child,
                        builder: (_, child) => Transform(
                          transform: Matrix4.rotationY(rotate.value),
                          alignment: Alignment.center,
                          child: child,
                        ),
                      );
                    },
                    child: _WordCard(key: ValueKey(item.id), text: item.promptText),
                  ),
                ),
              ),

              // ── Feedback banner ──────────────────────────────────────────
              SizedBox(
                height: 52,
                child: AnimatedOpacity(
                  opacity: _phase == _Phase.feedback ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: _FeedbackBanner(correct: _lastCorrect, text: _feedbackText),
                ),
              ),

              // ── Mic button ───────────────────────────────────────────────
              const SizedBox(height: AppSpacing.md),
              _BigMicButton(phase: _phase, onTap: busy ? null : _onMicTap),

              // ── Hint text ────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.sm),
              Text(_phaseHint(_phase), style: AppText.caption(), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  static String _phaseHint(_Phase phase) => switch (phase) {
    _Phase.ready => 'Tap the mic and say the word',
    _Phase.recording => 'Listening… tap to stop',
    _Phase.evaluating => 'Checking…',
    _Phase.feedback => '',
  };
}

// ── Header ─────────────────────────────────────────────────────────────────

class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({required this.score, required this.tried, required this.onEnd});
  final int score, tried;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEnd,
            child: Container(
              width: AppSpacing.minTap,
              height: AppSpacing.minTap,
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.charcoal, size: 22),
            ),
          ),
          Expanded(
            child: Text('Practice', style: AppText.title(), textAlign: TextAlign.center),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: AppColors.terracottaLight, borderRadius: BorderRadius.circular(20)),
            child: Text(
              tried == 0 ? 'Ready' : '$score / $tried',
              style: AppText.label(color: AppColors.terracotta).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Word card ──────────────────────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  const _WordCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius + 4),
        boxShadow: AppShadows.floating,
        border: Border.all(color: AppColors.warmCreamDark, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w800, color: AppColors.charcoal, height: 1.0),
      ),
    );
  }
}

// ── Feedback banner ────────────────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.correct, required this.text});
  final bool correct;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.deepGreen : AppColors.terracotta;
    final icon = correct ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.arrowCounterClockwise;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppText.label(color: color).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Mic button ─────────────────────────────────────────────────────────────

class _BigMicButton extends StatefulWidget {
  const _BigMicButton({required this.phase, required this.onTap});
  final _Phase phase;
  final VoidCallback? onTap;

  @override
  State<_BigMicButton> createState() => _BigMicButtonState();
}

class _BigMicButtonState extends State<_BigMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    if (widget.phase == _Phase.recording) return Colors.red.shade600;
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
          child: widget.phase == _Phase.evaluating
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : Icon(
                  widget.phase == _Phase.recording ? PhosphorIconsRegular.stop : PhosphorIconsRegular.microphone,
                  size: 36,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

// ── Summary screen ─────────────────────────────────────────────────────────

class _SummaryScreen extends StatelessWidget {
  const _SummaryScreen({required this.stats, required this.onRestart, required this.onBack});

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
              Padding(
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
                    Expanded(
                      child: Text('Practice Done', style: AppText.title(), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: AppSpacing.minTap),
                  ],
                ),
              ),
              const Spacer(),
              MamaSanWidget(state: OwlState.idle, size: 130),
              const SizedBox(height: AppSpacing.lg),
              Text('${stats.correct} / ${stats.itemsPracticed}', style: AppText.display(color: scoreColor)),
              const SizedBox(height: 4),
              Text('correct', style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.6))),
              const SizedBox(height: AppSpacing.lg),
              Container(
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
                        _StatChip(
                          icon: PhosphorIconsRegular.star,
                          label: '${stats.masteredToday} mastered',
                          color: AppColors.sunYellow,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatChip(
                          icon: PhosphorIconsRegular.calendarCheck,
                          label: '${stats.reviewTomorrow} tomorrow',
                          color: AppColors.deepGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.color});
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
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
