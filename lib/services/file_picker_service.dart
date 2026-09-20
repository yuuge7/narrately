import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class FilePickerService {
  /// Lets the user pick one or more books at once.
  ///
  /// Returns the paths that the picker could actually materialise; an entry
  /// with no path (a cloud document the provider refused to copy) is dropped
  /// rather than reported, because there is nothing to import.
  Future<List<String>> pickBookFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
    );

    return [
      for (final file in files)
        if (file.path != null) file.path!,
    ];
  }

  /// Picks a backup to restore. The extension filter is deliberately absent:
  /// Android's document picker hides files whose MIME type it does not know,
  /// and `.db` is one of those on many devices.
  Future<String?> pickBackupFile() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    return file?.path;
  }

  /// Writes [bytes] wherever the user chooses. Returns null if they cancelled.
  Future<Uri?> saveBackup(String fileName, Uint8List bytes) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/octet-stream',
      dialogTitle: 'Save Narrately backup',
    );
  }
}
