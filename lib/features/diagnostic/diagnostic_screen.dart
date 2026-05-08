import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../services/gemma/gemma_service.dart';
import '../../services/gemma/tutor_response.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final _gemmaService = GemmaService();
  final _sttService = SttService();
  final _ttsService = TtsService();
  final _recorder = AudioRecorder();
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<bool>? _ttsSub;

  String _status = 'Starting up…';
  int _downloadProgress = 0;
  bool _loading = false;
  bool _generating = false;
  bool _recording = false;
  bool _recorderReady = false;
  bool _transcribing = false;
  bool _speaking = false;
  String _output = '';
  TutorMode? _currentMode;

  bool get _bothReady => _gemmaService.isReady && _sttService.isReady;

  static final _sentenceSplit = RegExp(r'(?<=[.!?])\s+');

  @override
  void initState() {
    super.initState();
    _ttsService.initialize();
    _ttsSub = _ttsService.speakingStream.listen((speaking) {
      if (mounted) setState(() => _speaking = speaking);
    });
    _promptController.addListener(() {
      if (mounted) setState(() {});
    });
    // Auto-initialize so the user never has to tap "Set up" manually.
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  @override
  void dispose() {
    _ttsSub?.cancel();
    _gemmaService.dispose();
    _sttService.dispose();
    _ttsService.dispose();
    _recorder.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() {
      _loading = true;
      _downloadProgress = 0;
      _status = 'Setting up your tutor…';
    });

    try {
      setState(() => _status = 'Copying model to app storage (one-time, ~2 min)…');
      await _gemmaService.initialize(
        onProgress: (p) => setState(() {
          _downloadProgress = p;
          _status = 'Gemma: $p% (1 of 2)';
        }),
      );
      setState(() => _status = 'Gemma ready. Loading Whisper…');

      setState(() => _downloadProgress = 0);
      await _sttService.initialize(
        onProgress: (p) => setState(() {
          _downloadProgress = p;
          _status = 'Whisper: $p% (2 of 2)';
        }),
      );

      await Permission.microphone.request();
      setState(() => _status = 'Ready — speak or type.');
    } catch (e) {
      setState(() => _status = 'Setup failed — tap Retry to try again.\n$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    if (_generating || !_gemmaService.isReady) return;

    await _ttsService.stop();

    setState(() {
      _generating = true;
      _output = '';
      _currentMode = null;
      _promptController.clear();
    });

    try {
      await for (final response in _gemmaService.generate(prompt)) {
        setState(() {
          _currentMode = response.mode;
          _output = response.spokenText;
        });
        _scrollToBottom();
        for (final sentence in response.spokenText.split(_sentenceSplit)) {
          final s = sentence.trim();
          if (s.isNotEmpty) _ttsService.enqueue(s);
        }
      }
    } catch (e) {
      setState(() => _output = 'Generation error: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _toggleMic() async {
    if (_recording) {
      await _stopAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_transcribing || _generating) return;

    if (!await Permission.microphone.isGranted) {
      setState(() => _status = 'Microphone permission denied. Run setup again.');
      return;
    }

    setState(() {
      _recording = true;
      _recorderReady = false;
      _status = 'Starting mic…';
    });

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/stt_input.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: path,
      );
      setState(() {
        _recorderReady = true;
        _status = 'Recording… tap mic to stop';
      });
    } catch (e) {
      setState(() {
        _recording = false;
        _recorderReady = false;
        _status = 'Recording error: $e';
      });
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_recording || !_recorderReady) return;

    setState(() {
      _recording = false;
      _recorderReady = false;
      _transcribing = true;
      _status = 'Transcribing…';
    });

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      setState(() {
        _transcribing = false;
        _status = 'Stop error: $e';
      });
      return;
    }

    try {
      if (path != null) {
        final text = await _sttService.transcribe(path);
        setState(() => _promptController.text = text);
      }
    } catch (e) {
      setState(() => _status = 'Transcription error: $e');
    } finally {
      setState(() {
        _transcribing = false;
        _status = 'Ready — speak or type.';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma-San — Diagnostic'),
        backgroundColor: cs.inversePrimary,
        actions: [
          if (_ttsService.isReady)
            IconButton(
              icon: Icon(
                _speaking ? Icons.volume_up : Icons.volume_off,
                color: _speaking ? Colors.red : cs.onSurfaceVariant,
              ),
              onPressed: _speaking ? () => _ttsService.stop() : null,
              tooltip: _speaking ? 'Stop speaking' : 'Audio idle',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusBanner(status: _status),
              const SizedBox(height: 8),
              if (_loading) _ProgressBar(progress: _downloadProgress),
              if (!_bothReady) ...[
                const SizedBox(height: 8),
                FilledButton(onPressed: _loading ? null : _setup, child: const Text('Retry')),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _OutputArea(output: _output, scrollController: _scrollController),
              ),
              if (_currentMode != null) ...[
                const SizedBox(height: 8),
                _ModePill(mode: _currentMode!),
              ],
              const Divider(height: 24),
              _InputRow(
                controller: _promptController,
                gemmaReady: _gemmaService.isReady,
                sttReady: _sttService.isReady,
                generating: _generating,
                transcribing: _transcribing,
                recording: _recording,
                onSend: _send,
                onMicTap: _toggleMic,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    debugPrint('Status update: $status');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress / 100),
      ],
    );
  }
}

class _OutputArea extends StatelessWidget {
  const _OutputArea({required this.output, required this.scrollController});
  final String output;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: SelectableText(
          output.isEmpty ? '(response will stream here)' : output,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.gemmaReady,
    required this.sttReady,
    required this.generating,
    required this.transcribing,
    required this.recording,
    required this.onSend,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final bool gemmaReady;
  final bool sttReady;
  final bool generating;
  final bool transcribing;
  final bool recording;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    final busy = generating || transcribing;
    final canSend = gemmaReady && !busy && !recording && controller.text.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (sttReady) ...[_MicButton(recording: recording, disabled: busy, onTap: onMicTap), const SizedBox(width: 8)],
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: recording
                  ? 'Recording… tap mic to stop'
                  : transcribing
                  ? 'Transcribing…'
                  : 'Type a prompt…',
              border: const OutlineInputBorder(),
            ),
            maxLines: 4,
            minLines: 1,
            enabled: gemmaReady && !busy && !recording,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: canSend ? onSend : null,
          child: generating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send'),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});
  final TutorMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode) {
      TutorMode.socratic => ('? Socratic', Colors.green),
      TutorMode.direct => ('📖 Direct', Colors.blue),
      TutorMode.encourage => ('❤ Encourage', Colors.pink),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.recording, required this.disabled, required this.onTap});

  final bool recording;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: recording
              ? Colors.red
              : disabled
              ? cs.surfaceContainerHighest
              : cs.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          recording ? Icons.stop : Icons.mic,
          color: disabled && !recording ? cs.onSurfaceVariant : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
