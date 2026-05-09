import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../data/app_database.dart';
import '../../data/memory_dao.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/gemma/tutor_response.dart';
import '../../services/illustration/illustration_registry.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.gemmaService,
    required this.sttService,
    required this.ttsService,
  });

  final GemmaService gemmaService;
  final SttService sttService;
  final TtsService ttsService;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _recorder = AudioRecorder();
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_Message>[];

  StreamSubscription<bool>? _ttsSub;

  bool _sessionReady = false;
  bool _generating = false;
  bool _recording = false;
  bool _transcribing = false;
  bool _speaking = false;

  static final _sentenceSplit = RegExp(r'(?<=[.!?])\s+');

  @override
  void initState() {
    super.initState();
    _ttsSub = widget.ttsService.speakingStream.listen((s) {
      if (mounted) setState(() => _speaking = s);
    });
    _promptController.addListener(() {
      if (mounted) setState(() {});
    });
    _initSession();
  }

  @override
  void dispose() {
    _ttsSub?.cancel();
    _recorder.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    // Fire-and-forget: compaction is pure-Dart JSON, completes in microseconds.
    widget.gemmaService.endSession();
    super.dispose();
  }

  Future<void> _initSession() async {
    final db = await AppDatabase.get();
    await widget.gemmaService.startSession('default', db);
    if (mounted) setState(() => _sessionReady = true);
  }

  Future<void> _send() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _generating) return;

    await widget.ttsService.stop();

    setState(() {
      _messages.add(_Message(isUser: true, text: prompt));
      _generating = true;
      _promptController.clear();
    });
    _scrollToBottom();

    try {
      await for (final response in widget.gemmaService.generate(prompt)) {
        setState(() => _messages.add(_Message(
          isUser: false,
          text: response.spokenText,
          mode: response.mode,
          illustrationTopicId: response.illustrationTopicId,
        )));
        _scrollToBottom();

        if (response.languageCode != null) {
          await widget.ttsService.setResponseLanguage(response.languageCode!);
        }
        for (final sentence in response.spokenText.split(_sentenceSplit)) {
          final s = sentence.trim();
          if (s.isNotEmpty) widget.ttsService.enqueue(s);
        }
      }
    } catch (e) {
      setState(() => _messages.add(_Message(isUser: false, text: 'Something went wrong: $e')));
    } finally {
      setState(() => _generating = false);
      _scrollToBottom();
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

    if (!await Permission.microphone.isGranted) return;

    setState(() {
      _recording = true;
      _transcribing = false;
    });

    try {
      final dir = await getTemporaryDirectory();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: '${dir.path}/conv_input.wav',
      );
    } catch (_) {
      setState(() => _recording = false);
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _transcribing = true;
    });

    try {
      final path = await _recorder.stop();
      if (path != null) {
        final text = await widget.sttService.transcribe(path);
        if (mounted) setState(() => _promptController.text = text);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _endAndDump() async {
    await widget.gemmaService.endSession();
    final db = await AppDatabase.get();
    await MemoryDao(db).debugDump('default');
    if (!mounted) return;
    // Re-start session so the screen stays usable.
    await widget.gemmaService.startSession('default', db);
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
    final busy = _generating || _transcribing;
    final canSend = _sessionReady && !busy && !_recording && _promptController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation'),
        backgroundColor: cs.inversePrimary,
        actions: [
          if (_speaking)
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.red),
              onPressed: widget.ttsService.stop,
              tooltip: 'Stop speaking',
            ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _sessionReady ? _endAndDump : null,
            tooltip: 'Save & dump memory (debug)',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_sessionReady)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 2),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
              ),
            ),
            if (_generating)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Text('Thinking…', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MicButton(
                    recording: _recording,
                    transcribing: _transcribing,
                    disabled: busy || !_sessionReady,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        hintText: _recording
                            ? 'Recording… tap mic to stop'
                            : _transcribing
                            ? 'Transcribing…'
                            : 'Say something…',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      enabled: _sessionReady && !busy && !_recording,
                      onSubmitted: canSend ? (_) => _send() : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSend ? _send : null,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data ───────────────────────────────────────────────────────────────────

class _Message {
  const _Message({required this.isUser, required this.text, this.mode, this.illustrationTopicId});
  final bool isUser;
  final String text;
  final TutorMode? mode;
  final String? illustrationTopicId;
}

// ── Private widgets ────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _Message message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final assetPath = message.illustrationTopicId != null
        ? IllustrationRegistry.getAssetPath(message.illustrationTopicId!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text('G', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (assetPath != null) ...[
                  _IllustrationView(assetPath: assetPath),
                  const SizedBox(height: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? cs.onPrimary : cs.onSurface,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                if (!isUser && message.mode != null) ...[
                  const SizedBox(height: 3),
                  _ModeTag(mode: message.mode!),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _IllustrationView extends StatefulWidget {
  const _IllustrationView({required this.assetPath});
  final String assetPath;

  @override
  State<_IllustrationView> createState() => _IllustrationViewState();
}

class _IllustrationViewState extends State<_IllustrationView> {
  double _opacity = 0.0;
  String? _svgData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DefaultAssetBundle.of(context).loadString(widget.assetPath);
      if (mounted) {
        setState(() {
          _svgData = data;
          _opacity = 1.0;
        });
      }
    } catch (_) {
      // SVG file not yet placed — silently show nothing.
    }
  }

  void _openFullscreen() {
    final svg = _svgData;
    if (svg == null) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: SvgPicture.string(svg, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
                tooltip: 'Close',
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
              left: 0,
              right: 0,
              child: const Text(
                'Pinch to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_svgData == null) return const SizedBox.shrink();
    final thumbWidth = MediaQuery.of(context).size.width * 0.65;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeIn,
      child: GestureDetector(
        onTap: _openFullscreen,
        child: Stack(
          children: [
            SvgPicture.string(
              _svgData!,
              width: thumbWidth,
              fit: BoxFit.contain,
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.mode});
  final TutorMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode) {
      TutorMode.socratic => ('? Socratic', Colors.green),
      TutorMode.direct => ('📖 Direct', Colors.blue),
      TutorMode.encourage => ('❤ Encourage', Colors.pink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.recording,
    required this.transcribing,
    required this.disabled,
    required this.onTap,
  });

  final bool recording;
  final bool transcribing;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording
              ? Colors.red
              : disabled
              ? cs.surfaceContainerHighest
              : cs.primary,
        ),
        child: transcribing
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                recording ? Icons.stop : Icons.mic,
                size: 22,
                color: disabled && !recording ? cs.onSurfaceVariant : Colors.white,
              ),
      ),
    );
  }
}
