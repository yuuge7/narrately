import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<String?> pickEpubFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    return file?.path;
  }
}
