import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/services/text_chunker.dart';

void main() {
  group('chunkIntoSentences - basics', () {
    test('splits plain sentences', () {
      expect(
        chunkIntoSentences('One thing happened. Then another. And a third.'),
        ['One thing happened.', 'Then another.', 'And a third.'],
      );
    });

    test('keeps a trailing fragment with no terminator', () {
      expect(
        chunkIntoSentences('A complete sentence. A dangling fragment'),
        ['A complete sentence.', 'A dangling fragment'],
      );
    });

    test('returns nothing for empty or blank input', () {
      expect(chunkIntoSentences(''), isEmpty);
      expect(chunkIntoSentences('   \n  '), isEmpty);
    });

    test('text with no terminator stays one chunk', () {
      expect(chunkIntoSentences('no punctuation at all'),
          ['no punctuation at all']);
    });

    test('handles ! and ? and runs of terminators', () {
      expect(
        chunkIntoSentences('Stop! Who goes there? Really?!'),
        ['Stop!', 'Who goes there?', 'Really?!'],
      );
    });
  });

  group('chunkIntoSentences - abbreviations', () {
    test('does not split a title from its name', () {
      // The exact failure seen while listening to Modern Mythology.
      expect(
        chunkIntoSentences('The reply of Mr. Max Muller was long.'),
        ['The reply of Mr. Max Muller was long.'],
      );
    });

    test('handles several titles', () {
      expect(
        chunkIntoSentences('Dr. Smith met Mrs. Jones and Prof. Brown today.'),
        ['Dr. Smith met Mrs. Jones and Prof. Brown today.'],
      );
    });

    test('handles scholarly abbreviations', () {
      expect(
        chunkIntoSentences('See vol. 2 ch. 4 and cf. Fig. 3 for details.'),
        ['See vol. 2 ch. 4 and cf. Fig. 3 for details.'],
      );
    });

    test('handles initials', () {
      expect(
        chunkIntoSentences('It was J. R. R. Tolkien who wrote it.'),
        ['It was J. R. R. Tolkien who wrote it.'],
      );
    });

    test('handles lettered abbreviations with internal periods', () {
      expect(
        chunkIntoSentences('He left the U.S.A. and never returned.'),
        ['He left the U.S.A. and never returned.'],
      );
    });

    test('handles decimals', () {
      expect(
        chunkIntoSentences('It cost 3.50 in total. That was cheap.'),
        ['It cost 3.50 in total.', 'That was cheap.'],
      );
    });

    test('an abbreviation still splits at a paragraph break', () {
      expect(
        chunkIntoSentences('Sold by Acme Co.\n\nThe next chapter begins.'),
        ['Sold by Acme Co.', 'The next chapter begins.'],
      );
    });

    test('a real sentence after a name still splits', () {
      expect(
        chunkIntoSentences('This was said by Mr. Muller. The reply came later.'),
        ['This was said by Mr. Muller.', 'The reply came later.'],
      );
    });
  });

  group('chunkIntoSentences - Romanian', () {
    test('does not split a title from its name', () {
      expect(
        chunkIntoSentences('A venit dl. Popescu la ședință.'),
        ['A venit dl. Popescu la ședință.'],
      );
      expect(
        chunkIntoSentences('Dna. Ionescu a plecat. Apoi a revenit.'),
        ['Dna. Ionescu a plecat.', 'Apoi a revenit.'],
      );
    });

    test('handles professional titles', () {
      expect(
        chunkIntoSentences('Lucrarea e semnată de ing. Vasile și arh. Radu.'),
        ['Lucrarea e semnată de ing. Vasile și arh. Radu.'],
      );
    });

    test('handles Sf. before a saint name', () {
      expect(
        chunkIntoSentences('Biserica Sf. Gheorghe este veche.'),
        ['Biserica Sf. Gheorghe este veche.'],
      );
    });

    test('handles î.Hr. and d.Hr.', () {
      expect(
        chunkIntoSentences('Roma a fost fondată în 753 î.Hr. Legenda spune altceva.'),
        ['Roma a fost fondată în 753 î.Hr. Legenda spune altceva.'],
      );
    });

    test('handles ș.a.m.d.', () {
      expect(
        chunkIntoSentences('Erau mere, pere ș.a.m.d. Nimic altceva.'),
        ['Erau mere, pere ș.a.m.d. Nimic altceva.'],
      );
    });

    test('keeps a citation attached to its number', () {
      // "art." and "lit." are deliberately not in the abbreviation set, because
      // they end English sentences normally; the digit rule covers them here.
      expect(
        chunkIntoSentences('Conform art. 5 lit. b din lege, se aplică.'),
        ['Conform art. 5 lit. b din lege, se aplică.'],
      );
      expect(
        chunkIntoSentences('Vezi pag. 47 și nr. 12 din volum.'),
        ['Vezi pag. 47 și nr. 12 din volum.'],
      );
    });

    test('an English sentence ending in those words still splits', () {
      expect(
        chunkIntoSentences('He studied modern art. The next year he left.'),
        ['He studied modern art.', 'The next year he left.'],
      );
    });

    test('a lower-case continuation with diacritics is not a boundary', () {
      expect(
        chunkIntoSentences('Spunea "Stai!" și apoi a plecat în oraș.'),
        ['Spunea "Stai!" și apoi a plecat în oraș.'],
      );
    });

    test('splits normal Romanian sentences', () {
      expect(
        chunkIntoSentences('Era o zi însorită. Copiii se jucau afară. Toți râdeau.'),
        ['Era o zi însorită.', 'Copiii se jucau afară.', 'Toți râdeau.'],
      );
    });

    test('a capitalised word with diacritics starts a new chunk', () {
      expect(
        chunkIntoSentences('A plecat devreme. Înainte de prânz a revenit.'),
        ['A plecat devreme.', 'Înainte de prânz a revenit.'],
      );
    });
  });

  group('chunkIntoSentences - continuations', () {
    test('a lower-case continuation is not a boundary', () {
      expect(
        chunkIntoSentences('He shouted "Stop!" and then he ran away.'),
        ['He shouted "Stop!" and then he ran away.'],
      );
    });

    test('closing quotes stay with their sentence', () {
      expect(
        chunkIntoSentences('"Go away." She turned around.'),
        ['"Go away."', 'She turned around.'],
      );
    });

    test('recovers a boundary when a PDF dropped the space', () {
      expect(
        chunkIntoSentences('The first sentence.The second sentence.'),
        ['The first sentence.', 'The second sentence.'],
      );
    });
  });

  group('chunkIntoSentences - engine limits', () {
    test('splits a chunk that exceeds the TTS input limit', () {
      final long = '${List.filled(2000, 'word').join(' ')}.';
      final chunks = chunkIntoSentences(long);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(3500));
      }
    });

    test('an oversized chunk loses no words', () {
      final long = '${List.generate(2000, (i) => 'w$i').join(' ')}.';
      final rejoined = chunkIntoSentences(long).join(' ');

      expect(rejoined.split(RegExp(r'\s+')).length, 2000);
    });

    test('a single unbroken token is still bounded', () {
      final chunks = chunkIntoSentences('x' * 9000);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(3500));
      }
    });
  });
}
