import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/models/book.dart';
import 'package:narrately/models/chapter.dart';
import 'package:narrately/services/book_search.dart';

Chapter _chapter(String id, int index, String text) {
  return Chapter(
    id: id,
    bookId: 'b1',
    index: index,
    title: 'Chapter ${index + 1}',
    textContent: text,
    wordCount: text.split(' ').length,
  );
}

Book _book(List<Chapter> chapters) {
  return Book(
    id: 'b1',
    title: 'Test',
    author: 'Author',
    filePath: '/tmp/test.epub',
    chapters: chapters,
  );
}

void main() {
  group('searchBook', () {
    test('finds a term and reports where it is', () {
      final book = _book([
        _chapter('c1', 0, 'The whale surfaced at dawn.'),
        _chapter('c2', 1, 'No whale was seen again.'),
      ]);

      final matches = searchBook(book, 'whale');

      expect(matches.length, 2);
      expect(matches[0].chapterId, 'c1');
      expect(matches[0].offset, 4);
      expect(matches[1].chapterId, 'c2');
      expect(matches[1].offset, 3);
    });

    test('ignores case', () {
      final book = _book([_chapter('c1', 0, 'Ahab and AHAB and ahab.')]);
      expect(searchBook(book, 'Ahab').length, 3);
    });

    test('the highlight lines up with the term in the snippet', () {
      final book = _book([
        _chapter('c1', 0, 'A long sentence about a whale in the sea.'),
      ]);

      final match = searchBook(book, 'whale').single;
      expect(
        match.snippet.substring(
          match.matchStart,
          match.matchStart + match.matchLength,
        ),
        'whale',
      );
    });

    test('a match at the start of a chapter needs no leading ellipsis', () {
      final book = _book([_chapter('c1', 0, 'Whale. And more text here.')]);
      final match = searchBook(book, 'whale').single;

      expect(match.snippet.startsWith('…'), isFalse);
      expect(match.matchStart, 0);
    });

    test('newlines are flattened without moving the highlight', () {
      final book = _book([
        _chapter('c1', 0, 'First line.\n\nA whale appeared.\n\nLast line.'),
      ]);

      final match = searchBook(book, 'whale').single;
      expect(match.snippet, isNot(contains('\n')));
      expect(
        match.snippet.substring(
          match.matchStart,
          match.matchStart + match.matchLength,
        ),
        'whale',
      );
    });

    test('an empty query finds nothing', () {
      final book = _book([_chapter('c1', 0, 'Anything at all.')]);
      expect(searchBook(book, '   '), isEmpty);
    });

    test('punctuation is matched literally, not as a pattern', () {
      final book = _book([_chapter('c1', 0, 'Cost: 3.50 or 3x50.')]);

      expect(searchBook(book, '3.50').length, 1);
      // A regex would have let "." match the "x".
      expect(searchBook(book, '3.50').single.offset, 6);
    });

    test('stops at the limit instead of returning thousands of rows', () {
      final book = _book([_chapter('c1', 0, List.filled(500, 'the').join(' '))]);
      expect(searchBook(book, 'the', limit: 20).length, 20);
    });

    test('overlapping terms advance past the previous match', () {
      final book = _book([_chapter('c1', 0, 'aaaa')]);
      expect(searchBook(book, 'aa').length, 2);
    });
  });
}
