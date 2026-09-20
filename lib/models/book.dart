import 'chapter.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverImagePath;

  /// Fingerprint of the source file, used to recognise a re-import. Null for
  /// books imported before fingerprinting existed.
  final String? contentHash;

  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverImagePath,
    this.contentHash,
    this.chapters = const [],
  });

  int get chapterCount => chapters.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_path': filePath,
      'cover_image_path': coverImagePath,
      'content_hash': contentHash,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map, {List<Chapter> chapters = const []}) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      filePath: map['file_path'],
      coverImagePath: map['cover_image_path'],
      contentHash: map['content_hash'] as String?,
      chapters: chapters,
    );
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? coverImagePath,
    String? contentHash,
    List<Chapter>? chapters,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      contentHash: contentHash ?? this.contentHash,
      chapters: chapters ?? this.chapters,
    );
  }
}
