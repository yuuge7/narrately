import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import '../models/chapter.dart';
import 'book_parse_exception.dart';
import 'epub_parser_service.dart';

class PdfParserService {
  final _uuid = const Uuid();

  Future<Book> parsePdf(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      
      final title = p.basenameWithoutExtension(filePath);
      final author = 'Unknown Author'; // Hard to reliably extract author from PDF metadata without parsing XMP
      
      final chapters = <Chapter>[];
      final bookId = _uuid.v4();
      
      // Attempt to extract from bookmarks
      final bookmarksInfo = _extractBookmarks(document);
      
      if (bookmarksInfo.isNotEmpty) {
        // Sort by page index
        bookmarksInfo.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
        
        // Remove duplicates on the same page by keeping the first one
        final uniqueBookmarks = <_PdfBookmarkInfo>[];
        for (final bm in bookmarksInfo) {
          if (uniqueBookmarks.isEmpty || uniqueBookmarks.last.pageIndex != bm.pageIndex) {
            uniqueBookmarks.add(bm);
          } else {
            uniqueBookmarks.last.title += ' / ${bm.title}';
          }
        }
        
        for (int i = 0; i < uniqueBookmarks.length; i++) {
          final bm = uniqueBookmarks[i];
          final startPage = bm.pageIndex;
          
          // The end page is the page before the next bookmark, or the last page
          final endPage = (i < uniqueBookmarks.length - 1) 
              ? uniqueBookmarks[i + 1].pageIndex - 1 
              : document.pages.count - 1;
              
          if (startPage <= endPage) {
            final text = PdfTextExtractor(document).extractText(startPageIndex: startPage, endPageIndex: endPage);
            final cleanedText = _cleanText(text);
            final wordCount = EpubParserService.countWords(cleanedText);
            
            if (wordCount > 0) {
              chapters.add(Chapter(
                id: _uuid.v4(),
                bookId: bookId,
                index: chapters.length,
                title: bm.title,
                textContent: cleanedText,
                wordCount: wordCount,
              ));
            }
          }
        }
      } 
      
      // Fallback: chunk by every 10 pages if no bookmarks or if bookmarks extraction failed to yield text
      if (chapters.isEmpty) {
        final pagesPerChapter = 10;
        final totalPages = document.pages.count;
        
        for (int i = 0; i < totalPages; i += pagesPerChapter) {
          final startPage = i;
          final endPage = (i + pagesPerChapter - 1).clamp(0, totalPages - 1);
          
          final text = PdfTextExtractor(document).extractText(startPageIndex: startPage, endPageIndex: endPage);
          final cleanedText = _cleanText(text);
          final wordCount = EpubParserService.countWords(cleanedText);
          
          if (wordCount > 0) {
            chapters.add(Chapter(
              id: _uuid.v4(),
              bookId: bookId,
              index: chapters.length,
              title: 'Pages ${startPage + 1} - ${endPage + 1}',
              textContent: cleanedText,
              wordCount: wordCount,
            ));
          }
        }
      }
      
      document.dispose();
      
      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        coverImagePath: null, // PDF cover extraction is complex, skip for now
        chapters: chapters,
      );
    } catch (e) {
      throw BookParseException(
        'This PDF could not be read: ${describeError(e)}',
      );
    }
  }
  
  List<_PdfBookmarkInfo> _extractBookmarks(PdfDocument document) {
    final result = <_PdfBookmarkInfo>[];
    try {
      for (int i = 0; i < document.bookmarks.count; i++) {
        final bm = document.bookmarks[i];
        _processBookmark(bm, document, result);
      }
    } catch (e) {
      // Ignore bookmark extraction errors
    }
    return result;
  }
  
  void _processBookmark(PdfBookmark bookmark, PdfDocument document, List<_PdfBookmarkInfo> result) {
    try {
      if (bookmark.destination != null) {
        final page = bookmark.destination!.page;
        final pageIndex = document.pages.indexOf(page);
        if (pageIndex >= 0) {
          result.add(_PdfBookmarkInfo(title: bookmark.title, pageIndex: pageIndex));
        }
      }
      
      // Process children
      for (int i = 0; i < bookmark.count; i++) {
        _processBookmark(bookmark[i], document, result);
      }
    } catch (e) {
      // Ignore errors for individual bookmarks
    }
  }

  String _cleanText(String text) {
    // Basic cleanup for PDF extracted text
    var cleaned = text.replaceAll(RegExp(r'\r\n'), '\n');
    // Remove multiple consecutive newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }
}

class _PdfBookmarkInfo {
  String title;
  final int pageIndex;
  
  _PdfBookmarkInfo({required this.title, required this.pageIndex});
}
