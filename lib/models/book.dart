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

  /// BCP-47 tag from the book's own metadata ("ro", "en-GB"), used to pick a
  /// narration voice. Null when the format carries no language, as PDF does.
  final String? language;

  /// Narration speed chosen for this book, overriding the global default.
  /// Null until the speed is changed while this book is open.
  final double? playbackSpeed;

  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverImagePath,
    this.contentHash,
    this.language,
    this.playbackSpeed,
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
      'language': language,
      'playback_speed': playbackSpeed,
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
      language: map['language'] as String?,
      playbackSpeed: (map['playback_speed'] as num?)?.toDouble(),
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
    String? language,
    double? playbackSpeed,
    List<Chapter>? chapters,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      contentHash: contentHash ?? this.contentHash,
      language: language ?? this.language,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      chapters: chapters ?? this.chapters,
    );
  }
}
