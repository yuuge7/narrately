import 'package:flutter_test/flutter_test.dart';
import 'package:narrately/services/voice_matcher.dart';

List<Map<String, String>> _voices(List<List<String>> rows) =>
    rows.map((r) => {'name': r[0], 'locale': r[1]}).toList();

void main() {
  group('primaryLanguageCode', () {
    test('reduces a tag to its primary subtag', () {
      expect(primaryLanguageCode('ro'), 'ro');
      expect(primaryLanguageCode('ro-RO'), 'ro');
      expect(primaryLanguageCode('ro_RO'), 'ro');
      expect(primaryLanguageCode('EN-gb'), 'en');
      expect(primaryLanguageCode('  ro-RO  '), 'ro');
    });

    test('returns null for nothing usable', () {
      expect(primaryLanguageCode(null), isNull);
      expect(primaryLanguageCode(''), isNull);
      expect(primaryLanguageCode('   '), isNull);
      expect(primaryLanguageCode('-RO'), isNull);
    });
  });

  group('pickVoiceForLanguage', () {
    final installed = _voices([
      ['en-us-x-tpf-local', 'en-US'],
      ['en-gb-x-gba-local', 'en-GB'],
      ['ro-ro-x-rod-network', 'ro-RO'],
      ['ro-ro-x-rod-local', 'ro-RO'],
      ['de-de-x-deb-network', 'de-DE'],
    ]);

    test('matches on the primary subtag', () {
      final voice = pickVoiceForLanguage(installed, 'ro');
      expect(voice?['locale'], 'ro-RO');
    });

    test('prefers an offline voice over a network one', () {
      // The app makes no network calls, so a server-side voice would fail.
      final voice = pickVoiceForLanguage(installed, 'ro');
      expect(voice?['name'], 'ro-ro-x-rod-local');
    });

    test('prefers the matching region when one is asked for', () {
      final voice = pickVoiceForLanguage(
        installed,
        'en',
        preferredLocale: 'en-GB',
      );
      expect(voice?['locale'], 'en-GB');
    });

    test('falls back to any voice of the language', () {
      final voice = pickVoiceForLanguage(
        installed,
        'en',
        preferredLocale: 'en-AU',
      );
      expect(voice?['locale'], anyOf('en-US', 'en-GB'));
    });

    test('takes a network voice when it is the only one', () {
      final voice = pickVoiceForLanguage(installed, 'de');
      expect(voice?['name'], 'de-de-x-deb-network');
    });

    test('returns null when the language is not installed', () {
      expect(pickVoiceForLanguage(installed, 'ja'), isNull);
      expect(pickVoiceForLanguage(const [], 'ro'), isNull);
    });

    test('ignores malformed entries', () {
      final voice = pickVoiceForLanguage(
        [
          {'name': 'broken'},
          {'locale': 'ro-RO'},
          {'name': 'ro-ro-x-rod-local', 'locale': 'ro-RO'},
        ],
        'ro',
      );
      expect(voice?['name'], 'ro-ro-x-rod-local');
    });
  });
}
