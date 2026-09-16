import 'dart:io';
import 'dart:typed_data';
import 'package:epub_pro/epub_pro.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/chapter.dart';

class EpubParserException implements Exception {
  final String message;
  EpubParserException(this.message);

  @override
  String toString() => message;
}

class EpubParserService {
  final _uuid = const Uuid();

  Future<Book> parseEpub(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      final title = epubBook.title?.trim().isNotEmpty == true
          ? epubBook.title!
          : _getFileNameWithoutExtension(filePath);

      final author = epubBook.author?.trim().isNotEmpty == true
          ? epubBook.author!
          : 'Unknown Author';

      Uint8List? coverBytes;
      if (epubBook.coverImage != null) {
        coverBytes = Uint8List.fromList(img.encodePng(epubBook.coverImage!));
      }

      final flattenedChapters = _flattenChapters(epubBook.chapters);
      
      final bookId = _uuid.v4();
      final chapters = <Chapter>[];

      for (int i = 0; i < flattenedChapters.length; i++) {
        final epubChap = flattenedChapters[i];
        final chapTitle = epubChap.title?.trim().isNotEmpty == true
            ? epubChap.title!
            : 'Chapter ${i + 1}';
            
        final plainText = EpubParserService.extractPlainText(epubChap.htmlContent);
        final wordCount = EpubParserService.countWords(plainText);
        
        chapters.add(Chapter(
          id: _uuid.v4(),
          bookId: bookId,
          index: i,
          title: chapTitle,
          textContent: plainText,
          wordCount: wordCount,
        ));
      }

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        coverBytes: coverBytes,
        chapterCount: chapters.length,
        importedAt: DateTime.now(),
        chapters: chapters,
      );
    } catch (e) {
      throw EpubParserException('Failed to parse EPUB file: $e');
    }
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    final result = <EpubChapter>[];
    for (final chapter in chapters) {
      result.add(chapter);
      if (chapter.subChapters.isNotEmpty) {
        result.addAll(_flattenChapters(chapter.subChapters));
      }
    }
    return result;
  }

  String _getFileNameWithoutExtension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    if (name.contains('.')) {
      return name.substring(0, name.lastIndexOf('.'));
    }
    return name;
  }

  static String extractPlainText(String? html) {
    if (html == null || html.isEmpty) return '';
    
    var text = html.replaceAll(
        RegExp(r'</?(?:p|div|h[1-6]|li|blockquote)[^>]*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');
        
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' \n'), '\n');
    text = text.replaceAll(RegExp(r'\n '), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
