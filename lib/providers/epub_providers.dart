import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../services/epub_parser_service.dart';
import '../services/file_picker_service.dart';
import 'database_provider.dart';

final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService();
});

final epubParserServiceProvider = Provider<EpubParserService>((ref) {
  return EpubParserService();
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
      final filePath = await picker.pickEpubFile();
      
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

      final parser = ref.read(epubParserServiceProvider);
      final appDocsDir = await getApplicationDocumentsDirectory();
      final book = await parser.parseEpub(filePath, appDocsDir.path);
      
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
  
  void dismissError() {
    state = state.clearError();
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(() {
  return LibraryNotifier();
});
