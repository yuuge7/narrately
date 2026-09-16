import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../services/epub_parser_service.dart';
import '../services/pdf_parser_service.dart';
import '../services/file_picker_service.dart';
import 'database_provider.dart';

final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService();
});

final epubParserServiceProvider = Provider<EpubParserService>((ref) {
  return EpubParserService();
});

final pdfParserServiceProvider = Provider<PdfParserService>((ref) {
  return PdfParserService();
});

class LibraryState {
  final List<Book> books;
  final bool isImporting;
  final String? errorMessage;
  final bool isLoading;

  const LibraryState({
    this.books = const [],
    this.isImporting = false,
    this.errorMessage,
    this.isLoading = true,
  });

  LibraryState copyWith({
    List<Book>? books,
    bool? isImporting,
    String? errorMessage,
    bool? isLoading,
  }) {
    return LibraryState(
      books: books ?? this.books,
      isImporting: isImporting ?? this.isImporting,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
  
  LibraryState clearError() {
    return LibraryState(
      books: books,
      isImporting: isImporting,
      errorMessage: null,
      isLoading: isLoading,
    );
  }
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

  Future<void> importBook() async {
    state = state.clearError().copyWith(isImporting: true);
    
    try {
      final picker = ref.read(filePickerServiceProvider);
      // Wait, does filePickerServiceProvider support PDF?
      // I should update filePickerServiceProvider too.
      final filePath = await picker.pickBookFile();
      
      if (filePath == null) {
        state = state.copyWith(isImporting: false);
        return;
      }
      
      if (state.books.any((b) => b.filePath == filePath)) {
        state = state.copyWith(
          isImporting: false,
          errorMessage: 'Book is already imported.',
        );
        return;
      }

      final appDocsDir = await getApplicationDocumentsDirectory();
      Book book;
      
      if (filePath.toLowerCase().endsWith('.pdf')) {
        final pdfParser = ref.read(pdfParserServiceProvider);
        book = await pdfParser.parsePdf(filePath);
      } else {
        final epubParser = ref.read(epubParserServiceProvider);
        book = await epubParser.parseEpub(filePath, appDocsDir.path);
      }
      
      final db = ref.read(databaseServiceProvider);
      await db.insertBook(book);
      
      state = state.copyWith(
        isImporting: false,
        books: [...state.books, book],
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  Future<void> deleteBook(String bookId) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteBook(bookId);
      
      final currentBooks = List<Book>.from(state.books);
      currentBooks.removeWhere((b) => b.id == bookId);
      state = state.copyWith(books: currentBooks);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete book: $e');
    }
  }

  void dismissError() {
    state = state.clearError();
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});
