import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/services/text_chunker.dart';

void main() {
  group('chunkWithOffsets', () {
    test('every chunk points at itself in the source text', () {
      const text = 'First one. Second one!  Third one?\n\nFourth one.';
      final chunks = chunkWithOffsets(text);

      expect(chunks, isNotEmpty);
      for (final chunk in chunks) {
        expect(
          text.substring(chunk.start, chunk.end),
          chunk.text,
          reason: 'offset ${chunk.start} does not point at "${chunk.text}"',
        );
      }
    });

    test('offsets increase and skip the whitespace between chunks', () {
      const text = 'Alpha.   Beta.\n\n\nGamma.';
      final chunks = chunkWithOffsets(text);

      expect(chunks.map((c) => c.text), ['Alpha.', 'Beta.', 'Gamma.']);
      expect(chunks[0].start, 0);
      expect(chunks[1].start, text.indexOf('Beta'));
      expect(chunks[2].start, text.indexOf('Gamma'));
    });

    test('an oversized chunk keeps offsets pointing into the source', () {
      final text = '${List.filled(2000, 'word').join(' ')}.';
      final chunks = chunkWithOffsets(text);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(text.substring(chunk.start, chunk.end), chunk.text);
      }
    });

    test('produces the same strings as chunkIntoSentences', () {
      const text = 'Mr. Smith went home. He slept.\n\nThen 3.5 days passed.';
      expect(
        chunkWithOffsets(text).map((c) => c.text).toList(),
        chunkIntoSentences(text),
      );
    });
  });

  group('chunkIndexForOffset', () {
    final chunks = chunkWithOffsets('Alpha. Beta. Gamma. Delta.');

    test('finds the chunk an offset falls inside', () {
      expect(chunkIndexForOffset(chunks, chunks[2].start), 2);
      expect(chunkIndexForOffset(chunks, chunks[2].start + 2), 2);
    });

    test('an offset in the gap belongs to the chunk before it', () {
      // The space between "Beta." and "Gamma." is covered by no chunk.
      final gap = chunks[1].end;
      expect(chunkIndexForOffset(chunks, gap), 1);
    });

    test('clamps rather than failing on an out-of-range offset', () {
      expect(chunkIndexForOffset(chunks, -50), 0);
      expect(chunkIndexForOffset(chunks, 100000), chunks.length - 1);
    });

    test('an empty chapter gives index zero', () {
      expect(chunkIndexForOffset(const [], 42), 0);
    });

    test('survives chunking rules that changed under a saved offset', () {
      // A position saved by a build that split "Dr." in two: the offset still
      // lands on the right sentence under the current rules.
      const text = 'Dr. Miller arrived late. The meeting had started.';
      final current = chunkWithOffsets(text);
      final savedOffset = text.indexOf('The meeting');

      expect(current[chunkIndexForOffset(current, savedOffset)].text,
          'The meeting had started.');
    });
  });
}
