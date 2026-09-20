import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/player_provider.dart';
import '../services/book_search.dart';
import 'player_screen.dart';

/// Full-text search inside one book, jumping playback to whatever is picked.
class BookSearchScreen extends ConsumerStatefulWidget {
  final Book book;

  const BookSearchScreen({super.key, required this.book});

  @override
  ConsumerState<BookSearchScreen> createState() => _BookSearchScreenState();
}

class _BookSearchScreenState extends ConsumerState<BookSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<ChapterMatch> _matches = const [];
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Every keystroke otherwise re-scans the whole book, which is noticeable
    // once a chapter runs to tens of thousands of characters.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _matches = searchBook(widget.book, value);
      });
    });
  }

  Future<void> _open(ChapterMatch match) async {
    final chapter = widget.book.chapters.firstWhere(
      (c) => c.id == match.chapterId,
      orElse: () => widget.book.chapters.first,
    );

    await ref.read(playerProvider.notifier).jumpTo(chapter, match.offset);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const PlayerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search in ${widget.book.title}',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Type a word or phrase to find where it is read.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Nothing found for "${_query.trim()}".'),
        ),
      );
    }

    return ListView.separated(
      itemCount: _matches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final match = _matches[index];
        return ListTile(
          title: Text(
            match.chapterTitle,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          subtitle: Text.rich(_highlight(context, match)),
          onTap: () => _open(match),
        );
      },
    );
  }

  TextSpan _highlight(BuildContext context, ChapterMatch match) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final end = match.matchStart + match.matchLength;

    return TextSpan(
      style: style,
      children: [
        TextSpan(text: match.snippet.substring(0, match.matchStart)),
        TextSpan(
          text: match.snippet.substring(match.matchStart, end),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
        TextSpan(text: match.snippet.substring(end)),
      ],
    );
  }
}
