import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get() async {
    _db ??= await openDatabase('gemma_san.db', version: 1, onCreate: _create);
    return _db!;
  }

  static Future<void> _create(Database db, int version) async {
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
}
