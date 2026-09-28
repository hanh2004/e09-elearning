// KHỞI TẠO / GIAO DIỆN: Điểm chạy mặc định: chuyển sang app học viên trong diem_vao_hoc_vien.dart.
// Lệnh flutter run không truyền -t sẽ bắt đầu tại đây.

// Chạy `flutter run` sẽ mở App học viên, không mở cổng Admin.
import 'diem_vao_hoc_vien.dart' as user;

Future<void> main() => user.main();
