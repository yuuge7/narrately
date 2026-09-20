import '../models/book.dart';
import 'reading_progress.dart';

enum LibrarySort { added, title, author, recent, progress }

const Map<LibrarySort, String> _keys = {
  LibrarySort.added: 'added',
  LibrarySort.title: 'title',
  LibrarySort.author: 'author',
  LibrarySort.recent: 'recent',
  LibrarySort.progress: 'progress',
};

const Map<LibrarySort, String> _labels = {
  LibrarySort.added: 'Recently added',
  LibrarySort.title: 'Title',
  LibrarySort.author: 'Author',
  LibrarySort.recent: 'Recently played',
  LibrarySort.progress: 'Progress',
};

String librarySortKey(LibrarySort sort) => _keys[sort]!;

String librarySortLabel(LibrarySort sort) => _labels[sort]!;

/// Falls back to the default rather than throwing: the stored key comes from
/// the database and may have been written by a build that had other options.
LibrarySort librarySortFromKey(String? key) {
  for (final entry in _keys.entries) {
    if (entry.value == key) return entry.key;
  }
  return LibrarySort.added;
}

/// Books whose title or author contains [query], case-insensitively.
///
/// An empty or whitespace-only query matches everything, so the caller can
/// pass the raw field contents straight through.
List<Book> searchBooks(List<Book> books, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return books;

  return books.where((book) {
    return book.title.toLowerCase().contains(needle) ||
        book.author.toLowerCase().contains(needle);
  }).toList();
}

/// Orders a copy of [books]. The input order is the order they were imported
/// in, which is what [LibrarySort.added] reverses.
List<Book> sortBooks(
  List<Book> books,
  LibrarySort sort,
  Map<String, BookProgress> progress,
) {
  final sorted = List<Book>.from(books);
  BookProgress progressOf(Book book) =>
      progress[book.id] ?? BookProgress.none;

  switch (sort) {
    case LibrarySort.added:
      return sorted.reversed.toList();
    case LibrarySort.title:
      sorted.sort((a, b) => _compareText(a.title, b.title));
    case LibrarySort.author:
      sorted.sort((a, b) {
        final byAuthor = _compareText(a.author, b.author);
        return byAuthor != 0 ? byAuthor : _compareText(a.title, b.title);
      });
    case LibrarySort.recent:
      sorted.sort((a, b) {
        final byTime =
            progressOf(b).updatedAt.compareTo(progressOf(a).updatedAt);
        return byTime != 0 ? byTime : _compareText(a.title, b.title);
      });
    case LibrarySort.progress:
      sorted.sort((a, b) {
        final byProgress =
            progressOf(b).fraction.compareTo(progressOf(a).fraction);
        return byProgress != 0 ? byProgress : _compareText(a.title, b.title);
      });
  }

  return sorted;
}

int _compareText(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());
