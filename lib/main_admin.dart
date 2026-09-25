// KHỞI TẠO / GIAO DIỆN: Điểm chạy web quản trị: mở cổng Admin và trang tổng quan.
// Chạy: flutter run -t lib/main_admin.dart -d chrome.

import 'app/app_portal.dart';
import 'app/bootstrap.dart';
import 'app/elearning_app.dart';
import 'screens/admin/admin_home_screen.dart';

Future<void> main() => bootstrap(
  ElearningApp(
    portal: AppPortal.admin,
    homeBuilder: (_) => const AdminHomeScreen(),
  ),
);
