import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_database.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/gemma/tutor_response.dart';
import '../../services/illustration/illustration_registry.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';
import '../home/widgets/mama_san_widget.dart';

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
  TutorMode? _currentMode;

  static final _sentenceSplit = RegExp(r'(?<=[.!?])\s+');

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
    _initSession();
  }

  @override
  void dispose() {
    _ttsSub?.cancel();
    _recorder.dispose();
    _promptController.dispose();
    _scrollController.dispose();
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
      _currentMode = null;
      _promptController.clear();
    });
    _scrollToBottom();

    try {
      await for (final response in widget.gemmaService.generate(prompt)) {
        setState(() {
          _currentMode = response.mode;
          _messages.add(_Message(
            isUser: false,
            text: response.spokenText,
            mode: response.mode,
            illustrationTopicId: response.illustrationTopicId,
          ));
        });
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

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Column(
          children: [
            _ConvHeader(
              currentMode: _currentMode,
              speaking: _speaking,
              onStopTts: widget.ttsService.stop,
            ),

            // ── Owl + status bar ──────────────────────────────────────────
            Padding(
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
                ],
              ),
            ),

            // ── Mode indicator pill ───────────────────────────────────────
            _ModePill(mode: _currentMode),
            const SizedBox(height: 4),

            // ── Chat list ─────────────────────────────────────────────────
            Expanded(
              child: _messages.isEmpty && !_generating
                  ? const _EmptyPlaceholder()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
                    ),
            ),

            // ── Thinking indicator ────────────────────────────────────────
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.terracotta,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Mama San is thinking…', style: AppText.caption()),
                        ],
                      ),
                    )
                  : const SizedBox(height: 4),
            ),

            // ── Input row ─────────────────────────────────────────────────
            _InputRow(
              controller: _promptController,
              recording: _recording,
              transcribing: _transcribing,
              busy: busy,
              sessionReady: _sessionReady,
              canSend: canSend,
              onMicTap: _toggleMic,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _ConvHeader extends StatelessWidget {
  const _ConvHeader({
    required this.currentMode,
    required this.speaking,
    required this.onStopTts,
  });

  final TutorMode? currentMode;
  final bool speaking;
  final VoidCallback onStopTts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppSpacing.minTap,
              height: AppSpacing.minTap,
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsRegular.arrowLeft, color: AppColors.charcoal, size: 22),
            ),
          ),
          Expanded(
            child: Text('Conversation', style: AppText.title(), textAlign: TextAlign.center),
          ),
          if (speaking)
            GestureDetector(
              onTap: onStopTts,
              child: Container(
                width: AppSpacing.minTap,
                height: AppSpacing.minTap,
                alignment: Alignment.center,
                child: const Icon(PhosphorIconsRegular.speakerX, color: AppColors.terracotta, size: 22),
              ),
            )
          else
            const SizedBox(width: AppSpacing.minTap),
        ],
      ),
    );
  }
}

// ── Input row ──────────────────────────────────────────────────────────────

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.recording,
    required this.transcribing,
    required this.busy,
    required this.sessionReady,
    required this.canSend,
    required this.onMicTap,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool recording, transcribing, busy, sessionReady, canSend;
  final VoidCallback onMicTap;
  final VoidCallback onSend;

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
          _MicPill(
            recording: recording,
            transcribing: transcribing,
            disabled: busy || !sessionReady,
            onTap: onMicTap,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.warmCreamDark,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.terracottaLight, width: 1.2),
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
          _SendButton(enabled: canSend, onTap: onSend),
        ],
      ),
    );
  }
}

class _MicPill extends StatefulWidget {
  const _MicPill({
    required this.recording,
    required this.transcribing,
    required this.disabled,
    required this.onTap,
  });

  final bool recording, transcribing, disabled;
  final VoidCallback onTap;

  @override
  State<_MicPill> createState() => _MicPillState();
}

class _MicPillState extends State<_MicPill> with SingleTickerProviderStateMixin {
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

class _SendButton extends StatefulWidget {
  const _SendButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> with SingleTickerProviderStateMixin {
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
          child: Icon(
            PhosphorIconsRegular.paperPlaneTilt,
            color: Colors.white,
            size: 22,
          ),
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

// ── Chat bubble ────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final assetPath = message.illustrationTopicId != null
        ? IllustrationRegistry.getAssetPath(message.illustrationTopicId!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.terracottaLight,
              ),
              alignment: Alignment.center,
              child: Text('M', style: AppText.caption(color: AppColors.terracotta).copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.terracotta : AppColors.warmCreamDark,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: AppShadows.card,
                  ),
                  child: Text(
                    message.text,
                    style: AppText.body(
                      color: isUser ? Colors.white : AppColors.charcoal,
                    ),
                  ),
                ),
                if (!isUser && message.mode != null) ...[
                  const SizedBox(height: 4),
                  _ModeTag(mode: message.mode!),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Illustration view ──────────────────────────────────────────────────────

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
    } catch (_) {}
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
        child: Container(
          width: thumbWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              SvgPicture.string(_svgData!, width: thumbWidth, fit: BoxFit.contain),
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
      ),
    );
  }
}

// ── Mode pill (persistent header pill, faded when no mode yet) ────────────

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});
  final TutorMode? mode;

  @override
  Widget build(BuildContext context) {
    if (mode == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warmCreamDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '· · ·',
          style: AppText.caption(color: AppColors.charcoal.withValues(alpha: 0.25)),
        ),
      );
    }
    final (label, color) = switch (mode!) {
      TutorMode.socratic  => ('Socratic',    AppColors.socratic),
      TutorMode.direct    => ('Direct',      AppColors.direct),
      TutorMode.encourage => ('Encouraging', AppColors.encourage),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: AppText.caption(color: color).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

// ── Empty state placeholder ────────────────────────────────────────────────

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
            Icon(
              PhosphorIconsRegular.microphone,
              size: 36,
              color: AppColors.charcoal.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap the mic and ask me anything…',
              style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.32)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode tag ───────────────────────────────────────────────────────────────

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.mode});
  final TutorMode mode;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode) {
      TutorMode.socratic => ('Socratic', AppColors.socratic),
      TutorMode.direct => ('Direct', AppColors.direct),
      TutorMode.encourage => ('Encouraging', AppColors.encourage),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppText.caption(color: color).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
