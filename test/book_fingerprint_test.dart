import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/services/book_fingerprint.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('bookFingerprint', () {
    test('identical content produces the same fingerprint', () {
      final a = _bytes([1, 2, 3, 4, 5]);
      final b = _bytes([1, 2, 3, 4, 5]);

      expect(bookFingerprint(a), bookFingerprint(b));
    });

    test('a single changed byte produces a different fingerprint', () {
      expect(
        bookFingerprint(_bytes([1, 2, 3, 4, 5])),
        isNot(bookFingerprint(_bytes([1, 2, 3, 4, 6]))),
      );
    });

    test('reordered bytes produce a different fingerprint', () {
      expect(
        bookFingerprint(_bytes([1, 2, 3])),
        isNot(bookFingerprint(_bytes([3, 2, 1]))),
      );
    });

    test('different lengths produce different fingerprints', () {
      expect(
        bookFingerprint(_bytes([1, 2, 3])),
        isNot(bookFingerprint(_bytes([1, 2, 3, 0]))),
      );
    });

    test('empty content is handled', () {
      expect(bookFingerprint(_bytes([])), isNotEmpty);
      expect(bookFingerprint(_bytes([])), bookFingerprint(_bytes([])));
    });

    test('fingerprints are stable across a large payload', () {
      final large = Uint8List.fromList(
        List<int>.generate(200000, (i) => (i * 31) % 256),
      );
      final copy = Uint8List.fromList(large);

      expect(bookFingerprint(large), bookFingerprint(copy));
    });
  });
}
