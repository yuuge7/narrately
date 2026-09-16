class Chapter {
  final String id;
  final String bookId;
  final int index;
  final String title;
  final String textContent;
  final int wordCount;

  const Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    required this.textContent,
    required this.wordCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': index,
      'title': title,
      'text_content': textContent,
      'word_count': wordCount,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'],
      bookId: map['book_id'],
      index: map['chapter_index'],
      title: map['title'],
      textContent: map['text_content'],
      wordCount: map['word_count'],
    );
  }
}
