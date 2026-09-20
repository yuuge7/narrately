import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reading_progress.dart';
import 'database_provider.dart';
import 'epub_providers.dart';

/// How far through each book the reader is, keyed by book id.
///
/// One query for the whole library rather than one per card, and refreshed at
/// chapter boundaries rather than per sentence — see
/// `PlayerNotifier._refreshLibraryProgress`.
final libraryProgressProvider =
    FutureProvider<Map<String, BookProgress>>((ref) async {
  final books = ref.watch(libraryProvider).books;
  final db = ref.watch(databaseServiceProvider);
  final states = await db.getAllPlaybackStates();
  return progressForAll(books, states);
});
