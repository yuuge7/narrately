import 'package:flutter/material.dart';
import '../models/chapter.dart';

class ChapterListItem extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;

  const ChapterListItem({
    super.key,
    required this.chapter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Rough reading time estimate: 150 words per minute for speech
    final int readingTimeMins = (chapter.wordCount / 150).ceil();
    
    return ListTile(
      title: Text(chapter.title),
      subtitle: Text(
        '${chapter.wordCount} words • ~${readingTimeMins}m listen',
      ),
      leading: CircleAvatar(
        child: Text('${chapter.index + 1}'),
      ),
      onTap: onTap,
    );
  }
}
