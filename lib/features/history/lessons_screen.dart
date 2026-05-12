import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_database.dart';
import '../../data/memory_dao.dart';
import '../../services/gemma/gemma_service.dart';
import '../../services/illustration/illustration_registry.dart';
import '../../services/stt/stt_service.dart';
import '../../services/tts/tts_service.dart';
import '../home/widgets/mama_san_widget.dart';
import 'lesson_summary_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({
    super.key,
    required this.childId,
    required this.gemmaService,
    required this.sttService,
    required this.ttsService,
  });

  final String childId;
  final GemmaService gemmaService;
  final SttService sttService;
  final TtsService ttsService;

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  late Future<List<LessonTopic>> _topicsFuture;

  @override
  void initState() {
    super.initState();
    _topicsFuture = _loadTopics();
  }

  Future<List<LessonTopic>> _loadTopics() async {
    final db = await AppDatabase.get();
    final dao = MemoryDao(db);
    return dao.allTopicsForChild(widget.childId);
  }

  void _openSummary(LessonTopic topic) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LessonSummaryScreen(
              topic: topic,
              childId: widget.childId,
              gemmaService: widget.gemmaService,
              sttService: widget.sttService,
              ttsService: widget.ttsService,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          final next = _loadTopics();
          setState(() {
            _topicsFuture = next;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(title: const Text('My Lessons')),
      body: FutureBuilder<List<LessonTopic>>(
        future: _topicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.forest));
          }
          final topics = snapshot.data ?? [];
          if (topics.isEmpty) return const _EmptyLessonsState();
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: topics.length,
            itemBuilder: (_, i) => _LessonCard(topic: topics[i], onTap: () => _openSummary(topics[i])),
          );
        },
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyLessonsState extends StatelessWidget {
  const _EmptyLessonsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MamaSanWidget(state: OwlState.idle, size: 140),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No lessons yet!',
              style: AppText.title(color: AppColors.charcoal.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Go have a conversation and your lessons\nwill appear here automatically.',
              style: AppText.body(color: AppColors.charcoal.withValues(alpha: 0.4)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lesson card ──────────────────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.topic, required this.onTap});

  final LessonTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasIllustration = IllustrationRegistry.hasIllustration(topic.topic);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.warmCreamDark, width: 1),
        ),
        child: Row(
          children: [
            _Thumbnail(topicId: topic.topic, hasIllustration: hasIllustration),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.displayName, style: AppText.title(), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_formatDate(topic.lastVisited), style: AppText.caption()),
                    const SizedBox(height: AppSpacing.sm),
                    _MasteryBadge(mastery: topic.mastery),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Icon(PhosphorIconsRegular.caretRight, size: 18, color: AppColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.topicId, required this.hasIllustration});

  final String topicId;
  final bool hasIllustration;

  @override
  Widget build(BuildContext context) {
    const size = 100.0;

    if (hasIllustration) {
      return Container(
        margin: EdgeInsets.all(16),
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: SvgPicture.asset(
          IllustrationRegistry.getAssetPath(topicId)!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(16),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.encourage.withValues(alpha: .5)),
      child: Icon(PhosphorIcons.bookOpen()),
    );
  }
}

class _MasteryBadge extends StatelessWidget {
  const _MasteryBadge({required this.mastery});

  final MasteryLevel mastery;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mastery) {
      MasteryLevel.learning => ('Learning', AppColors.terracotta),
      MasteryLevel.gettingThere => ('Getting there', AppColors.deepGreen),
      MasteryLevel.mastered => ('Mastered', AppColors.forest),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(label, style: AppText.caption(color: color)),
    );
  }
}
