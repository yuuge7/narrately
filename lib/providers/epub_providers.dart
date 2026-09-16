import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/epub_parser_service.dart';
import '../services/file_picker_service.dart';

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

  const LibraryState({
    this.books = const [],
    this.isImporting = false,
    this.errorMessage,
  });

  LibraryState copyWith({
    List<Book>? books,
    bool? isImporting,
    String? errorMessage,
  }) {
    return LibraryState(
      books: books ?? this.books,
      isImporting: isImporting ?? this.isImporting,
      // null is used to clear the error message if not provided explicitly in a specific way,
      // but typical copyWith pattern requires a way to clear nullable fields.
      // We will handle clearing error messages through a specific method.
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  LibraryState clearError() {
    return LibraryState(
      books: books,
      isImporting: isImporting,
      errorMessage: null,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    return const LibraryState();
  }

  Future<void> importBook() async {
    state = state.clearError().copyWith(isImporting: true);
    
    try {
      final picker = ref.read(filePickerServiceProvider);
      final filePath = await picker.pickEpubFile();
      
      if (filePath == null) {
        // User cancelled picker
        state = state.copyWith(isImporting: false);
        return;
      }
      
      // Check if already imported
      if (state.books.any((b) => b.filePath == filePath)) {
        state = state.copyWith(
          isImporting: false,
          errorMessage: 'Book is already imported.',
        );
        return;
      }

      final parser = ref.read(epubParserServiceProvider);
      final book = await parser.parseEpub(filePath);
      
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
