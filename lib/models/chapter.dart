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

  Chapter copyWith({
    String? id,
    String? bookId,
    int? index,
    String? title,
    String? textContent,
    int? wordCount,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      index: index ?? this.index,
      title: title ?? this.title,
      textContent: textContent ?? this.textContent,
      wordCount: wordCount ?? this.wordCount,
    );
  }
}
