import 'dart:typed_data';
import 'chapter.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final Uint8List? coverBytes;
  final int chapterCount;
  final DateTime importedAt;
  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    this.coverBytes,
    required this.chapterCount,
    required this.importedAt,
    this.chapters = const [],
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    Uint8List? coverBytes,
    int? chapterCount,
    DateTime? importedAt,
    List<Chapter>? chapters,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      coverBytes: coverBytes ?? this.coverBytes,
      chapterCount: chapterCount ?? this.chapterCount,
      importedAt: importedAt ?? this.importedAt,
      chapters: chapters ?? this.chapters,
    );
  }
}
