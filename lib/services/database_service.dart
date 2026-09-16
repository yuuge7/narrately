import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/user_stats.dart';

class DatabaseService {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'narrately.db');
    
    _db = await openDatabase(
      path,
      version: 4, // Bumped version for theme_mode
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE user_stats (
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
              theme_mode TEXT
            )
          ''');
        } else if (oldVersion < 3) {
          await db.execute('ALTER TABLE user_stats ADD COLUMN preferred_speed REAL');
          await db.execute('ALTER TABLE user_stats ADD COLUMN preferred_pitch REAL');
          await db.execute('ALTER TABLE user_stats ADD COLUMN preferred_voice_name TEXT');
          await db.execute('ALTER TABLE user_stats ADD COLUMN preferred_voice_locale TEXT');
        }
        
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE user_stats ADD COLUMN theme_mode TEXT DEFAULT "system"');
        }
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT,
        author TEXT,
        file_path TEXT,
        cover_image_path TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT,
        chapter_index INTEGER,
        title TEXT,
        text_content TEXT,
        word_count INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE playback_state (
        book_id TEXT PRIMARY KEY,
        last_chapter_id TEXT,
        last_position_words INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_stats (
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
        theme_mode TEXT
      )
    ''');
  }

  Future<UserStats> getUserStats() async {
    final db = _db!;
    final List<Map<String, dynamic>> maps = await db.query('user_stats', where: 'id = 1');
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
    final db = _db!;
    await db.insert(
      'user_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBook(Book book) async {
    final db = _db!;
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

  Future<void> deleteBook(String bookId) async {
    final db = _db!;
    
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
    
    // Deleting from books will cascade to chapters and playback_state 
    // because we used ON DELETE CASCADE and if we enable foreign keys.
    // SQFlite doesn't enable foreign keys by default, so let's delete manually to be safe.
    await db.transaction((txn) async {
      await txn.delete('playback_state', where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
      await txn.delete('books', where: 'id = ?', whereArgs: [bookId]);
    });
  }

  Future<List<Book>> getAllBooks() async {
    final db = _db!;
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

  Future<void> savePlaybackState(String bookId, String chapterId) async {
    final db = _db!;
    await db.insert(
      'playback_state',
      {
        'book_id': bookId,
        'last_chapter_id': chapterId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getLastChapterId(String bookId) async {
    final db = _db!;
    final List<Map<String, dynamic>> result = await db.query(
      'playback_state',
      columns: ['last_chapter_id'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    
    if (result.isNotEmpty) {
      return result.first['last_chapter_id'] as String?;
    }
    return null;
  }
}
