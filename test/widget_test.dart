import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:narrately/main.dart';
import 'package:narrately/providers/database_provider.dart';
import 'package:narrately/services/database_service.dart';
import 'package:narrately/models/book.dart';
import 'package:narrately/models/user_stats.dart';

class MockDatabaseService implements DatabaseService {
  @override
  Future<void> init() async {}
  
  @override
  Future<UserStats> getUserStats() async {
    return UserStats(
      lastListenedDate: DateTime.now().toIso8601String().split('T')[0],
    );
  }
  
  @override
  Future<void> updateUserStats(UserStats stats) async {}
  
  @override
  Future<void> insertBook(Book book) async {}
  
  @override
  Future<void> setBookContentHash(String bookId, String contentHash) async {}

  @override
  Future<void> deleteBook(String bookId) async {}
  
  @override
  Future<List<Book>> getAllBooks() async => [];
  
  @override
  Future<void> savePlaybackState(String bookId, String chapterId, int chunkIndex) async {}
  
  @override
  Future<Map<String, dynamic>?> getPlaybackState(String bookId) async => null;
  
  @override
  Future<Map<String, dynamic>?> getMostRecentPlayback() async => null;
  
  @override
  Future<void> saveListeningHistory(String dateStr, int seconds, bool goalReached) async {}
  
  @override
  Future<List<Map<String, dynamic>>> getListeningHistory(int limit) async => [];
  
  @override
  Future<void> addBookmark(String id, String bookId, String chapterId, int chunkIndex, String note) async {}
  
  @override
  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async => [];
  
  @override
  Future<void> deleteBookmark(String id) async {}
}

void main() {
  testWidgets('Library screen empty state smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame with mocked database.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(MockDatabaseService()),
      ],
      child: const NarratelyApp(),
    ));
    await tester.pumpAndSettle(); // Wait for database init

    // Verify that the empty state is displayed
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Import Book'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
