import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';
import '../conversation/conversation_screen.dart';
import '../diagnostic/diagnostic_screen.dart';
import '../history/lessons_screen.dart';
import '../onboarding/age_picker_screen.dart';
import '../onboarding/session_provider.dart';
import '../practice/practice_screen.dart';
import 'widgets/app_button.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/mama_san_widget.dart';
import 'widgets/status_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
          setState(() => _statusText = 'Downloading voice… $pct%');
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
    final childId = ref.read(currentAvatarIdProvider);
    final ageRange = ref.read(currentAgeRangeProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          gemmaService: _gemmaService,
          sttService: _sttService,
          ttsService: _ttsService,
          childId: childId,
          ageRange: ageRange,
        ),
      ),
    );
  }

  void _goSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgePickerScreen(isFromSettings: true)),
    );
  }

  void _goPractice() {
    if (!_sttReady) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PracticeScreen(sttService: _sttService)),
    );
  }

  void _goLessons() {
    final childId = ref.read(currentAvatarIdProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonsScreen(
          childId: childId,
          gemmaService: _gemmaService,
          sttService: _sttService,
          ttsService: _ttsService,
        ),
      ),
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
              HomeTopBar(
                onDebugLongPress: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
                ),
                onSettings: _goSettings,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                flex: 5,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.sunYellow.withValues(alpha: 0.18),
                              AppColors.warmCream.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      MamaSanWidget(state: _owlState, size: 200),
                    ],
                  ),
                ),
              ),
              Text('Gemma-San', style: AppText.caption(color: AppColors.terracotta)),
              const SizedBox(height: 6),
              Text('Welcome back!', style: AppText.heading(), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'What do you want to do today?',
                style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _statusText.isNotEmpty
                    ? StatusRow(text: _statusText, pct: _downloadPct)
                    : const SizedBox(height: 20),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Start Learning',
                icon: PhosphorIconsRegular.chatsCircle,
                color: AppColors.terracotta,
                enabled: _ready,
                onTap: _goConversation,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Practice',
                icon: PhosphorIconsRegular.pencilSimpleLine,
                color: AppColors.deepGreen,
                enabled: _sttReady,
                onTap: _goPractice,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'My Lessons',
                icon: PhosphorIconsRegular.books,
                color: AppColors.forest,
                enabled: true,
                onTap: _goLessons,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
