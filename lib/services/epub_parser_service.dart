import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  Future<Book> parseEpub(String filePath, String appDocsDir) async {
    try {
      var bytes = await File(filePath).readAsBytes();
      bytes = _patchEpubBytesIfNeeded(bytes);
      final epubBook = await EpubReader.readBook(bytes);

      final title = epubBook.title?.trim().isNotEmpty == true
          ? epubBook.title!
          : 'Unknown Title';

      final author = epubBook.author?.trim().isNotEmpty == true
          ? epubBook.author!
          : 'Unknown Author';

      String? coverImagePath;
      if (epubBook.coverImage != null) {
        final imgBytes = Uint8List.fromList(img.encodePng(epubBook.coverImage!));
        final coverFileName = '${_uuid.v4()}_cover.png';
        final coverFile = File('$appDocsDir/$coverFileName');
        await coverFile.writeAsBytes(imgBytes);
        coverImagePath = coverFile.path;
      }

      final flattenedChapters = _flattenChapters(epubBook.chapters);
      
      final bookId = _uuid.v4();
      final chapters = <Chapter>[];
      final seenFiles = <String>{};

      for (int i = 0; i < flattenedChapters.length; i++) {
        final epubChap = flattenedChapters[i];
        
        // Prevent duplication if multiple TOC entries point to the same HTML file
        if (epubChap.contentFileName != null) {
          if (seenFiles.contains(epubChap.contentFileName!)) {
            continue;
          }
          seenFiles.add(epubChap.contentFileName!);
        }
        
        final chapTitle = epubChap.title?.trim().isNotEmpty == true
            ? epubChap.title!
            : 'Chapter ${chapters.length + 1}';
            
        final plainText = EpubParserService.extractPlainText(epubChap.htmlContent);
        final wordCount = EpubParserService.countWords(plainText);
        
        // Skip completely empty chapters
        if (wordCount == 0) continue;
        
        chapters.add(Chapter(
          id: _uuid.v4(),
          bookId: bookId,
          index: chapters.length,
          title: chapTitle,
          textContent: plainText,
          wordCount: wordCount,
        ));
      }

      // If we still have too many tiny chapters, concatenate them
      final mergedChapters = _mergeTinyChapters(chapters);

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        coverImagePath: coverImagePath,
        chapters: mergedChapters,
      );
    } catch (e) {
      throw Exception('Failed to parse EPUB file: $e');
    }
  }

  List<Chapter> _mergeTinyChapters(List<Chapter> original) {
    if (original.isEmpty) return original;
    
    final merged = <Chapter>[];
    Chapter current = original.first;
    
    for (int i = 1; i < original.length; i++) {
      final next = original[i];
      // If current is less than 500 words or the next is less than 500 words, merge them
      // (This prevents tiny 1-minute chapters)
      if (current.wordCount < 500 || next.wordCount < 100) {
        current = current.copyWith(
          title: '${current.title} / ${next.title}',
          textContent: '${current.textContent}\n\n${next.title}\n\n${next.textContent}',
          wordCount: current.wordCount + next.wordCount,
        );
      } else {
        merged.add(current.copyWith(index: merged.length));
        current = next;
      }
    }
    merged.add(current.copyWith(index: merged.length));
    
    return merged;
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

  static Uint8List _patchEpubBytesIfNeeded(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      bool modified = false;
      ArchiveFile? opfFile;
      
      for (var file in archive) {
        if (file.name.endsWith('.opf')) {
          opfFile = file;
          break;
        }
      }

      if (opfFile != null) {
        String opfContent = String.fromCharCodes(opfFile.content as List<int>);
        
        // If it's version 3 and doesn't have properties="nav", it will crash epub_pro
        if (opfContent.contains('version="3.0"') || opfContent.contains('version="3"')) {
          if (!opfContent.contains('properties="nav"')) {
            // Try to find a toc/nav item and inject properties="nav"
            final navRegex = RegExp(r'<item[^>]+(?:id="[^"]*nav[^"]*"|id="[^"]*toc[^"]*"|href="[^"]*nav[^"]*"|href="[^"]*toc[^"]*")[^>]*/>', caseSensitive: false);
            if (navRegex.hasMatch(opfContent)) {
               opfContent = opfContent.replaceFirstMapped(navRegex, (match) {
                 String item = match.group(0)!;
                 if (!item.contains('properties=')) {
                   return item.replaceFirst('/>', ' properties="nav"/>');
                 }
                 return item;
               });
               
               final newFile = ArchiveFile(opfFile.name, opfContent.codeUnits.length, opfContent.codeUnits);
               final index = archive.files.indexOf(opfFile);
               if (index != -1) archive.files[index] = newFile;
               
               modified = true;
            } else {
               // Downgrade to EPUB 2 parser
               opfContent = opfContent.replaceAll(RegExp(r'version="3\.\d"'), 'version="2.0"');
               opfContent = opfContent.replaceAll('version="3"', 'version="2.0"');
               
               final newFile = ArchiveFile(opfFile.name, opfContent.codeUnits.length, opfContent.codeUnits);
               final index = archive.files.indexOf(opfFile);
               if (index != -1) archive.files[index] = newFile;
               
               modified = true;
            }
          }
        }
      }

      if (modified) {
        final encoded = ZipEncoder().encode(archive);
        return Uint8List.fromList(encoded);
      }
    } catch (e) {
      // If patching fails, just return original bytes
    }
    return bytes;
  }

  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
