import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/reading_progress.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final BookProgress progress;
  final VoidCallback onTap;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.progress = BookProgress.none,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CoverImage(path: book.coverImagePath),
                  if (progress.finished)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _FinishedBadge(),
                    ),
                ],
              ),
            ),
            if (progress.started)
              LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 4,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    if (!progress.started) return book.author;
    if (progress.finished) return 'Finished · ${book.author}';
    return '${(progress.fraction * 100).round()}% · ${book.author}';
  }
}

class _CoverImage extends StatelessWidget {
  final String? path;

  const _CoverImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.book, size: 48),
    );

    if (path == null) return placeholder;

    // The cover file can be missing: it lives in the app's storage, which a
    // restored backup does not bring with it.
    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        size: 14,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
