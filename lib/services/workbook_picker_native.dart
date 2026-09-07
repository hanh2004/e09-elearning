import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'workbook_picker_error.dart';

Future<Uint8List?> pickWorkbookFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  validateWorkbookFile(file.name, bytes.length);
  if (bytes.isEmpty) {
    throw const WorkbookPickerException(
      'Đã chọn file nhưng không nhận được dữ liệu. Hãy tải file về ổ đĩa rồi chọn lại.',
    );
  }
  return bytes;
}
