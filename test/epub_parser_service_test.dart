import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/services/epub_parser_service.dart';

void main() {
  group('EpubParserService - Text Extraction', () {
    test('extractPlainText handles empty or null', () {
      expect(EpubParserService.extractPlainText(null), '');
      expect(EpubParserService.extractPlainText(''), '');
    });

    test('extractPlainText replaces block tags with newlines', () {
      const html = '<h1>Chapter 1</h1><p>First paragraph.</p><div>Second block</div>';
      final text = EpubParserService.extractPlainText(html);
      
      expect(text, 'Chapter 1\n\nFirst paragraph.\n\nSecond block');
    });

    test('extractPlainText replaces br tags with single newline', () {
      const html = 'Line 1<br>Line 2<br/>Line 3<br />Line 4';
      final text = EpubParserService.extractPlainText(html);
      
      expect(text, 'Line 1\nLine 2\nLine 3\nLine 4');
    });

    test('extractPlainText decodes common entities', () {
      const html = '&lt;b&gt;Hello &amp; welcome to &quot;Narrately&quot;!&nbsp;It&#39;s great.&lt;/b&gt;';
      final text = EpubParserService.extractPlainText(html);
      
      expect(text, '<b>Hello & welcome to "Narrately"! It\'s great.</b>');
    });

    test('extractPlainText collapses excess whitespace and newlines', () {
      const html = '<p>   Lots   of \t spaces  </p><p>Next.</p>\n\n\n<p>End.</p>';
      final text = EpubParserService.extractPlainText(html);
      
      expect(text, 'Lots of spaces\n\nNext.\n\nEnd.');
    });
  });

  group('EpubParserService - Word Counting', () {
    test('countWords handles empty strings', () {
      expect(EpubParserService.countWords(''), 0);
      expect(EpubParserService.countWords('   \n  \t  '), 0);
    });

    test('countWords counts standard words correctly', () {
      expect(EpubParserService.countWords('Hello world'), 2);
      expect(EpubParserService.countWords('This is a test of word count.'), 7);
      expect(EpubParserService.countWords('One\nTwo\nThree'), 3);
    });
  });
}
