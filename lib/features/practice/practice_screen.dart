import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_database.dart';
import '../../services/stt/stt_service.dart';
import '../home/widgets/mama_san_widget.dart';
import 'practice_service.dart';
import 'widgets/big_mic_button.dart';
import 'widgets/feedback_banner.dart';
import 'widgets/summary_screen.dart';
import 'widgets/word_card.dart';

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

    if (result.correct || _service.tries >= _maxTriesPerItem) _service.advance();
    if (!_service.hasMore) await _service.debugDump();

    setState(() => _phase = _Phase.ready);
  }

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
      return SummaryScreen(
        stats: _service.sessionStats,
        onRestart: _restartPractice,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    final item = _service.currentItem!;
    final busy = _phase == _Phase.evaluating || _phase == _Phase.feedback;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.terracottaLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _service.tried == 0 ? 'Ready' : '${_service.score} / ${_service.tried}',
              style: AppText.label(color: AppColors.terracotta).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
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
              const SizedBox(height: AppSpacing.md),
              MamaSanWidget(state: _owlState, size: 130),
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
                    child: WordCard(key: ValueKey(item.id), text: item.promptText),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: AnimatedOpacity(
                  opacity: _phase == _Phase.feedback ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: FeedbackBanner(correct: _lastCorrect, text: _feedbackText),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BigMicButton(
                recording: _phase == _Phase.recording,
                evaluating: _phase == _Phase.evaluating,
                onTap: busy ? null : _onMicTap,
              ),
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
