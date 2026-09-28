// XỬ LÝ DỮ LIỆU / API: Chọn file Excel trên thiết bị qua file_picker.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'loi_chon_bang_tinh.dart';

Future<Uint8List?> pickWorkbookFile() async {
  final tep = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (tep == null) return null;
  final duLieuByte = await tep.readAsBytes();
  validateWorkbookFile(tep.name, duLieuByte.length);
  if (duLieuByte.isEmpty) {
    throw const WorkbookPickerException(
      'Đã chọn file nhưng không nhận được dữ liệu. Hãy tải file về ổ đĩa rồi chọn lại.',
    );
  }
  return duLieuByte;
}
