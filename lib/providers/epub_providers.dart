import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../services/book_parse_exception.dart';
import '../services/book_parser.dart';
import '../services/file_picker_service.dart';
import 'database_provider.dart';
import 'library_progress_provider.dart';

final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService();
});

class LibraryState {
  final List<Book> books;
  final bool isImporting;
  final String? errorMessage;
  final bool isLoading;

  /// Progress line shown while a multi-file import runs.
  final String? importStatus;

  /// A one-off message about something that worked, shown as a snack bar.
  final String? noticeMessage;

  const LibraryState({
    this.books = const [],
    this.isImporting = false,
    this.errorMessage,
    this.isLoading = true,
    this.importStatus,
    this.noticeMessage,
  });

  LibraryState copyWith({
    List<Book>? books,
    bool? isImporting,
    String? errorMessage,
    bool? isLoading,
    String? importStatus,
    String? noticeMessage,
  }) {
    return LibraryState(
      books: books ?? this.books,
      isImporting: isImporting ?? this.isImporting,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
      importStatus: importStatus ?? this.importStatus,
      noticeMessage: noticeMessage ?? this.noticeMessage,
    );
  }

  /// copyWith cannot put a nullable field back to null, so clearing a message
  /// goes through its own constructor call.
  LibraryState withMessages({String? error, String? notice, String? status}) {
    return LibraryState(
      books: books,
      isImporting: isImporting,
      isLoading: isLoading,
      errorMessage: error,
      noticeMessage: notice,
      importStatus: status,
    );
  }

  LibraryState clearError() => withMessages(notice: noticeMessage);

  LibraryState clearNotice() => withMessages(error: errorMessage);
}

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    _init();
    return const LibraryState();
  }

  Future<void> _init() async {
    final db = ref.read(databaseServiceProvider);
    await db.init();
    final books = await db.getAllBooks();
    state = state.copyWith(books: books, isLoading: false);
  }

  /// Reloads everything from the database. Used after a backup is restored,
  /// where the books on disk have nothing to do with the ones in memory.
  Future<void> reload() async {
    state = const LibraryState();
    await _init();
    ref.invalidate(libraryProgressProvider);
  }

  /// Imports one or more picked books.
  ///
  /// Each file is handled on its own: one unreadable PDF in a selection of six
  /// no longer aborts the other five, and the result says what happened to
  /// each group.
  Future<void> importBooks() async {
    state = state.withMessages(status: 'Reading files…').copyWith(isImporting: true);

    try {
      final picker = ref.read(filePickerServiceProvider);
      final paths = await picker.pickBookFiles();

      if (paths.isEmpty) {
        state = state.withMessages().copyWith(isImporting: false);
        return;
      }

      final fingerprints = await _fingerprintAndBackfill(paths);
      final appDocsDir = await getApplicationDocumentsDirectory();
      final db = ref.read(databaseServiceProvider);

      var imported = 0;
      final skipped = <String>[];
      final failed = <String>[];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final name = p.basename(path);

        if (paths.length > 1) {
          state = state.copyWith(
            importStatus: 'Importing ${i + 1} of ${paths.length}: $name',
          );
        }

        final fingerprint = fingerprints[path];
        if (fingerprint == null) {
          failed.add(name);
          continue;
        }

        final existing = _bookWithHash(fingerprint);
        if (existing != null) {
          skipped.add(existing.title);
          continue;
        }

        try {
          // Reading and parsing run on a background isolate so the import stays
          // responsive; see parseBookFile.
          final parsed = await compute(
            parseBookFile,
            ParseRequest(filePath: path, appDocsDir: appDocsDir.path),
          );

          final book = parsed.copyWith(contentHash: fingerprint);
          await db.insertBook(book);
          state = state.copyWith(books: [...state.books, book]);
          imported++;
        } catch (e) {
          failed.add('$name — ${describeError(e)}');
        }
      }

      ref.invalidate(libraryProgressProvider);
      state = state.withMessages(
        notice: _successSummary(imported, skipped),
        error: _failureSummary(failed),
      ).copyWith(isImporting: false);
    } catch (e) {
      state = state
          .withMessages(error: describeError(e))
          .copyWith(isImporting: false);
    }
  }

  String? _successSummary(int imported, List<String> skipped) {
    final parts = <String>[];
    if (imported == 1) {
      parts.add('Imported 1 book');
    } else if (imported > 1) {
      parts.add('Imported $imported books');
    }

    if (skipped.length == 1) {
      parts.add('"${skipped.first}" was already in your library');
    } else if (skipped.length > 1) {
      parts.add('${skipped.length} were already in your library');
    }

    if (parts.isEmpty) return null;
    return '${parts.join('. ')}.';
  }

  String? _failureSummary(List<String> failed) {
    if (failed.isEmpty) return null;
    if (failed.length == 1) return failed.first;
    return '${failed.length} files could not be imported:\n${failed.join('\n')}';
  }

  /// Fingerprints the files being imported, and in the same background pass
  /// fills in the fingerprint of any book that predates the column.
  ///
  /// A path that could not be read is simply absent from the result. A legacy
  /// book whose cached source file is gone keeps its null hash and cannot be
  /// matched.
  Future<Map<String, String>> _fingerprintAndBackfill(
    List<String> paths,
  ) async {
    final legacy =
        state.books.where((b) => b.contentHash == null).toList(growable: false);

    final hashes = await compute(
      fingerprintFiles,
      <String>[...paths, ...legacy.map((b) => b.filePath)],
    );

    final db = ref.read(databaseServiceProvider);
    for (final book in legacy) {
      final hash = hashes[book.filePath];
      if (hash == null) continue;
      await db.setBookContentHash(book.id, hash);
      _replaceBook(book.copyWith(contentHash: hash));
    }

    return hashes;
  }

  Book? _bookWithHash(String fingerprint) {
    for (final book in state.books) {
      if (book.contentHash == fingerprint) return book;
    }
    return null;
  }

  void _replaceBook(Book updated) {
    state = state.copyWith(
      books: [
        for (final book in state.books)
          if (book.id == updated.id) updated else book,
      ],
    );
  }

  /// Remembers the narration speed chosen while this book was open.
  Future<void> setBookSpeed(String bookId, double speed) async {
    final db = ref.read(databaseServiceProvider);
    await db.setBookSpeed(bookId, speed);

    for (final book in state.books) {
      if (book.id == bookId) {
        _replaceBook(book.copyWith(playbackSpeed: speed));
        return;
      }
    }
  }

  Future<void> deleteBook(String bookId) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteBook(bookId);

      final currentBooks = List<Book>.from(state.books);
      currentBooks.removeWhere((b) => b.id == bookId);
      state = state.copyWith(books: currentBooks);
      ref.invalidate(libraryProgressProvider);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete book: ${describeError(e)}');
    }
  }

  void dismissError() {
    state = state.clearError();
  }

  void dismissNotice() {
    state = state.clearNotice();
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});
