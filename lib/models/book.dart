import 'chapter.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverImagePath;
  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverImagePath,
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
    };
  }

  factory Book.fromMap(Map<String, dynamic> map, {List<Chapter> chapters = const []}) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      filePath: map['file_path'],
      coverImagePath: map['cover_image_path'],
      chapters: chapters,
    );
  }
}
