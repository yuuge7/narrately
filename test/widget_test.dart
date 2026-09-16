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
  Future<List<Book>> getAllBooks() async => [];
  @override
  Future<String?> getLastChapterId(String bookId) async => null;
  @override
  Future<void> insertBook(Book book) async {}
  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<void> savePlaybackState(String bookId, String chapterId) async {}
  @override
  Future<UserStats> getUserStats() async => UserStats(lastListenedDate: DateTime.now().toIso8601String().split('T')[0]);
  @override
  Future<void> updateUserStats(UserStats stats) async {}
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
