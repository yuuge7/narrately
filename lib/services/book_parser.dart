import 'dart:io';

import '../models/book.dart';
import 'book_fingerprint.dart';
import 'epub_parser_service.dart';
import 'pdf_parser_service.dart';

/// Arguments for [parseBookFile]. A single sendable object, because that is
/// what `compute` accepts.
class ParseRequest {
  final String filePath;
  final String appDocsDir;

  const ParseRequest({required this.filePath, required this.appDocsDir});
}

/// Reads and parses a book file. Meant to be run through `compute`.
///
/// Reading the bytes and running epub_pro or syncfusion are all synchronous
/// enough to hold the UI thread for seconds, which is why the import progress
/// bar could not even animate while it was happening.
///
/// Plugin channels are unavailable on a background isolate, so the documents
/// directory is resolved by the caller and passed in rather than looked up
/// here with path_provider.
Future<Book> parseBookFile(ParseRequest request) async {
  if (request.filePath.toLowerCase().endsWith('.pdf')) {
    return PdfParserService().parsePdf(request.filePath);
  }
  return EpubParserService().parseEpub(request.filePath, request.appDocsDir);
}

/// Fingerprints each path that can still be read, keyed by path.
///
/// Paths that no longer exist, or cannot be read, are simply absent from the
/// result: a book whose cached source file is gone cannot be matched, and that
/// is not an error.
Future<Map<String, String>> fingerprintFiles(List<String> paths) async {
  final results = <String, String>{};

  for (final path in paths) {
    if (results.containsKey(path)) continue;
    try {
      final file = File(path);
      if (!await file.exists()) continue;
      results[path] = bookFingerprint(await file.readAsBytes());
    } catch (e) {
      // Unreadable file: leave it out.
      continue;
    }
  }

  return results;
}
