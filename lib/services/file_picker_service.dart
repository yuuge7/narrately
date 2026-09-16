import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<String?> pickBookFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
    );
    return file?.path;
  }
}
