import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/user_stats.dart';

class DatabaseService {
  static const int _schemaVersion = 7;

  Database? _db;
  Future<Database>? _opening;

  Future<void> init() async {
    await _database;
  }

  /// Every public method funnels through here, so a call that arrives before
  /// [init] finishes waits for the same open instead of racing a second one.
  Future<Database> get _database {
    final db = _db;
    if (db != null) return Future.value(db);

    return _opening ??= _open().catchError((Object e) {
      _opening = null;
      throw e;
    });
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'narrately.db');

    final db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migrations are written to be idempotent: any table or column that is
        // already present is left alone. Older builds shipped an `else if`
        // chain that could re-add an existing column and abort the upgrade,
        // so existing installs may be on any mix of these steps.
        await _createTables(db);
        await _addMissingColumns(db);
      },
    );

    _db = db;
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        title TEXT,
        author TEXT,
        file_path TEXT,
        cover_image_path TEXT,
        content_hash TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT,
        chapter_index INTEGER,
        title TEXT,
        text_content TEXT,
        word_count INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chapters_book ON chapters (book_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS playback_state (
        book_id TEXT PRIMARY KEY,
        last_chapter_id TEXT,
        last_position_words INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        id INTEGER PRIMARY KEY,
        current_streak INTEGER,
        longest_streak INTEGER,
        last_listened_date TEXT,
        seconds_listened_today INTEGER,
        daily_goal_seconds INTEGER,
        goal_reached_today INTEGER,
        preferred_speed REAL,
        preferred_pitch REAL,
        preferred_voice_name TEXT,
        preferred_voice_locale TEXT,
        theme_mode TEXT,
        preferred_font_size REAL DEFAULT 18.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS listening_history (
        date TEXT PRIMARY KEY,
        seconds INTEGER DEFAULT 0,
        goal_reached INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id TEXT PRIMARY KEY,
        book_id TEXT,
        chapter_id TEXT,
        chunk_index INTEGER,
        note TEXT,
        created_at TEXT,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks (book_id)',
    );
  }

  Future<void> _addMissingColumns(Database db) async {
    await _addColumn(db, 'user_stats', 'preferred_speed', 'REAL');
    await _addColumn(db, 'user_stats', 'preferred_pitch', 'REAL');
    await _addColumn(db, 'user_stats', 'preferred_voice_name', 'TEXT');
    await _addColumn(db, 'user_stats', 'preferred_voice_locale', 'TEXT');
    await _addColumn(db, 'user_stats', 'theme_mode', "TEXT DEFAULT 'system'");
    await _addColumn(db, 'user_stats', 'preferred_font_size', 'REAL DEFAULT 18.0');
    await _addColumn(db, 'playback_state', 'updated_at', 'INTEGER DEFAULT 0');
    await _addColumn(db, 'books', 'content_hash', 'TEXT');
  }

  Future<void> _addColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final existing = info.map((row) => row['name'] as String).toSet();
    if (existing.contains(column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<UserStats> getUserStats() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps =
        await db.query('user_stats', where: 'id = 1');
    if (maps.isNotEmpty) {
      return UserStats.fromMap(maps.first);
    } else {
      final defaultStats = UserStats(
        lastListenedDate: DateTime.now().toIso8601String().split('T')[0],
      );
      await db.insert('user_stats', defaultStats.toMap());
      return defaultStats;
    }
  }

  Future<void> updateUserStats(UserStats stats) async {
    final db = await _database;
    await db.insert(
      'user_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBook(Book book) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'books',
        book.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final chapter in book.chapters) {
        await txn.insert(
          'chapters',
          chapter.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Fills in the fingerprint of a book that predates it, so it takes part in
  /// duplicate detection from then on.
  Future<void> setBookContentHash(String bookId, String contentHash) async {
    final db = await _database;
    await db.update(
      'books',
      {'content_hash': contentHash},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteBook(String bookId) async {
    final db = await _database;

    // First, let's get the book so we can delete its cover image file if it exists
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );

    if (maps.isNotEmpty) {
      final coverPath = maps.first['cover_image_path'] as String?;
      if (coverPath != null) {
        try {
          final file = File(coverPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore file deletion errors
        }
      }
    }

    // Foreign keys are on, but older rows may predate that, so delete the
    // children explicitly rather than relying on the cascade.
    await db.transaction((txn) async {
      await txn.delete('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete('playback_state', where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete('books', where: 'id = ?', whereArgs: [bookId]);
    });
  }

  Future<List<Book>> getAllBooks() async {
    final db = await _database;
    final List<Map<String, dynamic>> bookMaps = await db.query('books');

    List<Book> books = [];
    for (var bookMap in bookMaps) {
      final List<Map<String, dynamic>> chapterMaps = await db.query(
        'chapters',
        where: 'book_id = ?',
        whereArgs: [bookMap['id']],
        orderBy: 'chapter_index ASC',
      );

      final chapters = chapterMaps.map((c) => Chapter.fromMap(c)).toList();
      books.add(Book.fromMap(bookMap, chapters: chapters));
    }

    return books;
  }

  Future<void> savePlaybackState(String bookId, String chapterId, int chunkIndex) async {
    final db = await _database;
    await db.insert(
      'playback_state',
      {
        'book_id': bookId,
        'last_chapter_id': chapterId,
        'last_position_words': chunkIndex,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getPlaybackState(String bookId) async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'playback_state',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMostRecentPlayback() async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'playback_state',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<void> saveListeningHistory(String dateStr, int seconds, bool goalReached) async {
    final db = await _database;
    await db.insert(
      'listening_history',
      {
        'date': dateStr,
        'seconds': seconds,
        'goal_reached': goalReached ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getListeningHistory(int limit) async {
    final db = await _database;
    return await db.query(
      'listening_history',
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<void> addBookmark(String id, String bookId, String chapterId, int chunkIndex, String note) async {
    final db = await _database;
    await db.insert(
      'bookmarks',
      {
        'id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'chunk_index': chunkIndex,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async {
    final db = await _database;
    return await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteBookmark(String id) async {
    final db = await _database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
