import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/practice_progress_dao.dart';
import 'scheduler.dart';

class PhonicsItem {
  const PhonicsItem({
    required this.id,
    required this.promptText,
    required this.expectedPronunciation,
    required this.difficulty,
  });

  final String id;
  final String promptText;
  final String expectedPronunciation;
  final int difficulty;

  factory PhonicsItem.fromJson(Map<String, dynamic> json) => PhonicsItem(
        id: json['id'] as String,
        promptText: json['prompt_text'] as String,
        expectedPronunciation: json['expected_pronunciation'] as String,
        difficulty: json['difficulty'] as int,
      );
}

class EvalResult {
  const EvalResult({required this.correct, required this.feedback, required this.transcribed});

  final bool correct;
  final String feedback;
  final String transcribed;
}

class SessionStats {
  const SessionStats({
    required this.itemsPracticed,
    required this.correct,
    required this.masteredToday,
    required this.reviewTomorrow,
  });

  final int itemsPracticed;
  final int correct;
  final int masteredToday;
  final int reviewTomorrow;
}

class PracticeService {
  static const _correctFeedback = ['You get am!', 'Correct! Well done!', 'Na correct!'];
  static const _incorrectFeedback = ['Try am again!', 'No worry, say am one more time.'];

  Scheduler? _scheduler;
  PracticeProgressDao? _dao;
  String _childId = 'default';

  PhonicsItem? _current;
  int _tries = 0;
  int _score = 0;
  int _attempted = 0;
  int _masteredThisSession = 0;
  final Set<String> _reviewTomorrow = {};

  int _correctCycle = 0;
  int _incorrectCycle = 0;

  PhonicsItem? get currentItem => _current;
  bool get hasMore => _current != null;
  int get score => _score;
  int get tried => _attempted;
  int get tries => _tries;

  SessionStats get sessionStats => SessionStats(
        itemsPracticed: _attempted,
        correct: _score,
        masteredToday: _masteredThisSession,
        reviewTomorrow: _reviewTomorrow.length,
      );

  Future<void> initialize(String childId, AssetBundle bundle, Database db) async {
    _childId = childId;
    _dao = PracticeProgressDao(db);

    final raw = await bundle.loadString('assets/data/phonics_curriculum.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final allItems = (data['levels'] as List)
        .expand((l) => (l as Map<String, dynamic>)['items'] as List)
        .map((i) => PhonicsItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final progress = await _dao!.loadAll(childId);
    _scheduler = Scheduler(allItems, progress);
    _score = 0;
    _attempted = 0;
    _tries = 0;
    _masteredThisSession = 0;
    _reviewTomorrow.clear();

    _pickNext();
  }

  Future<EvalResult> evaluate(String transcribed) async {
    final item = _current;
    if (item == null) {
      return const EvalResult(correct: false, feedback: '', transcribed: '');
    }

    final correct = _fuzzyMatch(item.expectedPronunciation, transcribed);
    final scheduler = _scheduler!;
    final dao = _dao!;

    final existing = scheduler.progress[item.id] ??
        ItemProgress(itemId: item.id, childId: _childId);

    final updated = correct ? scheduler.applyCorrect(existing) : scheduler.applyWrong(existing);
    scheduler.updateProgress(item.id, updated);

    // Persist immediately — crash-safe.
    await dao.save(updated);

    if (correct) {
      _score++;
      _tries = 0;
      if (updated.masteryScore >= 0.8 && existing.masteryScore < 0.8) {
        _masteredThisSession++;
      }
      final feedback = _correctFeedback[_correctCycle % _correctFeedback.length];
      _correctCycle++;
      return EvalResult(correct: true, feedback: feedback, transcribed: transcribed);
    } else {
      _tries++;
      // Track items scheduled for tomorrow (wrong 2nd+ time).
      if (updated.wrongAttempts >= 2) _reviewTomorrow.add(item.id);
      final feedback = _incorrectFeedback[_incorrectCycle % _incorrectFeedback.length];
      _incorrectCycle++;
      return EvalResult(correct: false, feedback: feedback, transcribed: transcribed);
    }
  }

  void advance() {
    _attempted++;
    _tries = 0;
    _pickNext();
  }

  Future<void> debugDump() async => _dao?.debugDump(_childId);

  void _pickNext() {
    final scheduler = _scheduler;
    if (scheduler == null) {
      _current = null;
      return;
    }
    final next = scheduler.nextItem();
    if (next != null) {
      final isNew = !scheduler.hasProgress(next.id);
      scheduler.recordShown();
      if (isNew) scheduler.recordNewItem();
      debugPrint('[Practice] next item: ${next.id} (${next.promptText})');
    }
    _current = next;
  }

  // ── Fuzzy matching (unchanged) ─────────────────────────────────────────────

  static bool _fuzzyMatch(String expected, String raw) {
    final e = _normalize(expected);
    final t = _normalize(raw);

    if (e.isEmpty) return false;
    if (t == e || t.contains(e)) return true;

    final words = t.split(RegExp(r'\s+'));
    final best = words.fold<int>(999, (best, word) {
      final d = _levenshtein(e, word);
      return d < best ? d : best;
    });

    final threshold = switch (e.length) {
      1 => 0,
      <= 4 => 1,
      <= 6 => 2,
      _ => 3,
    };
    return best <= threshold;
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), '').trim();

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final dp = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) { dp[i][0] = i; }
    for (var j = 0; j <= b.length; j++) { dp[0][j] = j; }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce(min);
      }
    }
    return dp[a.length][b.length];
  }
}
