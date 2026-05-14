import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/route_transitions.dart';
import '../../core/theme/app_theme.dart';
import '../camera/camera_capture_screen.dart' show CameraCaptureScreen, CameraResult;
import '../../data/app_database.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/gemma/tool_definitions.dart';
import '../../services/gemma/tutor_response.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';
import '../home/widgets/mama_san_widget.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/conv_input_row.dart';
import 'widgets/mode_pill.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.gemmaService,
    required this.sttService,
    required this.ttsService,
    this.childId = 'default',
    this.ageRange,
    this.initialText,
    this.quizMode = false,
    this.quizContext,
    this.quizTopic,
  });

  final GemmaService gemmaService;
  final SttService sttService;
  final TtsService ttsService;
  final String childId;
  final String? ageRange;

  /// Pre-fills the text input so the child just needs to tap Send.
  final String? initialText;

  /// When true, starts a quiz session with [quizContext] + [quizTopic].
  final bool quizMode;
  final String? quizContext;
  final String? quizTopic;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatEntry>[];

  StreamSubscription<bool>? _ttsSub;
  StreamSubscription<TutorResponse>? _generateSub;

  bool _sessionReady = false;
  bool _generating = false;
  bool _recording = false;
  bool _transcribing = false;
  bool _speaking = false;
  TutorMode? _currentMode;
  int _quizQuestionNumber = 0;

  static final _sentenceSplit = RegExp(r'(?<=[.!?])\s+');

  bool get _hasMessages => _messages.isNotEmpty;

  OwlState get _owlState {
    if (_recording) return OwlState.listening;
    if (_transcribing || _generating) return OwlState.thinking;
    if (_speaking) return OwlState.speaking;
    return OwlState.idle;
  }

  @override
  void initState() {
    super.initState();
    _ttsSub = widget.ttsService.speakingStream.listen((s) {
      if (mounted) setState(() => _speaking = s);
    });
    _promptController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialText != null) {
      _promptController.text = widget.initialText!;
    }
    _initSession();
  }

  @override
  void dispose() {
    widget.ttsService.stop();
    _generateSub?.cancel();
    _ttsSub?.cancel();
    _recorder.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    widget.gemmaService.endSession();
    super.dispose();
  }

  Future<void> _initSession() async {
    final db = await AppDatabase.get();
    await widget.gemmaService.startSession(
      widget.childId,
      db,
      ageRange: widget.ageRange,
      toolsOverride: widget.quizMode ? kQuizTools : null,
      systemInstructionOverride: widget.quizMode && widget.quizContext != null
          ? kQuizSystemPrompt(widget.quizTopic ?? 'this topic', widget.quizContext!)
          : null,
    );
    if (mounted) setState(() => _sessionReady = true);
  }

  Future<void> _send() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _generating) return;

    await widget.ttsService.stop();

    setState(() {
      _messages.add(_ChatEntry(isUser: true, text: prompt));
      _generating = true;
      _currentMode = null;
      _promptController.clear();
    });
    _scrollToBottom();

    final completer = Completer<void>();
    _generateSub = widget.gemmaService.generate(prompt).listen(
      (response) {
        if (!mounted) return;
        setState(() {
          _currentMode = response.mode;
          if (response.mode == TutorMode.quiz) _quizQuestionNumber++;
          _messages.add(
            _ChatEntry(
              isUser: false,
              text: response.spokenText,
              mode: response.mode,
              illustrationTopicId: response.illustrationTopicId,
              tryDrawingSvg: response.tryDrawingSvg,
              tryDrawingTopic: response.tryDrawingTopic,
            ),
          );
        });
        _scrollToBottom();

        if (response.languageCode != null) {
          widget.ttsService.setResponseLanguage(response.languageCode!);
        }
        for (final sentence in response.spokenText.split(_sentenceSplit)) {
          final s = sentence.trim();
          if (s.isNotEmpty) widget.ttsService.enqueue(s);
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() => _messages.add(_ChatEntry(isUser: false, text: 'Something went wrong: $e')));
        }
        completer.complete();
      },
      onDone: completer.complete,
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      _generateSub = null;
      if (mounted) setState(() => _generating = false);
      _scrollToBottom();
    }
  }

  Future<void> _onCameraTap() async {
    if (_generating || _transcribing || _recording) return;
    if (!await Permission.camera.request().isGranted) return;

    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null || !mounted) return;

    final result = await Navigator.of(context).push<CameraResult?>(
      slideRoute(CameraCaptureScreen(initialFile: file)),
    );
    if (result == null || !mounted) return;

    final bytes = await result.file.readAsBytes();
    await _sendWithImage(bytes, result.file.path, result.query);
  }

  Future<void> _sendWithImage(Uint8List bytes, String path, String query) async {
    await widget.ttsService.stop();

    setState(() {
      _messages.add(_ChatEntry(isUser: true, text: query, imagePath: path));
      _generating = true;
      _currentMode = null;
    });
    _scrollToBottom();

    final completer = Completer<void>();
    _generateSub = widget.gemmaService.generateWithImage(bytes, query: query).listen(
      (response) {
        if (!mounted) return;
        setState(() {
          _currentMode = response.mode;
          _messages.add(_ChatEntry(isUser: false, text: response.spokenText, mode: response.mode));
        });
        _scrollToBottom();
        if (response.languageCode != null) {
          widget.ttsService.setResponseLanguage(response.languageCode!);
        }
        for (final s in response.spokenText.split(_sentenceSplit)) {
          if (s.trim().isNotEmpty) widget.ttsService.enqueue(s.trim());
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() => _messages.add(_ChatEntry(isUser: false, text: 'Something went wrong: $e')));
        }
        completer.complete();
      },
      onDone: completer.complete,
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      _generateSub = null;
      if (mounted) setState(() => _generating = false);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _generating || _transcribing;
    final canSend = _sessionReady && !busy && !_recording && _promptController.text.trim().isNotEmpty;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          widget.ttsService.stop();
          _generateSub?.cancel();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: widget.quizMode
            ? Text('Quiz: $_quizQuestionNumber/5')
            : _hasMessages
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MamaSanWidget(state: _owlState, size: 36),
                      const SizedBox(width: 8),
                      ConvModePill(mode: _currentMode),
                    ],
                  )
                : const Text('Conversation'),
        actions: [
          if (_speaking)
            IconButton(
              icon: const Icon(Icons.volume_off_rounded, color: AppColors.terracotta),
              onPressed: widget.ttsService.stop,
            )
          else
            const SizedBox(width: AppSpacing.minTap),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    MamaSanWidget(state: _owlState, size: 120),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _sessionReady
                          ? const SizedBox(height: 16)
                          : SizedBox(
                              height: 16,
                              child: LinearProgressIndicator(
                                backgroundColor: AppColors.warmCreamDark,
                                valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Say something to get started!',
                      style: AppText.caption(color: AppColors.charcoal.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _hasMessages ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            Expanded(
              child: _messages.isEmpty && !_generating
                  ? const _EmptyPlaceholder()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        return ChatBubble(
                          isUser: m.isUser,
                          text: m.text,
                          mode: m.mode,
                          illustrationTopicId: m.illustrationTopicId,
                          imagePath: m.imagePath,
                          tryDrawingSvg: m.tryDrawingSvg,
                          tryDrawingTopic: m.tryDrawingTopic,
                          avatarId: m.isUser ? widget.childId : null,
                        );
                      },
                    ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _generating
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.terracotta),
                          ),
                          const SizedBox(width: 8),
                          Text('Gemma-San is thinking…', style: AppText.caption()),
                        ],
                      ),
                    )
                  : const SizedBox(height: 4),
            ),
            ConvInputRow(
              controller: _promptController,
              recording: _recording,
              transcribing: _transcribing,
              busy: busy,
              sessionReady: _sessionReady,
              canSend: canSend,
              onMicTap: _toggleMic,
              onSend: _send,
              onCameraTap: _onCameraTap,
            ),
          ],
        ),
      ),
    ),  // Scaffold
  );    // PopScope
  }
}

class _ChatEntry {
  const _ChatEntry({
    required this.isUser,
    required this.text,
    this.mode,
    this.illustrationTopicId,
    this.imagePath,
    this.tryDrawingSvg,
    this.tryDrawingTopic,
  });
  final bool isUser;
  final String text;
  final TutorMode? mode;
  final String? illustrationTopicId;
  final String? imagePath;
  final String? tryDrawingSvg;
  final String? tryDrawingTopic;
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.terracottaLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: AppColors.terracotta.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask me anything!',
              style: AppText.title(color: AppColors.charcoal.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the mic or type below to start.',
              style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.3)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
