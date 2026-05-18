import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/route_transitions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_database.dart';
import '../../data/memory_dao.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/illustration/illustration_registry.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';
import '../conversation/conversation_screen.dart';
import '../onboarding/session_provider.dart';

class LessonSummaryScreen extends ConsumerStatefulWidget {
  const LessonSummaryScreen({
    super.key,
    required this.topic,
    required this.childId,
    required this.gemmaService,
    required this.sttService,
    required this.ttsService,
  });

  final LessonTopic topic;
  final String childId;
  final GemmaService gemmaService;
  final SttService sttService;
  final TtsService ttsService;

  @override
  ConsumerState<LessonSummaryScreen> createState() => _LessonSummaryScreenState();
}

class _LessonSummaryScreenState extends ConsumerState<LessonSummaryScreen> {
  String? _summary;
  List<String> _concepts = [];
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrGenerate();
  }

  Future<void> _loadOrGenerate() async {
    final topic = widget.topic;

    // Use cached summary if it's still fresh AND not poisoned by a previous
    // thinking-channel JSON leak (see GemmaService._extractPlainText).
    if (!topic.needsNewSummary && topic.lessonSummaryJson != null) {
      final parsed = _tryParseCached(topic.lessonSummaryJson!);
      if (parsed != null) {
        setState(() {
          _summary = parsed.summary;
          _concepts = parsed.concepts;
        });
        return;
      }
      debugPrint('[LessonSummary] cached summary is poisoned — regenerating');
    }

    if (!widget.gemmaService.isReady) {
      setState(() => _error = 'AI is still loading. Try again in a moment.');
      return;
    }

    setState(() => _generating = true);

    try {
      final db = await AppDatabase.get();
      final dao = MemoryDao(db);
      final summaries = await dao.sessionSummariesForTopic(widget.childId, topic.topic);

      final result = await widget.gemmaService.generateLessonSummary(
        topic: topic.displayName,
        sessionSummaries: summaries,
      );

      final json = jsonEncode({'summary': result.summary, 'concepts': result.concepts});
      await dao.saveLessonSummary(widget.childId, topic.topic, json);

      if (mounted) {
        setState(() {
          _summary = result.summary;
          _concepts = result.concepts;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not generate summary. Try again later.';
          _generating = false;
        });
      }
    }
  }

  /// Returns the parsed pair, or null if the cache is unreadable or poisoned.
  ({String? summary, List<String> concepts})? _tryParseCached(String json) {
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final summary = m['summary'] as String?;
      final concepts = (m['concepts'] as List?)?.cast<String>() ?? <String>[];
      if (summary != null && _looksLikeThinkingJson(summary)) return null;
      return (summary: summary, concepts: concepts);
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeThinkingJson(String s) {
    final trimmed = s.trimLeft();
    if (!trimmed.startsWith('{')) return false;
    return trimmed.contains('"channels"') || trimmed.contains('"thought"') || trimmed.contains('"role":"assistant"');
  }

  void _openConversation(String initialText) {
    final ageRange = ref.read(currentAgeRangeProvider);
    Navigator.of(context).push(
      slideRoute(
        ConversationScreen(
          gemmaService: widget.gemmaService,
          sttService: widget.sttService,
          ttsService: widget.ttsService,
          childId: widget.childId,
          ageRange: ageRange,
          initialText: initialText,
        ),
      ),
    );
  }

  void _openQuiz() {
    final quizContext = [
      if (_summary != null && _summary!.isNotEmpty) 'Summary: $_summary',
      if (_concepts.isNotEmpty) 'Key concepts: ${_concepts.join('; ')}',
    ].join('\n');
    final ageRange = ref.read(currentAgeRangeProvider);
    Navigator.of(context).push(
      slideRoute(
        ConversationScreen(
          gemmaService: widget.gemmaService,
          sttService: widget.sttService,
          ttsService: widget.ttsService,
          childId: widget.childId,
          ageRange: ageRange,
          quizMode: true,
          quizContext: quizContext.isNotEmpty ? quizContext : null,
          quizTopic: widget.topic.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final hasIllustration = IllustrationRegistry.hasIllustration(topic.topic);

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(title: Text(topic.displayName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasIllustration) _IllustrationBanner(topicId: topic.topic),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeading(icon: PhosphorIconsRegular.bookOpenText, label: 'What You Learned'),
                  const SizedBox(height: AppSpacing.md),
                  _SummaryBody(generating: _generating, summary: _summary, error: _error),
                  if (_concepts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeading(icon: PhosphorIconsRegular.listBullets, label: 'Key Concepts'),
                    const SizedBox(height: AppSpacing.md),
                    _ConceptsList(concepts: _concepts),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _ActionButton(
                    label: 'Continue Learning',
                    icon: PhosphorIconsRegular.chatsCircle,
                    color: AppColors.terracotta,
                    onTap: () => _openConversation("Let's continue learning about ${topic.displayName}"),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActionButton(
                    label: 'Quiz Me',
                    icon: PhosphorIconsRegular.question,
                    color: AppColors.deepGreen,
                    onTap: _openQuiz,
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _IllustrationBanner extends StatelessWidget {
  const _IllustrationBanner({required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      width: size.width,
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.warmCreamDark),
      ),
      child: SvgPicture.asset(
        IllustrationRegistry.getAssetPath(topicId)!,
        width: size.width,
        height: 200,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.forest),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppText.title(color: AppColors.forest)),
      ],
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.generating, this.summary, this.error});
  final bool generating;
  final String? summary;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (generating) return const _Shimmer();
    if (error != null) {
      return Text(error!, style: AppText.body(color: AppColors.terracotta));
    }
    if (summary == null || summary!.isEmpty) {
      return Text('Summary not available yet.', style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.5)));
    }
    return Text(summary!, style: AppText.body());
  }
}

class _ConceptsList extends StatelessWidget {
  const _ConceptsList({required this.concepts});
  final List<String> concepts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: concepts
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: AppColors.forest, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(c, style: AppText.body())),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: AppSpacing.minTap + 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          boxShadow: AppShadows.button(color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppText.button()),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer ──────────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _opacity = Tween<double>(begin: 0.25, end: 0.6).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - AppSpacing.lg * 2;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(width: w),
            const SizedBox(height: 10),
            _Bar(width: w),
            const SizedBox(height: 10),
            _Bar(width: w * 0.75),
            const SizedBox(height: AppSpacing.sm),
            Text('Generating your summary…', style: AppText.caption(color: AppColors.charcoal.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 16,
    decoration: BoxDecoration(color: AppColors.warmCreamDark, borderRadius: BorderRadius.circular(8)),
  );
}
