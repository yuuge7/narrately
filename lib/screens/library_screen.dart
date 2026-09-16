import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/epub_providers.dart';
import '../providers/stats_provider.dart';
import '../widgets/book_card.dart';
import '../widgets/error_banner.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final statsState = ref.watch(statsProvider);

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Narrately'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import Book',
            onPressed: state.isImporting
                ? null
                : () => ref.read(libraryProvider.notifier).importBook(),
          ),
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
          if (state.isImporting) const LinearProgressIndicator(),
          if (state.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: state.books.isEmpty
                  ? _buildEmptyState(context, ref, state.isImporting)
                  : _buildGrid(context, state),
            ),
        ],
      ),
      floatingActionButton: state.books.isEmpty && !state.isImporting && !state.isLoading
          ? FloatingActionButton.extended(
              onPressed: () => ref.read(libraryProvider.notifier).importBook(),
              icon: const Icon(Icons.add),
              label: const Text('Import Book'),
            )
          : null,
    );
  }

  Widget _buildStatsHeader(BuildContext context, dynamic stats) {
    final progress = stats.secondsListenedToday / stats.dailyGoalSeconds;
    final minsListened = stats.secondsListenedToday ~/ 60;
    final minsGoal = stats.dailyGoalSeconds ~/ 60;

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
                  value: progress > 1.0 ? 1.0 : progress,
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isImporting) {
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
                  ? 'Importing and parsing your book...'
                  : 'Tap the + button to import an EPUB or PDF file from your device.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, LibraryState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: state.books.length,
      itemBuilder: (context, index) {
        final book = state.books[index];
        return BookCard(
          book: book,
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
