import '../models/book.dart';

/// One occurrence of a search term inside a book.
class ChapterMatch {
  final String chapterId;
  final int chapterIndex;
  final String chapterTitle;

  /// Character offset of the match within the chapter text, which is what
  /// playback is positioned by.
  final int offset;

  /// A window of text around the match, for the result list.
  final String snippet;

  /// Where the match sits inside [snippet], for highlighting it.
  final int matchStart;
  final int matchLength;

  const ChapterMatch({
    required this.chapterId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.offset,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
  });
}

const int _leadingContext = 44;
const int _trailingContext = 76;

/// Finds [query] in every chapter of [book], in reading order.
///
/// Matching is case-insensitive and plain text: no regular expressions, so a
/// query full of punctuation searches for exactly those characters. Results
/// stop at [limit] because a common word in a long book otherwise produces
/// thousands of rows that nobody scrolls through.
List<ChapterMatch> searchBook(Book book, String query, {int limit = 200}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final matches = <ChapterMatch>[];

  for (final chapter in book.chapters) {
    final text = chapter.textContent;
    final haystack = text.toLowerCase();

    var from = 0;
    while (matches.length < limit) {
      final at = haystack.indexOf(needle, from);
      if (at == -1) break;

      final start = at - _leadingContext < 0 ? 0 : at - _leadingContext;
      var end = at + needle.length + _trailingContext;
      if (end > text.length) end = text.length;

      // Newlines are replaced one for one so the offsets below stay valid.
      final window = text.substring(start, end).replaceAll(RegExp(r'\s'), ' ');
      final prefix = start > 0 ? '…' : '';
      final suffix = end < text.length ? '…' : '';

      matches.add(ChapterMatch(
        chapterId: chapter.id,
        chapterIndex: chapter.index,
        chapterTitle: chapter.title,
        offset: at,
        snippet: '$prefix$window$suffix',
        matchStart: prefix.length + (at - start),
        matchLength: needle.length,
      ));

      from = at + needle.length;
    }

    if (matches.length >= limit) break;
  }

  return matches;
}
