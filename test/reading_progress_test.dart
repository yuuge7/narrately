import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/models/book.dart';
import 'package:narrately/models/chapter.dart';
import 'package:narrately/services/reading_progress.dart';

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

/// Three chapters of 100, 300 and 100 words: deliberately uneven, because the
/// point of weighting by words is that the middle one counts for more.
Book _book() {
  return Book(
    id: 'b1',
    title: 'Test',
    author: 'Author',
    filePath: '/tmp/test.epub',
    chapters: [
      _chapter('c1', 0, List.filled(100, 'word').join(' ')),
      _chapter('c2', 1, List.filled(300, 'word').join(' ')),
      _chapter('c3', 2, List.filled(100, 'word').join(' ')),
    ],
  );
}

Map<String, dynamic> _state(String chapterId, int? chars, {int updatedAt = 5}) {
  return {
    'book_id': 'b1',
    'last_chapter_id': chapterId,
    'last_position_words': 0,
    'last_position_chars': chars,
    'updated_at': updatedAt,
  };
}

void main() {
  group('progressFor', () {
    test('a book never opened has no progress', () {
      final progress = progressFor(_book(), null);
      expect(progress.fraction, 0);
      expect(progress.started, isFalse);
      expect(progress.finished, isFalse);
    });

    test('counts whole chapters that came before', () {
      final book = _book();
      final progress = progressFor(book, _state('c2', 0));

      // 100 of 500 words are behind the start of chapter two.
      expect(progress.fraction, closeTo(0.2, 0.001));
      expect(progress.started, isTrue);
    });

    test('weights by words, not by chapter count', () {
      final book = _book();
      final halfway = book.chapters[1].textContent.length ~/ 2;
      final progress = progressFor(book, _state('c2', halfway));

      // 100 words before, plus half of a 300-word chapter, out of 500.
      expect(progress.fraction, closeTo(0.5, 0.01));
    });

    test('the end of the last chapter reads as finished', () {
      final book = _book();
      final end = book.chapters[2].textContent.length;
      final progress = progressFor(book, _state('c3', end));

      expect(progress.fraction, 1.0);
      expect(progress.finished, isTrue);
    });

    test('a position saved before character offsets existed still counts', () {
      // Rows written by an older build carry a null offset. The chapters
      // already read are known; where inside the current one is not.
      final progress = progressFor(_book(), _state('c2', null));
      expect(progress.fraction, closeTo(0.2, 0.001));
      expect(progress.started, isTrue);
    });

    test('a chapter that no longer exists counts as started only', () {
      final progress = progressFor(_book(), _state('gone', 10));
      expect(progress.fraction, 0);
      expect(progress.started, isTrue);
    });

    test('an offset past the end of the text is clamped', () {
      final progress = progressFor(_book(), _state('c1', 999999));
      expect(progress.fraction, closeTo(0.2, 0.001));
    });

    test('a book with no chapters does not divide by zero', () {
      const empty = Book(
        id: 'b1',
        title: 'Empty',
        author: 'Author',
        filePath: '/tmp/x.epub',
      );
      expect(progressFor(empty, _state('c1', 0)).fraction, 0);
    });
  });

  test('progressForAll keys every book, played or not', () {
    final book = _book();
    final result = progressForAll([book], {'b1': _state('c2', 0)});

    expect(result.keys, ['b1']);
    expect(result['b1']!.fraction, closeTo(0.2, 0.001));
    expect(progressForAll([book], const {})['b1']!.started, isFalse);
  });
}
