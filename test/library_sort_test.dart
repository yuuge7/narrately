import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/models/book.dart';
import 'package:narrately/services/library_sort.dart';
import 'package:narrately/services/reading_progress.dart';

Book _book(String id, String title, String author) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: '/tmp/$id.epub',
  );
}

/// Insertion order is what the database returns, so it is what sorting starts
/// from: zola first, austen last.
final _books = [
  _book('1', 'Germinal', 'Émile Zola'),
  _book('2', 'the hobbit', 'J. R. R. Tolkien'),
  _book('3', 'Emma', 'Jane Austen'),
];

final _progress = {
  '1': const BookProgress(fraction: 0.9, updatedAt: 100),
  '2': const BookProgress(fraction: 0.1, updatedAt: 300),
  '3': BookProgress.none,
};

List<String> _titles(List<Book> books) => books.map((b) => b.title).toList();

void main() {
  group('librarySortFromKey', () {
    test('round-trips every option', () {
      for (final sort in LibrarySort.values) {
        expect(librarySortFromKey(librarySortKey(sort)), sort);
      }
    });

    test('falls back to the default for an unknown or missing key', () {
      expect(librarySortFromKey(null), LibrarySort.added);
      expect(librarySortFromKey('something-else'), LibrarySort.added);
    });
  });

  group('sortBooks', () {
    test('recently added reverses the import order', () {
      expect(_titles(sortBooks(_books, LibrarySort.added, _progress)),
          ['Emma', 'the hobbit', 'Germinal']);
    });

    test('title ignores case', () {
      expect(_titles(sortBooks(_books, LibrarySort.title, _progress)),
          ['Emma', 'Germinal', 'the hobbit']);
    });

    test('author sorts by author', () {
      expect(_titles(sortBooks(_books, LibrarySort.author, _progress)),
          ['the hobbit', 'Emma', 'Germinal']);
    });

    test('recently played puts never-played books last', () {
      expect(_titles(sortBooks(_books, LibrarySort.recent, _progress)),
          ['the hobbit', 'Germinal', 'Emma']);
    });

    test('progress sorts by how far in', () {
      expect(_titles(sortBooks(_books, LibrarySort.progress, _progress)),
          ['Germinal', 'the hobbit', 'Emma']);
    });

    test('leaves the input list alone', () {
      final before = _titles(_books);
      sortBooks(_books, LibrarySort.title, _progress);
      expect(_titles(_books), before);
    });

    test('a book with no progress entry does not throw', () {
      expect(
        () => sortBooks(_books, LibrarySort.progress, const {}),
        returnsNormally,
      );
    });
  });

  group('searchBooks', () {
    test('matches title and author, ignoring case', () {
      expect(_titles(searchBooks(_books, 'HOBB')), ['the hobbit']);
      expect(_titles(searchBooks(_books, 'austen')), ['Emma']);
    });

    test('an empty query matches everything', () {
      expect(searchBooks(_books, '   ').length, _books.length);
    });

    test('no match gives an empty list', () {
      expect(searchBooks(_books, 'zzz'), isEmpty);
    });
  });
}
