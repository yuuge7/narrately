import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../widgets/chapter_list_item.dart';
import '../providers/player_provider.dart';
import '../providers/database_provider.dart';
import 'player_screen.dart';

import '../providers/epub_providers.dart';

class BookDetailScreen extends ConsumerWidget {
  final Book book;

  const BookDetailScreen({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Book'),
                  content: const Text('Are you sure you want to delete this book? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(context, ref),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: book.chapters.length,
              itemBuilder: (context, index) {
                final chapter = book.chapters[index];
                return ChapterListItem(
                  chapter: chapter,
                  onTap: () {
                    ref.read(playerProvider.notifier).playChapter(chapter);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlayerScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            height: 150,
            child: book.coverImagePath != null
                ? Image.file(
                    File(book.coverImagePath!),
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.book, size: 48),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${book.chapterCount} chapters',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    if (book.chapters.isEmpty) return;
                    
                    final db = ref.read(databaseServiceProvider);
                    final lastChapterId = await db.getLastChapterId(book.id);
                    
                    var chapterToPlay = book.chapters.first;
                    if (lastChapterId != null) {
                      try {
                        chapterToPlay = book.chapters.firstWhere((c) => c.id == lastChapterId);
                      } catch (_) {
                        // ignore if not found
                      }
                    }
                    
                    ref.read(playerProvider.notifier).playChapter(chapterToPlay);
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlayerScreen(),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START LISTENING'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
