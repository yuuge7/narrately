import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../widgets/chapter_list_item.dart';
import '../providers/player_provider.dart';
import '../providers/database_provider.dart';
import 'player_screen.dart';
import '../providers/epub_providers.dart';
import '../providers/library_progress_provider.dart';
import '../services/reading_progress.dart';
import 'book_search_screen.dart';
import 'bookmarks_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  final Book book;

  const BookDetailScreen({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search in book',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookSearchScreen(book: book),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bookmarks_rounded),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BookmarksScreen(book: book)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _deleteBook(context, ref),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoverBackground(context),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildBookInfo(context, ref),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 8.0),
              child: Text(
                'Chapters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final chapter = book.chapters[index];
                return ChapterListItem(
                  chapter: chapter,
                  onTap: () async {
                    final db = ref.read(databaseServiceProvider);
                    final playbackState = await db.getPlaybackState(book.id);
                    
                    int startChunkIndex = 0;
                    int? startCharOffset;
                    if (playbackState != null && playbackState['last_chapter_id'] == chapter.id) {
                      startChunkIndex = playbackState['last_position_words'] as int? ?? 0;
                      startCharOffset = playbackState['last_position_chars'] as int?;
                    }

                    // Check if it's already the current chapter to avoid forcing a restart if we just want to open the screen
                    final currentPlayerChapter = ref.read(playerProvider).currentChapter;
                    final isSameChapter = currentPlayerChapter?.id == chapter.id;

                    await ref.read(playerProvider.notifier).playChapter(
                      chapter,
                      startingChunkIndex: startChunkIndex,
                      startingCharOffset: startCharOffset,
                      forceRestart: !isSameChapter, // Only force restart if it's a different chapter
                      autoPlay: false,
                    );
                    
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlayerScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  },
                );
              },
              childCount: book.chapters.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Padding for FAB
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startListening(context, ref),
        icon: const Icon(Icons.play_arrow_rounded, size: 28),
        label: const Text('START LISTENING', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }

  Widget _buildCoverBackground(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (book.coverImagePath != null) ...[
          Image.file(
            File(book.coverImagePath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            ),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: Container(
              width: 150,
              height: 225,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: book.coverImagePath != null
                  ? Image.file(
                      File(book.coverImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _coverPlaceholder(context),
                    )
                  : _coverPlaceholder(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        Icons.menu_book_rounded,
        size: 64,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  String _infoLine(BookProgress progress) {
    final chapters = '${book.chapterCount} chapters';
    if (progress.finished) return '$chapters · finished';
    if (progress.started) {
      return '$chapters · ${(progress.fraction * 100).round()}% read';
    }
    return chapters;
  }

  Widget _buildBookInfo(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(libraryProgressProvider).value?[book.id] ?? BookProgress.none;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            book.author,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _infoLine(progress),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (progress.started) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteBook(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book? This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(libraryProvider.notifier).deleteBook(book.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _startListening(BuildContext context, WidgetRef ref) async {
    if (book.chapters.isEmpty) return;
    
    final db = ref.read(databaseServiceProvider);
    final playbackState = await db.getPlaybackState(book.id);
    
    var chapterToPlay = book.chapters.first;
    int chunkIndex = 0;
    int? charOffset;

    if (playbackState != null) {
      final lastChapterId = playbackState['last_chapter_id'] as String?;
      final lastChunkIndex = playbackState['last_position_words'] as int?;

      if (lastChapterId != null) {
        try {
          chapterToPlay = book.chapters.firstWhere((c) => c.id == lastChapterId);
          chunkIndex = lastChunkIndex ?? 0;
          charOffset = playbackState['last_position_chars'] as int?;
        } catch (_) {
          // ignore if not found
        }
      }
    }

    ref.read(playerProvider.notifier).playChapter(
          chapterToPlay,
          startingChunkIndex: chunkIndex,
          startingCharOffset: charOffset,
        );
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PlayerScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }
}
