import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/epub_providers.dart';
import '../widgets/book_card.dart';
import '../widgets/error_banner.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Narrately'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import EPUB',
            onPressed: state.isImporting
                ? null
                : () => ref.read(libraryProvider.notifier).importBook(),
          ),
        ],
      ),
      body: Column(
        children: [
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
              label: const Text('Import EPUB'),
            )
          : null,
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
                  : 'Tap the + button to import an EPUB file from your device.',
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
