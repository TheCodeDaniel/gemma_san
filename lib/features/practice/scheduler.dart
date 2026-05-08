import '../../data/practice_progress_dao.dart';
import '../practice/practice_service.dart';

// SRS review intervals after a correct answer:
//   correct_streak == 1 → +1 hour
//   correct_streak == 2 → +1 day
//   correct_streak == 3 → +3 days
//   correct_streak >= 4 → +7 days
//
// After a wrong answer:
//   first wrong on item  → +5 minutes  (resurfaces within same session)
//   second+ wrong        → +1 day      (try again tomorrow)
//
// Mastery scoring (0.0–1.0):
//   correct → mastery += 0.2 * (1 - mastery)   diminishing-returns growth
//   wrong   → mastery -= 0.3                    hard drop
//   mastered threshold = 0.8

class Scheduler {
  static const int _maxNewPerSession = 3;
  static const int _sessionCap = 15;

  // All items available to this child (level 1, or 1+2 when level 1 is mostly mastered).
  final List<PhonicsItem> _pool;
  final Map<String, ItemProgress> _progress;

  Map<String, ItemProgress> get progress => _progress;
  bool hasProgress(String itemId) => _progress.containsKey(itemId);

  int _newThisSession = 0;
  int _practicedThisSession = 0;

  Scheduler(List<PhonicsItem> allItems, this._progress)
      : _pool = _buildPool(allItems, _progress);

  int get practicedThisSession => _practicedThisSession;

  /// Returns the next item to show, or null when the session is complete.
  PhonicsItem? nextItem() {
    if (_practicedThisSession >= _sessionCap) return null;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Due reviews: next_review_at <= now, not yet mastered, sorted lowest mastery first.
    final due = _pool.where((item) {
      final p = _progress[item.id];
      return p != null && (p.nextReviewAt ?? 0) <= now && p.masteryScore < 0.8;
    }).toList()
      ..sort((a, b) => (_progress[a.id]!.masteryScore).compareTo(_progress[b.id]!.masteryScore));

    if (due.isNotEmpty) return due.first;

    // 2. New items (never seen), up to cap.
    if (_newThisSession < _maxNewPerSession) {
      final unseen = _pool.where((item) => !_progress.containsKey(item.id)).toList();
      if (unseen.isNotEmpty) return unseen.first;
    }

    return null; // session complete
  }

  /// Call after nextItem() is accepted as the current item.
  void recordShown() => _practicedThisSession++;

  /// Call after recordShown() when the item was new (no prior progress record).
  void recordNewItem() => _newThisSession++;

  ItemProgress applyCorrect(ItemProgress p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newStreak = p.correctStreak + 1;
    final newMastery = (p.masteryScore + 0.2 * (1 - p.masteryScore)).clamp(0.0, 1.0);
    final intervalMs = _correctInterval(newStreak);
    return p.copyWith(
      masteryScore: newMastery,
      lastSeenAt: now,
      nextReviewAt: now + intervalMs,
      correctStreak: newStreak,
      totalAttempts: p.totalAttempts + 1,
    );
  }

  ItemProgress applyWrong(ItemProgress p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newMastery = (p.masteryScore - 0.3).clamp(0.0, 1.0);
    final isFirstWrong = p.wrongAttempts == 0;
    final intervalMs = isFirstWrong
        ? const Duration(minutes: 5).inMilliseconds
        : const Duration(days: 1).inMilliseconds;
    return p.copyWith(
      masteryScore: newMastery,
      lastSeenAt: now,
      nextReviewAt: now + intervalMs,
      correctStreak: 0,
      totalAttempts: p.totalAttempts + 1,
      wrongAttempts: p.wrongAttempts + 1,
    );
  }

  void updateProgress(String itemId, ItemProgress p) => _progress[itemId] = p;

  // ── Private ────────────────────────────────────────────────────────────────

  static List<PhonicsItem> _buildPool(List<PhonicsItem> all, Map<String, ItemProgress> progress) {
    // Always include difficulty-1 items.
    // Mix in difficulty-2 if ≥70% of difficulty-1 items are mastered.
    final d1 = all.where((i) => i.difficulty == 1).toList();
    final d1Mastered = d1.where((i) => (progress[i.id]?.masteryScore ?? 0) >= 0.8).length;
    final includeD2 = d1.isNotEmpty && d1Mastered / d1.length >= 0.7;

    return all.where((i) => i.difficulty == 1 || (includeD2 && i.difficulty == 2)).toList();
  }

  static int _correctInterval(int streak) => switch (streak) {
        1 => const Duration(hours: 1).inMilliseconds,
        2 => const Duration(days: 1).inMilliseconds,
        3 => const Duration(days: 3).inMilliseconds,
        _ => const Duration(days: 7).inMilliseconds,
      };
}
