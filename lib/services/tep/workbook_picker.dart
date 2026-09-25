// XỬ LÝ DỮ LIỆU / API: Tự chọn cách mở file Excel phù hợp với web hoặc thiết bị.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

export 'workbook_picker_native.dart'
    if (dart.library.js_interop) 'workbook_picker_web.dart';
