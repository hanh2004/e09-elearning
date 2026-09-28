// Web Admin mới hỗ trợ tải file Excel trực tiếp từ trình duyệt.

import 'dart:typed_data';

Future<void> downloadReportExcel(Uint8List duLieuByte, String tenTep) {
  return Future.error(
    UnsupportedError('Excel export is only available in Web Admin.'),
  );
}
