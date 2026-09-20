import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bookmark_provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../providers/player_provider.dart';
import 'player_screen.dart';

class BookmarksScreen extends ConsumerWidget {
  final Book book;

  const BookmarksScreen({super.key, required this.book});

  Chapter? _chapterFor(String? chapterId) {
    if (book.chapters.isEmpty) return null;
    for (final c in book.chapters) {
      if (c.id == chapterId) return c;
    }
    return book.chapters.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider(book.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
      ),
      body: bookmarksAsync.when(
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No bookmarks yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Add a bookmark while listening', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: bookmarks.length,
            separatorBuilder: (context, index) => const Divider(indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final b = bookmarks[index];
              final chapter = _chapterFor(b['chapter_id'] as String?);
              if (chapter == null) return const SizedBox.shrink();
              final chunkIndex = (b['chunk_index'] as int?) ?? 0;
              final note = (b['note'] as String?) ?? '';

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bookmark_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    if (note.isNotEmpty) Text('"$note"', style: const TextStyle(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text('Part ${chunkIndex + 1} • ${b['created_at'].toString().split('T').first}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    ref.read(bookmarkNotifierProvider.notifier).deleteBookmark(book.id, b['id'] as String);
                  },
                ),
                onTap: () {
                  ref.read(playerProvider.notifier).playChapter(
                        chapter,
                        startingChunkIndex: chunkIndex,
                        startingCharOffset: b['char_offset'] as int?,
                        forceRestart: true,
                      );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PlayerScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
