// XỬ LÝ DỮ LIỆU / API: Thông báo lỗi chung khi chọn file Excel.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

class WorkbookPickerException implements Exception {
  const WorkbookPickerException(this.message);

  final String message;
}

void validateWorkbookFile(String ten, int kichThuoc) {
  if (!ten.toLowerCase().endsWith('.xlsx') || kichThuoc > 2 * 1024 * 1024) {
    throw const WorkbookPickerException('Chỉ nhận file .xlsx tối đa 2 MB.');
  }
}
