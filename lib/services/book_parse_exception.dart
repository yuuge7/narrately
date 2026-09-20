/// A book that could not be read, described in words meant for the user.
///
/// The import path shows `toString()` straight in the error banner, so this
/// deliberately omits the `Exception: ` prefix that `Exception()` adds. A
/// message built by wrapping a caught error used to reach the banner as
/// "Exception: Failed to parse EPUB file: Exception: ...".
class BookParseException implements Exception {
  final String message;

  const BookParseException(this.message);

  @override
  String toString() => message;
}

/// Renders any thrown object as a single readable line.
///
/// Errors cross an isolate boundary on the way out of `compute`, which turns a
/// typed exception back into a plain one, so the prefixes have to be stripped
/// from the text rather than avoided by catching a type.
String describeError(Object error) {
  var text = error.toString().trim();

  // `Exception:` can appear more than once when one layer wrapped another.
  // The trailing space is left off the pattern: an Exception with an empty
  // message renders as "Exception: " and trims down to "Exception:".
  const prefixes = ['Exception:', 'Error:', 'FileSystemException:'];
  var stripped = true;
  while (stripped) {
    stripped = false;
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
        stripped = true;
      }
    }
  }

  if (text.isEmpty) return 'That file could not be read.';
  return text;
}
