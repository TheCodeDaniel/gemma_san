import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class ItemProgress {
  const ItemProgress({
    required this.itemId,
    required this.childId,
    this.masteryScore = 0.0,
    this.lastSeenAt,
    this.nextReviewAt,
    this.correctStreak = 0,
    this.totalAttempts = 0,
    this.wrongAttempts = 0,
  });

  final String itemId;
  final String childId;
  final double masteryScore;
  final int? lastSeenAt;
  final int? nextReviewAt;
  final int correctStreak;
  final int totalAttempts;
  final int wrongAttempts;

  ItemProgress copyWith({
    double? masteryScore,
    int? lastSeenAt,
    int? nextReviewAt,
    int? correctStreak,
    int? totalAttempts,
    int? wrongAttempts,
  }) => ItemProgress(
    itemId: itemId,
    childId: childId,
    masteryScore: masteryScore ?? this.masteryScore,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    correctStreak: correctStreak ?? this.correctStreak,
    totalAttempts: totalAttempts ?? this.totalAttempts,
    wrongAttempts: wrongAttempts ?? this.wrongAttempts,
  );

  Map<String, dynamic> toMap() => {
    'item_id': itemId,
    'child_id': childId,
    'mastery_score': masteryScore,
    'last_seen_at': lastSeenAt,
    'next_review_at': nextReviewAt,
    'correct_streak': correctStreak,
    'total_attempts': totalAttempts,
    'wrong_attempts': wrongAttempts,
  };

  factory ItemProgress.fromMap(Map<String, dynamic> m) => ItemProgress(
    itemId: m['item_id'] as String,
    childId: m['child_id'] as String,
    masteryScore: (m['mastery_score'] as num).toDouble(),
    lastSeenAt: m['last_seen_at'] as int?,
    nextReviewAt: m['next_review_at'] as int?,
    correctStreak: m['correct_streak'] as int,
    totalAttempts: m['total_attempts'] as int,
    wrongAttempts: m['wrong_attempts'] as int,
  );
}

class PracticeProgressDao {
  PracticeProgressDao(this._db);

  final Database _db;

  Future<Map<String, ItemProgress>> loadAll(String childId) async {
    final rows = await _db.query('practice_items', where: 'child_id = ?', whereArgs: [childId]);
    return {for (final r in rows) r['item_id'] as String: ItemProgress.fromMap(r)};
  }

  Future<void> save(ItemProgress p) async {
    await _db.insert('practice_items', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> debugDump(String childId) async {
    final rows = await _db.query(
      'practice_items',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'mastery_score DESC',
    );
    debugPrint('[PracticeDB] ${rows.length} rows for child=$childId:');
    for (final r in rows) {
      final next = r['next_review_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(r['next_review_at'] as int).toLocal().toString()
          : 'null';
      debugPrint(
        '[PracticeDB]  ${r['item_id']}: mastery=${(r['mastery_score'] as num).toStringAsFixed(2)}'
        ' streak=${r['correct_streak']} attempts=${r['total_attempts']}/${r['wrong_attempts']}'
        ' next=$next',
      );
    }
  }
}
