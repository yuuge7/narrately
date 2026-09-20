import 'dart:typed_data';

/// FNV-1a 64-bit offset basis (0xcbf29ce484222325) as a signed 64-bit int.
const int _offsetBasis = -3750763034362895579;
const int _prime = 1099511628211;

/// A stable identity for an imported file, used to recognise a book that is
/// already in the library.
///
/// The picker copies each pick to a fresh cache path, so the file path says
/// nothing about whether two imports are the same book. Hashing the bytes does.
/// This is a dedupe key, not a security hash, so a fast non-cryptographic hash
/// is enough; the byte length is folded in so files of different sizes can
/// never share a fingerprint.
String bookFingerprint(Uint8List bytes) {
  var hash = _offsetBasis;
  for (var i = 0; i < bytes.length; i++) {
    hash ^= bytes[i];
    hash *= _prime;
  }

  final high = (hash >> 32).toUnsigned(32).toRadixString(16).padLeft(8, '0');
  final low = hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');

  return '${bytes.length.toRadixString(16)}-$high$low';
}
