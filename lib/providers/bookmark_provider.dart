import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'package:uuid/uuid.dart';

final bookmarksProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bookId) async {
  final db = ref.read(databaseServiceProvider);
  return await db.getBookmarks(bookId);
});

class BookmarkNotifier extends Notifier<void> {
  @override
  void build() {}
  
  Future<void> addBookmark(
    String bookId,
    String chapterId,
    int chunkIndex,
    int charOffset,
    String note,
  ) async {
    final db = ref.read(databaseServiceProvider);
    final id = const Uuid().v4();
    await db.addBookmark(id, bookId, chapterId, chunkIndex, charOffset, note);
    ref.invalidate(bookmarksProvider(bookId));
  }
  
  Future<void> deleteBookmark(String bookId, String bookmarkId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteBookmark(bookmarkId);
    ref.invalidate(bookmarksProvider(bookId));
  }
}

final bookmarkNotifierProvider = NotifierProvider<BookmarkNotifier, void>(() {
  return BookmarkNotifier();
});
