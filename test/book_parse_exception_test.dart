import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/services/book_parse_exception.dart';

void main() {
  group('describeError', () {
    test('a BookParseException reads as written', () {
      const error = BookParseException('This EPUB could not be read: no spine');
      expect(describeError(error), 'This EPUB could not be read: no spine');
    });

    test('strips the prefix a plain Exception adds', () {
      expect(describeError(Exception('missing file')), 'missing file');
    });

    test('unwraps an error that was wrapped twice', () {
      // What crossing the isolate boundary used to produce: the typed
      // exception became a plain one, and the banner showed both prefixes.
      final wrapped = Exception('Exception: Failed to parse: bad zip');
      expect(describeError(wrapped), 'Failed to parse: bad zip');
    });

    test('never returns an empty string', () {
      expect(describeError(Exception('')), 'That file could not be read.');
      expect(describeError(Exception('   ')), 'That file could not be read.');
    });

    test('leaves an ordinary message alone', () {
      expect(describeError('Disk is full'), 'Disk is full');
    });
  });
}
