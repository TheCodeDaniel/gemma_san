import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get() async {
    _db ??= await openDatabase(
      'gemma_san.db',
      version: 3,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _db!;
  }

  static Future<void> _create(Database db, int version) async {
    await _createV1(db);
    await _createV2(db);
    await _createV3(db);
  }

  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createV2(db);
    if (oldVersion < 3) await _createV3(db);
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE practice_items (
        item_id        TEXT NOT NULL,
        child_id       TEXT NOT NULL,
        mastery_score  REAL NOT NULL DEFAULT 0.0,
        last_seen_at   INTEGER,
        next_review_at INTEGER,
        correct_streak INTEGER NOT NULL DEFAULT 0,
        total_attempts INTEGER NOT NULL DEFAULT 0,
        wrong_attempts INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (item_id, child_id)
      )
    ''');
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        session_id   TEXT PRIMARY KEY,
        child_id     TEXT NOT NULL,
        topic        TEXT,
        started_at   INTEGER NOT NULL,
        ended_at     INTEGER,
        turn_count   INTEGER NOT NULL DEFAULT 0,
        summary_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE long_term_memory (
        child_id   TEXT NOT NULL,
        key        TEXT NOT NULL,
        value      TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (child_id, key)
      )
    ''');
  }

  static Future<void> _createV3(Database db) async {
    await db.execute('ALTER TABLE sessions ADD COLUMN lesson_summary TEXT');
  }
}
