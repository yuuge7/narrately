import '../models/book.dart';

/// How far through a book the saved position is, and when it was saved.
class BookProgress {
  /// 0.0 to 1.0 across the whole book, weighted by chapter length.
  final double fraction;

  /// Milliseconds since epoch of the last save, 0 when never played.
  final int updatedAt;

  const BookProgress({required this.fraction, required this.updatedAt});

  static const BookProgress none = BookProgress(fraction: 0, updatedAt: 0);

  bool get started => updatedAt > 0;

  /// A book is called finished a shade before the end: the last position is
  /// saved at the start of the final chunk, so an exact 1.0 only happens when
  /// the chapter ran to completion.
  bool get finished => fraction >= 0.999;
}

/// Reads one row of `playback_state` against the book it belongs to.
///
/// Position is weighted by word count rather than chapter count, so a book
/// with one long chapter and ten short ones does not jump to 90% after the
/// first of them.
BookProgress progressFor(Book book, Map<String, dynamic>? playback) {
  if (playback == null || book.chapters.isEmpty) return BookProgress.none;

  final updatedAt = (playback['updated_at'] as int?) ?? 0;
  final chapterId = playback['last_chapter_id'] as String?;
  if (chapterId == null) return BookProgress.none;

  var index = -1;
  for (var i = 0; i < book.chapters.length; i++) {
    if (book.chapters[i].id == chapterId) {
      index = i;
      break;
    }
  }
  // The chapter is gone, which happens after a re-import. The book has been
  // opened, so say so, but do not guess how far in.
  if (index == -1) return BookProgress(fraction: 0, updatedAt: updatedAt);

  var totalWords = 0;
  var wordsBefore = 0;
  for (var i = 0; i < book.chapters.length; i++) {
    final words = book.chapters[i].wordCount;
    if (i < index) wordsBefore += words;
    totalWords += words;
  }
  if (totalWords <= 0) return BookProgress(fraction: 0, updatedAt: updatedAt);

  final chapter = book.chapters[index];
  var within = 0.0;
  final chars = playback['last_position_chars'] as int?;
  if (chars != null && chapter.textContent.isNotEmpty) {
    within = (chars / chapter.textContent.length).clamp(0.0, 1.0);
  }

  final fraction =
      ((wordsBefore + within * chapter.wordCount) / totalWords).clamp(0.0, 1.0);
  return BookProgress(fraction: fraction, updatedAt: updatedAt);
}

Map<String, BookProgress> progressForAll(
  List<Book> books,
  Map<String, Map<String, dynamic>> playbackStates,
) {
  return {
    for (final book in books)
      book.id: progressFor(book, playbackStates[book.id]),
  };
}
