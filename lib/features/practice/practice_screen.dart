import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../services/stt/stt_service.dart';
import 'practice_service.dart';

const _hardcodedLevel = 1;
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

  @override
  void initState() {
    super.initState();
    _loadCurriculum();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadCurriculum() async {
    await _service.loadLevel(_hardcodedLevel, rootBundle);
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
      if (path != null) {
        transcribed = await widget.sttService.transcribe(path);
      }
    } catch (_) {}

    final result = _service.evaluate(transcribed);

    setState(() {
      _lastCorrect = result.correct;
      _feedbackText = result.feedback;
      _phase = _Phase.feedback;
    });

    final delay = result.correct ? 700 : 800;
    await Future.delayed(Duration(milliseconds: delay));
    if (!mounted) return;

    if (result.correct || _service.tries >= _maxTriesPerItem) {
      _service.advance();
    }

    setState(() => _phase = _Phase.ready);
  }

  void _endPractice() => Navigator.of(context).pop();

  void _restartPractice() {
    _service.loadLevel(_hardcodedLevel, rootBundle).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_service.hasMore) {
      return _SummaryScreen(
        score: _service.score,
        total: _service.total,
        onRestart: _restartPractice,
        onBack: _endPractice,
      );
    }

    final item = _service.currentItem!;
    final cs = Theme.of(context).colorScheme;
    final busy = _phase == _Phase.evaluating || _phase == _Phase.feedback;

    return Scaffold(
      appBar: AppBar(
        title: Text('Practice — Level $_hardcodedLevel'),
        backgroundColor: cs.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(label: Text('${_service.score} / ${_service.total}'), backgroundColor: cs.primaryContainer),
          ),
          TextButton(onPressed: _endPractice, child: const Text('End')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _service.currentIndex / _service.total,
              backgroundColor: cs.surfaceContainerHighest,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
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
                  const SizedBox(height: 32),
                  AnimatedOpacity(
                    opacity: _phase == _Phase.feedback ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: _FeedbackBanner(correct: _lastCorrect, text: _feedbackText),
                  ),
                  const SizedBox(height: 32),
                  _MicButton(phase: _phase, onTap: busy ? null : _onMicTap),
                  const SizedBox(height: 16),
                  Text(_phaseHint(_phase), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _phaseHint(_Phase phase) => switch (phase) {
    _Phase.ready => 'Tap mic and say the word',
    _Phase.recording => 'Listening… tap to stop',
    _Phase.evaluating => 'Checking…',
    _Phase.feedback => '',
  };
}

// ── Private widgets ────────────────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  const _WordCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      height: 180,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.correct, required this.text});
  final bool correct;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(correct ? Icons.check_circle : Icons.replay, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.phase, required this.onTap});
  final _Phase phase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recording = phase == _Phase.recording;
    final busy = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording
              ? Colors.red
              : busy
              ? cs.surfaceContainerHighest
              : cs.primary,
        ),
        child: phase == _Phase.evaluating
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                recording ? Icons.stop : Icons.mic,
                size: 32,
                color: busy && !recording ? cs.onSurfaceVariant : Colors.white,
              ),
      ),
    );
  }
}

class _SummaryScreen extends StatelessWidget {
  const _SummaryScreen({required this.score, required this.total, required this.onRestart, required this.onBack});

  final int score;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0 : (score * 100 ~/ total);
    final message = pct == 100
        ? 'You don pass all! You too much!'
        : pct >= 70
        ? 'Good work! Practice more, you go shine!'
        : 'No worry, try am again — you go get am!';

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Done'), backgroundColor: cs.inversePrimary),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score / $total',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('correct', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 40),
              FilledButton(onPressed: onRestart, child: const Text('Try Again')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ),
      ),
    );
  }
}
