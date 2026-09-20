import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epub_pro/epub_pro.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import 'book_parse_exception.dart';

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

      final language = _firstLanguage(epubBook);

      final flattenedChapters = _flattenChapters(epubBook.chapters);

      final bookId = _uuid.v4();
      final chapters = <Chapter>[];
      final frontMatterIds = <String>{};
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
            
        final plainText = stripLeadingTitle(
          EpubParserService.extractPlainText(epubChap.htmlContent),
          chapTitle,
        );
        final wordCount = EpubParserService.countWords(plainText);

        // Skip completely empty chapters
        if (wordCount == 0) continue;

        final chapterId = _uuid.v4();
        if (isFrontMatter(chapTitle, plainText, wordCount)) {
          frontMatterIds.add(chapterId);
        }

        chapters.add(Chapter(
          id: chapterId,
          bookId: bookId,
          index: chapters.length,
          title: chapTitle,
          textContent: plainText,
          wordCount: wordCount,
        ));
      }

      // Publisher boilerplate is dropped, unless that would empty the book.
      var content =
          chapters.where((c) => !frontMatterIds.contains(c.id)).toList();
      if (content.isEmpty) content = chapters;

      // If we still have too many tiny chapters, concatenate them
      final mergedChapters = _mergeTinyChapters(content);

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        coverImagePath: coverImagePath,
        language: language,
        chapters: mergedChapters,
      );
    } catch (e) {
      throw BookParseException(
        'This EPUB could not be read: ${describeError(e)}',
      );
    }
  }

  static String? _firstLanguage(EpubBook book) {
    final languages = book.schema?.package?.metadata?.languages;
    if (languages == null) return null;
    for (final language in languages) {
      final trimmed = language.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// Section titles that mark publisher front matter rather than something a
  /// listener wants read. Compared against the trimmed, lower-cased title.
  static const Set<String> _frontMatterTitles = {
    'cover', 'cover page', 'title page', 'titlepage', 'half title',
    'half-title', 'halftitle', 'copyright', 'copyright page', 'copyright notice',
    'colophon', 'imprint', 'front matter', 'frontmatter', 'also by this author',
    'about the publisher', 'praise for this book', 'table of contents',
    'contents',
  };

  static final RegExp _copyrightMarker = RegExp(
    r'all rights reserved|may not be reproduced|©|\bisbn\b',
    caseSensitive: false,
  );

  /// True for a section the listener did not ask to hear, such as the cover or
  /// the licence page. The word-count bound keeps a real chapter that happens
  /// to mention a copyright from being thrown away.
  static bool isFrontMatter(String title, String text, int wordCount) {
    if (_frontMatterTitles.contains(title.trim().toLowerCase())) return true;
    return wordCount < 300 && _copyrightMarker.hasMatch(text);
  }

  /// Drops a heading that only repeats the chapter's own title, which is what
  /// an `<h1>` matching the table-of-contents label produces.
  static String stripLeadingTitle(String text, String title) {
    final heading = title.trim();
    if (heading.isEmpty) return text;

    final body = text.trimLeft();
    if (body.length <= heading.length) return text;
    if (body.substring(0, heading.length).toLowerCase() !=
        heading.toLowerCase()) {
      return text;
    }

    // Only strip it when the title stands alone on its own line, so a chapter
    // whose first sentence begins with its title is left intact. Trailing
    // spaces before the break are common in extracted markup.
    final rest =
        body.substring(heading.length).replaceFirst(RegExp(r'^[ \t]+'), '');
    if (!rest.startsWith('\n')) return text;

    return rest.trimLeft();
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
        // The first title names the merged section. Joining every title with
        // " / " produced entries like "Mr. Max Muller's Reply / Part II: The
        // Story of Daphne / Mr. Max Muller's Method in Controversy". The
        // absorbed titles stay in the body as section headings.
        current = current.copyWith(
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

  static final RegExp _headBlock =
      RegExp(r'<head\b[^>]*>.*?</head>', caseSensitive: false, dotAll: true);
  static final RegExp _scriptOrStyle = RegExp(
    r'<(script|style)\b[^>]*>.*?</\1\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _comment = RegExp(r'<!--.*?-->', dotAll: true);

  static String extractPlainText(String? html) {
    if (html == null || html.isEmpty) return '';

    // Everything in <head> is metadata, not narration. Leaving it in meant the
    // <title> element was read aloud immediately before the <h1> that repeats
    // it, and a <style> block would have been dictated as CSS.
    var text = html.replaceAll(_headBlock, ' ');
    text = text.replaceAll(_scriptOrStyle, ' ');
    text = text.replaceAll(_comment, ' ');

    text = text.replaceAll(
        RegExp(r'</?(?:p|div|h[1-6]|li|blockquote)[^>]*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    
    text = decodeEntities(text);

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

  static final RegExp _decimalEntity = RegExp(r'&#(\d{1,7});');
  static final RegExp _hexEntity = RegExp(r'&#[xX]([0-9a-fA-F]{1,6});');

  static const Map<String, String> _namedEntities = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&mdash;': '—',
    '&ndash;': '–',
    '&hellip;': '…',
    '&lsquo;': '‘',
    '&rsquo;': '’',
    '&ldquo;': '“',
    '&rdquo;': '”',
    '&laquo;': '«',
    '&raquo;': '»',
    '&bdquo;': '„',
    '&ldquor;': '„',
    '&shy;': '',
  };

  /// Turns character references into the characters they stand for.
  ///
  /// Numeric references matter well beyond the handful of named ones: a book
  /// whose text is escaped writes Romanian diacritics as `&#537;` / `&#539;`
  /// (ș / ț), and left undecoded the engine reads the digits aloud.
  static String decodeEntities(String input) {
    var text = input;

    text = text.replaceAllMapped(_decimalEntity, (match) {
      return _fromCharCode(int.tryParse(match.group(1)!), match.group(0)!);
    });

    text = text.replaceAllMapped(_hexEntity, (match) {
      return _fromCharCode(
        int.tryParse(match.group(1)!, radix: 16),
        match.group(0)!,
      );
    });

    _namedEntities.forEach((entity, replacement) {
      text = text.replaceAll(entity, replacement);
    });

    // Decoded last, so an escaped reference such as `&amp;#537;` survives as
    // literal text instead of being decoded a second time.
    return text.replaceAll('&amp;', '&');
  }

  static String _fromCharCode(int? code, String original) {
    if (code == null || code > 0x10ffff) return original;
    // Surrogate halves are not characters on their own.
    if (code >= 0xd800 && code <= 0xdfff) return original;
    // Tab, newline and carriage return carry layout; other controls do not.
    if (code < 0x20 && code != 0x09 && code != 0x0a && code != 0x0d) {
      return original;
    }
    return String.fromCharCode(code);
  }

  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
