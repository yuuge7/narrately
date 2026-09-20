/// Splits chapter text into the units that get handed to the TTS engine one at
/// a time.
///
/// A plain `[.!?]` split breaks "Mr. Max Muller" into two utterances, which the
/// engine reads with an audible pause in the middle of the name and which makes
/// the on-screen highlight jump mid-name. The rules below keep a period that
/// belongs to an abbreviation, an initial or a decimal attached to its sentence.
///
/// Where a call is ambiguous this under-splits on purpose: a chunk that is one
/// sentence too long is merely read straight through, while a chunk that ends
/// too early is always audible.
library;

/// Android's TTS engine silently drops input past roughly 4000 characters, so
/// oversized chunks are broken up on whitespace before they ever reach it.
const int _maxChunkLength = 3500;

/// Words that take a trailing period without ending a sentence. Lowercase; the
/// comparison folds case.
const Set<String> _abbreviations = {
  // Titles and forms of address.
  'mr', 'mrs', 'ms', 'mx', 'dr', 'prof', 'st', 'sr', 'jr', 'rev', 'fr', 'hon',
  // Ranks and offices.
  'gen', 'col', 'capt', 'lt', 'sgt', 'maj', 'adm', 'cmdr', 'gov', 'pres',
  'sen', 'rep',
  // Scholarly and reference usage, which is dense in non-fiction.
  'vs', 'etc', 'al', 'cf', 'viz', 'ibid', 'ed', 'eds', 'trans', 'vol', 'vols',
  'ch', 'chap', 'fig', 'figs', 'no', 'nos', 'pp', 'pt', 'sec', 'par', 'ca',
  'approx', 'esp', 'incl',
  // Organisations.
  'inc', 'ltd', 'co', 'corp', 'dept', 'est',
  // Places.
  'mt', 'ft', 'ave', 'blvd', 'rd', 'sq', 'ste',
  // Months and days.
  'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov',
  'dec', 'mon', 'tue', 'tues', 'wed', 'thu', 'thur', 'thurs', 'fri', 'sat',
  'sun',

  // --- Romanian ---
  // Forms of address: dl., dna., dra., Sf.
  'dl', 'dlui', 'dna', 'dnei', 'dra', 'sf', 'sfta',
  // Professions and ranks not already covered above.
  // ('mr.' for maior already appears above as the English title.)
  'ing', 'arh', 'av', 'ec', 'pr', 'plt', 'slt',
  // Scholarly and editorial usage.
  'aprox', 'resp', 'trad', 'coord', 'red', 'cit', 'op', 'pag', 'alin',
  'urm', 'vezi', 'nr', 'lb', 'subst', 'adj', 'adv', 'vb',
  // Dates: î.Hr. / d.Hr. and the months that differ from the English list.
  'hr', 'ian', 'iun', 'iul',
  // Addresses and administrative units.
  'str', 'bd', 'bl', 'ap', 'et', 'sc', 'jud', 'loc', 'com', 'mun', 'soc',
  // Quantities.
  'mil', 'mld', 'buc',
};

/// One unit of narration, with where it starts in the chapter text.
///
/// The offset is what playback position is anchored to. Storing the chunk
/// index instead meant that any change to the splitting rules — a new
/// abbreviation, a re-import, a different app version — silently moved every
/// saved position in every book.
class TextChunk {
  final String text;

  /// Offset of the first character of [text] within the chapter it came from.
  final int start;

  const TextChunk(this.text, this.start);

  int get end => start + text.length;
}

List<String> chunkIntoSentences(String text) =>
    chunkWithOffsets(text).map((chunk) => chunk.text).toList();

List<TextChunk> chunkWithOffsets(String text) {
  final chunks = <TextChunk>[];
  var start = 0;
  var i = 0;

  while (i < text.length) {
    if (!_isTerminator(text[i])) {
      i++;
      continue;
    }

    // Take the whole run, so "?!" and "..." are treated as one terminator, then
    // absorb any closing quote or bracket that belongs to the same sentence.
    var end = i;
    while (end < text.length && _isTerminator(text[end])) {
      end++;
    }
    while (end < text.length && _isCloser(text[end])) {
      end++;
    }

    if (_endsSentence(text, i, end)) {
      _addChunk(chunks, text, start, end);
      start = end;
    }

    i = end;
  }

  _addChunk(chunks, text, start, text.length);
  return chunks;
}

