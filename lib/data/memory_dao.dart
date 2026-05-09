import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class SessionRecord {
  const SessionRecord({
    required this.sessionId,
    required this.childId,
    this.topic,
    required this.startedAt,
    this.endedAt,
    this.turnCount = 0,
    this.summaryJson,
  });

  final String sessionId;
  final String childId;
  final String? topic;
  final int startedAt;
  final int? endedAt;
  final int turnCount;
  final String? summaryJson;

  factory SessionRecord.fromMap(Map<String, dynamic> m) => SessionRecord(
    sessionId: m['session_id'] as String,
    childId: m['child_id'] as String,
    topic: m['topic'] as String?,
    startedAt: m['started_at'] as int,
    endedAt: m['ended_at'] as int?,
    turnCount: m['turn_count'] as int,
    summaryJson: m['summary_json'] as String?,
  );
}

class MemoryFact {
  const MemoryFact({
    required this.childId,
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  final String childId;
  final String key;
  final String value;
  final int updatedAt;

  factory MemoryFact.fromMap(Map<String, dynamic> m) => MemoryFact(
    childId: m['child_id'] as String,
    key: m['key'] as String,
    value: m['value'] as String,
    updatedAt: m['updated_at'] as int,
  );
}

class MemoryDao {
  MemoryDao(this._db);

  final Database _db;

  // ── Sessions ────────────────────────────────────────────────────────────────

  Future<String> createSession(String childId) async {
    final id = _uuid();
    await _db.insert('sessions', {
      'session_id': id,
      'child_id': childId,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'turn_count': 0,
    });
    return id;
  }

  Future<void> closeSession({
    required String sessionId,
    required int endedAt,
    required int turnCount,
    required String summaryJson,
  }) async {
    await _db.update(
      'sessions',
      {'ended_at': endedAt, 'turn_count': turnCount, 'summary_json': summaryJson},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<SessionRecord>> recentSessions(String childId, {int limit = 3}) async {
    final rows = await _db.query(
      'sessions',
      where: 'child_id = ? AND summary_json IS NOT NULL',
      whereArgs: [childId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(SessionRecord.fromMap).toList();
  }

  // ── Long-term memory ────────────────────────────────────────────────────────

  Future<void> saveFact(String childId, String key, String value) async {
    await _db.insert(
      'long_term_memory',
      {
        'child_id': childId,
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MemoryFact>> allFacts(String childId) async {
    final rows = await _db.query(
      'long_term_memory',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(MemoryFact.fromMap).toList();
  }

  Future<void> debugDump(String childId) async {
    final sessions = await recentSessions(childId, limit: 10);
    debugPrint('[Memory] ${sessions.length} recent sessions:');
    for (final s in sessions) {
      final id = s.sessionId.length > 8 ? s.sessionId.substring(0, 8) : s.sessionId;
      debugPrint('[Memory]  $id… turns=${s.turnCount} summary=${s.summaryJson}');
    }
    final facts = await allFacts(childId);
    debugPrint('[Memory] ${facts.length} long-term facts:');
    for (final f in facts) {
      debugPrint('[Memory]  ${f.key}: ${f.value}');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _uuid() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // Exposed for GemmaService compaction — builds a memory context string < 200 tokens.
  static String buildMemoryContext(List<MemoryFact> facts, List<SessionRecord> sessions) {
    if (facts.isEmpty && sessions.isEmpty) return '';

    final buf = StringBuffer('[Memory from previous sessions: ');

    if (facts.isNotEmpty) {
      final factTexts = facts.take(8).map((f) => f.value).join('; ');
      buf.write('Known facts about this child: $factTexts. ');
    }

    if (sessions.isNotEmpty) {
      final recentMessages = sessions
          .map((s) {
            if (s.summaryJson == null) return null;
            try {
              final m = jsonDecode(s.summaryJson!) as Map<String, dynamic>;
              final turns = (m['user_turns'] as List?)?.cast<String>() ?? [];
              return turns.take(2).join(', ');
            } catch (_) {
              return null;
            }
          })
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .take(3)
          .join('; ');

      if (recentMessages.isNotEmpty) {
        buf.write('Recent topics the child asked about: $recentMessages.');
      }
    }

    buf.write(']');
    return buf.toString();
  }
}
