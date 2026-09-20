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

    test('extractPlainText decodes Romanian diacritics written as numeric entities', () {
      const html =
          '<p>&#206;n gr&#259;din&#259; erau &#537;apte flori &#537;i un copac &#238;nalt.</p>';
      final text = EpubParserService.extractPlainText(html);

      expect(text, 'În grădină erau șapte flori și un copac înalt.');
    });

    test('extractPlainText decodes hexadecimal entities', () {
      const html = '<p>&#x219;i &#x21B;ara &#x103;sta</p>';

      expect(EpubParserService.extractPlainText(html), 'și țara ăsta');
    });

    test('extractPlainText decodes typographic entities', () {
      const html = '<p>&ldquo;Salut&rdquo; &mdash; spuse el&hellip;</p>';

      expect(EpubParserService.extractPlainText(html), '“Salut” — spuse el…');
    });

    test('extractPlainText leaves a malformed reference alone', () {
      const html = '<p>Cost &#99999999; and &#xZZ; stay put.</p>';
      final text = EpubParserService.extractPlainText(html);

      expect(text, contains('&#99999999;'));
      expect(text, contains('&#xZZ;'));
    });

    test('extractPlainText does not decode an escaped reference twice', () {
      const html = '<p>Write &amp;#537; to get the letter.</p>';

      expect(
        EpubParserService.extractPlainText(html),
        'Write &#537; to get the letter.',
      );
    });

    test('extractPlainText drops head, script and style content', () {
      const html = '<html><head><title>Capitolul I</title>'
          '<style>body { color: red; }</style></head>'
          '<body><h1>Capitolul I</h1><p>A venit.</p>'
          '<script>var x = 1;</script></body></html>';

      expect(EpubParserService.extractPlainText(html), 'Capitolul I\n\nA venit.');
    });

    test('extractPlainText drops comments', () {
      const html = '<p>Before<!-- a note --> after.</p>';

      expect(EpubParserService.extractPlainText(html), 'Before after.');
    });
  });

  group('EpubParserService - Chapter Cleanup', () {
    test('stripLeadingTitle removes a heading repeating the title', () {
      expect(
        EpubParserService.stripLeadingTitle(
          'Capitolul I\n\nA venit dl. Popescu.',
          'Capitolul I',
        ),
        'A venit dl. Popescu.',
      );
    });

    test('stripLeadingTitle ignores case and surrounding space', () {
      expect(
        EpubParserService.stripLeadingTitle(
          '  CHAPTER ONE \n\nIt began.',
          'Chapter One',
        ),
        'It began.',
      );
    });

    test('stripLeadingTitle keeps a sentence that merely starts with the title', () {
      const text = 'Chapter One was the hardest to write.';

      expect(
        EpubParserService.stripLeadingTitle(text, 'Chapter One'),
        text,
      );
    });

    test('stripLeadingTitle leaves unrelated text alone', () {
      const text = 'Something else entirely.';

      expect(EpubParserService.stripLeadingTitle(text, 'Chapter One'), text);
      expect(EpubParserService.stripLeadingTitle(text, ''), text);
    });

    test('isFrontMatter flags publisher sections by title', () {
      expect(EpubParserService.isFrontMatter('Cover', 'x', 1000), isTrue);
      expect(EpubParserService.isFrontMatter('  copyright  ', 'x', 1000), isTrue);
      expect(EpubParserService.isFrontMatter('Title Page', 'x', 1000), isTrue);
    });

    test('isFrontMatter flags a short section carrying a licence notice', () {
      const notice = 'Copyright 2014 epubBooks. All Rights Reserved.';

      expect(EpubParserService.isFrontMatter('Untitled', notice, 40), isTrue);
    });

    test('isFrontMatter keeps a real chapter that mentions a copyright', () {
      const text = 'The copyright dispute ran for years. All rights reserved, '
          'the lawyer said, and the case went on.';

      expect(EpubParserService.isFrontMatter('Chapter 4', text, 5000), isFalse);
    });

    test('isFrontMatter keeps ordinary chapters', () {
      expect(
        EpubParserService.isFrontMatter('Introduction', 'It began.', 800),
        isFalse,
      );
      expect(
        EpubParserService.isFrontMatter('Capitolul I', 'A venit.', 800),
        isFalse,
      );
    });
  });

  group('EpubParserService - Whitespace', () {
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