/// Index of the chunk containing [offset], or the last one before it.
///
/// A saved offset can land inside whitespace that no chunk covers, and a
/// chapter re-parsed by a newer build can be shorter than it was, so this
/// never fails: it returns the nearest chunk at or before the offset.
int chunkIndexForOffset(List<TextChunk> chunks, int offset) {
  if (chunks.isEmpty) return 0;

  var low = 0;
  var high = chunks.length - 1;
  var result = 0;

  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (chunks[mid].start <= offset) {
      result = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return result;
}

/// [termStart] is the first terminator character, [afterTerm] the first
/// character past the terminator run and its closing punctuation.
bool _endsSentence(String text, int termStart, int afterTerm) {
  var gapEnd = afterTerm;
  while (gapEnd < text.length && _isSpace(text[gapEnd])) {
    gapEnd++;
  }

  if (gapEnd >= text.length) return true;

  final gap = text.substring(afterTerm, gapEnd);

  // A line break is a paragraph boundary whatever precedes it.
  if (gap.contains('\n')) return true;

  final next = text[gapEnd];

  // Only a period can be part of an abbreviation, an initial or a decimal.
  // These are checked before anything else, because a chain like "î.Hr." or
  // "U.S.A." has no space to reason about.
  final runIsPeriods = !text
      .substring(termStart, afterTerm)
      .split('')
      .any((c) => c == '!' || c == '?');

  if (runIsPeriods) {
    if (_isDecimalPoint(text, termStart)) return false;

    // "art. 5", "nr. 12", "pag. 47", "vol. 2": a period followed by a number is
    // a reference, never a sentence end. This keeps Romanian legal and academic
    // citation whole without having to list words like "art." or "lit.", which
    // end English sentences perfectly normally ("modern art. The next...").
    if (_isDigit(next)) return false;

    if (_followsAbbreviation(text, termStart)) return false;
  }

  if (gap.isEmpty) {
    // Nothing separates the two sides, so this is normally inside a token.
    // The exception is text extracted from a PDF, where the space after a full
    // stop is routinely lost: "sentence.The next".
    if (termStart == 0) return false;
    return _isLower(text[termStart - 1]) && _isUpper(next);
  }

  // A lower-case continuation means the sentence carried on.
  if (_isLower(next)) return false;

  return true;
}

bool _isDecimalPoint(String text, int periodIndex) {
  if (periodIndex == 0 || periodIndex + 1 >= text.length) return false;
  return _isDigit(text[periodIndex - 1]) && _isDigit(text[periodIndex + 1]);
}

bool _followsAbbreviation(String text, int periodIndex) {
  var start = periodIndex;
  while (start > 0 && _isLetter(text[start - 1])) {
    start--;
  }

  if (start == periodIndex) return false;

  final word = text.substring(start, periodIndex);

  // A lone letter is an initial: "J. R. R. Tolkien", "U. S.", "e.g.".
  if (word.length == 1) return true;

  return _abbreviations.contains(word.toLowerCase());
}

void _addChunk(List<TextChunk> chunks, String source, int rawStart, int rawEnd) {
  final chunk = _trimmed(source, rawStart, rawEnd);
  if (chunk == null) return;

  if (chunk.text.length <= _maxChunkLength) {
    chunks.add(chunk);
    return;
  }

  var start = chunk.start;
  final end = chunk.end;
  while (start < end) {
    final limit = start + _maxChunkLength;
    if (limit >= end) {
      final tail = _trimmed(source, start, end);
      if (tail != null) chunks.add(tail);
      return;
    }

    // lastIndexOf searches the whole source, so a space before this piece
    // would be found when the piece itself has none; the guard turns that
    // into a hard cut at the limit.
    var cut = source.lastIndexOf(' ', limit);
    if (cut <= start) cut = limit;

    final piece = _trimmed(source, start, cut);
    if (piece != null) chunks.add(piece);
    start = cut;
  }
}

/// [source] between [start] and [end] with the surrounding whitespace removed,
/// or null when nothing is left. Trimming through String keeps this in step
/// with what the rest of the app considers whitespace.
TextChunk? _trimmed(String source, int start, int end) {
  final raw = source.substring(start, end);
  final left = raw.trimLeft();
  final text = left.trimRight();
  if (text.isEmpty) return null;
  return TextChunk(text, start + (raw.length - left.length));
}

bool _isTerminator(String c) => c == '.' || c == '!' || c == '?';

bool _isCloser(String c) =>
    c == '"' || c == "'" || c == '”' || c == '’' || c == ')' ||
    c == ']' || c == '»';

bool _isSpace(String c) =>
    c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ' ';

bool _isLetter(String c) => c.toLowerCase() != c.toUpperCase();

bool _isLower(String c) => c.toLowerCase() == c && c.toUpperCase() != c;

bool _isUpper(String c) => c.toUpperCase() == c && c.toLowerCase() != c;

bool _isDigit(String c) {
  final unit = c.codeUnitAt(0);
  return unit >= 0x30 && unit <= 0x39;
}
