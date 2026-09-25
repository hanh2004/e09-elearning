// Chọn cách tải file theo nền tảng đang chạy.

export 'report_excel_download_native.dart'
    if (dart.library.js_interop) 'report_excel_download_web.dart';
