/// Reduces a BCP-47 tag to its primary subtag: "ro-RO", "ro_RO" and "RO" all
/// become "ro". Returns null when there is nothing usable.
String? primaryLanguageCode(String? tag) {
  if (tag == null) return null;

  final trimmed = tag.trim();
  if (trimmed.isEmpty) return null;

  final separator = trimmed.indexOf(RegExp(r'[-_]'));
  final primary = separator == -1 ? trimmed : trimmed.substring(0, separator);
  if (primary.isEmpty) return null;

  return primary.toLowerCase();
}

/// Picks the best installed voice for [languageCode], or null when the device
/// has none — in which case the caller should keep whatever voice is set
/// rather than narrating in silence.
///
/// Offline voices are preferred: the app makes no network calls, so a voice
/// the engine only synthesises server-side would fail. After that, a voice
/// whose region matches [preferredLocale] wins, so an "en-GB" book is not read
/// in an American accent when both are installed.
Map<String, String>? pickVoiceForLanguage(
  List<Map<String, String>> voices,
  String languageCode, {
  String? preferredLocale,
}) {
  final wanted = languageCode.toLowerCase();
  final wantedFull = preferredLocale?.trim().toLowerCase().replaceAll('_', '-');

  Map<String, String>? best;
  var bestScore = 0;

  for (final voice in voices) {
    final locale = voice['locale'];
    final name = voice['name'];
    if (locale == null || name == null) continue;
    if (primaryLanguageCode(locale) != wanted) continue;

    var score = 0;
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    if (wantedFull != null && normalizedLocale == wantedFull) score += 4;

    final lowerName = name.toLowerCase();
    if (lowerName.contains('network')) {
      score -= 2;
    } else if (lowerName.contains('local')) {
      score += 2;
    }

    // The null check matters: a network-only language scores below zero, and
    // one bad voice still beats narrating in the wrong language.
    if (best == null || score > bestScore) {
      bestScore = score;
      best = voice;
    }
  }

  return best;
}
