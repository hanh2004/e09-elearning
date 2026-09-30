// KHỞI TẠO / GIAO DIỆN: Điểm chạy web quản trị: mở cổng Admin và trang tổng quan.
// Chạy: flutter run -t lib/diem_vao_quan_tri.dart -d chrome.

import 'app/cong_ung_dung.dart';
import 'app/khoi_dong_ung_dung.dart';
import 'app/ung_dung_hoc_tap_so.dart';
import 'screens/admin/trang_chu_quan_tri.dart';
import 'screens/admin/khoi_phuc_phien_quan_tri.dart';

Future<void> main() => bootstrap(
  ElearningApp(
    portal: AppPortal.admin,
    homeBuilder: (_) => const AdminHomeScreen(),
    initialHome: AdminSessionGate(homeBuilder: (_) => const AdminHomeScreen()),
  ),
  useIsolatedAdminWebSessions: true,
);
