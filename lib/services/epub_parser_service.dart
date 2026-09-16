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

  Future<Book> parseEpub(String filePath) async {
    try {
      var bytes = await File(filePath).readAsBytes();
      bytes = _patchEpubBytesIfNeeded(bytes);
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
