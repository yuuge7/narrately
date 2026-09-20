import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../models/user_stats.dart';
import '../providers/epub_providers.dart';
import '../providers/library_progress_provider.dart';
import '../providers/stats_provider.dart';
import '../services/library_sort.dart';
import '../services/reading_progress.dart';
import '../widgets/book_card.dart';
import '../widgets/error_banner.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final statsState = ref.watch(statsProvider);
    final sort = librarySortFromKey(statsState.stats?.librarySort);
    final progress = ref.watch(libraryProgressProvider).value ?? const {};

    ref.listen(statsProvider, (previous, next) {
      if (previous?.stats?.goalReachedToday == false &&
          next.stats?.goalReachedToday == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Congratulations! You reached your daily listening goal!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // An import that worked is not an error, so it gets a snack bar rather
    // than the red banner.
    ref.listen(libraryProvider, (previous, next) {
      final notice = next.noticeMessage;
      if (notice == null || notice == previous?.noticeMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice), behavior: SnackBarBehavior.floating),
      );
      ref.read(libraryProvider.notifier).dismissNotice();
    });

    final visible = sortBooks(searchBooks(state.books, _query), sort, progress);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search your library',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('Narrately'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          if (!_searching) ...[
            _SortButton(current: sort),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Import Books',
              onPressed: state.isImporting
                  ? null
                  : () => ref.read(libraryProvider.notifier).importBooks(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (!statsState.isLoading && statsState.stats != null)
            _buildStatsHeader(context, statsState.stats!),
          if (state.errorMessage != null)
            ErrorBanner(
              message: state.errorMessage!,
              onDismiss: () => ref.read(libraryProvider.notifier).dismissError(),
            ),
          if (state.isImporting) ...[
            const LinearProgressIndicator(),
            if (state.importStatus != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.importStatus!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (state.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: state.books.isEmpty
                  ? _buildEmptyState(context, state.isImporting)
                  : visible.isEmpty
                      ? _buildNoMatches(context)
                      : _buildGrid(context, visible, progress),
            ),
        ],
      ),
      floatingActionButton:
          state.books.isEmpty && !state.isImporting && !state.isLoading
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      ref.read(libraryProvider.notifier).importBooks(),
                  icon: const Icon(Icons.add),
                  label: const Text('Import Books'),
                )
              : null,
    );
  }

  Widget _buildStatsHeader(BuildContext context, UserStats stats) {
    final goalSeconds = stats.dailyGoalSeconds;
    final progress = goalSeconds > 0
        ? (stats.secondsListenedToday / goalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final minsListened = stats.secondsListenedToday ~/ 60;
    final minsGoal = goalSeconds ~/ 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '${stats.currentStreak} Day Streak',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              Text('$minsListened / $minsGoal mins'),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: stats.goalReachedToday ? Colors.green : Theme.of(context).colorScheme.primary,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isImporting) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isImporting
                  ? 'Importing and parsing your books...'
                  : 'Tap the + button to import EPUB or PDF files from your device. '
                      'You can pick several at once.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatches(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(
          'No book matches "$_query".',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<Book> books,
    Map<String, BookProgress> progress,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          progress: progress[book.id] ?? BookProgress.none,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookDetailScreen(book: book),
              ),
            );
          },
        );
      },
    );
  }
}

class _SortButton extends ConsumerWidget {
  final LibrarySort current;

  const _SortButton({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<LibrarySort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      initialValue: current,
      onSelected: (sort) => ref
          .read(statsProvider.notifier)
          .setLibrarySort(librarySortKey(sort)),
      itemBuilder: (context) => [
        for (final sort in LibrarySort.values)
          PopupMenuItem(
            value: sort,
            child: Row(
              children: [
                Icon(
                  sort == current ? Icons.check : null,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(librarySortLabel(sort)),
              ],
            ),
          ),
      ],
    );
  }
}
