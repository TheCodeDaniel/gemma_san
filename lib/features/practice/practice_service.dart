import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

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

class PracticeService {
  List<PhonicsItem> _items = [];
  int _index = 0;
  int _score = 0;
  int _tries = 0;

  static const _correctFeedback = ['You get am!', 'Correct! Well done!', 'Na correct!'];
  static const _incorrectFeedback = ['Try am again!', 'No worry, say am one more time.'];

  int _correctCycle = 0;
  int _incorrectCycle = 0;

  PhonicsItem? get currentItem => _index < _items.length ? _items[_index] : null;
  bool get hasMore => _index < _items.length;
  int get score => _score;
  int get total => _items.length;
  int get currentIndex => _index;
  int get tries => _tries;

  Future<void> loadLevel(int level, AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/data/phonics_curriculum.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final levels = data['levels'] as List;
    final levelData =
        levels.firstWhere((l) => (l as Map<String, dynamic>)['level'] == level, orElse: () => levels.first)
            as Map<String, dynamic>;

    final items = (levelData['items'] as List).map((i) => PhonicsItem.fromJson(i as Map<String, dynamic>)).toList();

    items.shuffle(Random());
    _items = items;
    _index = 0;
    _score = 0;
    _tries = 0;
  }

  EvalResult evaluate(String transcribed) {
    final item = currentItem;
    if (item == null) {
      return const EvalResult(correct: false, feedback: '', transcribed: '');
    }

    final correct = _fuzzyMatch(item.expectedPronunciation, transcribed);

    if (correct) {
      _score++;
      final feedback = _correctFeedback[_correctCycle % _correctFeedback.length];
      _correctCycle++;
      _tries = 0;
      return EvalResult(correct: true, feedback: feedback, transcribed: transcribed);
    } else {
      _tries++;
      final feedback = _incorrectFeedback[_incorrectCycle % _incorrectFeedback.length];
      _incorrectCycle++;
      return EvalResult(correct: false, feedback: feedback, transcribed: transcribed);
    }
  }

  void advance() {
    _index++;
    _tries = 0;
  }

  // ── Fuzzy matching ─────────────────────────────────────────────────────────

  static bool _fuzzyMatch(String expected, String raw) {
    final e = _normalize(expected);
    final t = _normalize(raw);

    if (e.isEmpty) return false;
    if (t == e || t.contains(e)) return true;

    // Check each word in transcription against expected; take the best distance.
    final words = t.split(RegExp(r'\s+'));
    final best = words.fold<int>(999, (min, word) {
      final d = _levenshtein(e, word);
      return d < min ? d : min;
    });

    // Threshold: length 1 → 0, ≤4 → 1, ≤6 → 2, >6 → 3.
    final threshold = switch (e.length) {
      1 => 0,
      <= 4 => 1,
      <= 6 => 2,
      _ => 3,
    };
    return best <= threshold;
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), '').trim();

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final dp = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }

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
