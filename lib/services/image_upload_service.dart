import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  static Future<String?> pickAndUpload(String folder) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Chọn ảnh tối đa 5 MB.');
    }
    final extension = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      throw ArgumentError('Định dạng ảnh không hợp lệ.');
    }
    final reference = FirebaseStorage.instance.ref(
      '$folder/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/${extension == 'jpg' ? 'jpeg' : extension}',
      ),
    );
    return reference.getDownloadURL();
  }
}
