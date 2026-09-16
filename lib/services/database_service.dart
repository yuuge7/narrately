import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class DatabaseService {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'narrately.db');
    
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
      },
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
