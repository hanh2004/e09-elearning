// KHỞI TẠO / GIAO DIỆN: Điểm chạy app học viên: cấu hình màn hình dọc và thông tin người đăng nhập.
// Chạy: flutter run -t lib/diem_vao_hoc_vien.dart; menu chính nằm trong bo_cuc_chinh_hoc_vien.dart.

import 'app/cong_ung_dung.dart';
import 'app/khoi_dong_ung_dung.dart';
import 'app/ung_dung_hoc_tap_so.dart';
import 'models/tham_so_nguoi_dung.dart';
import 'screens/man_hinh_dang_nhap.dart';
import 'screens/user/man_hinh_khoi_dong_hoc_vien.dart';
import 'screens/user/bo_cuc_chinh_hoc_vien.dart';
import 'screens/user/cong_bao_tri_hoc_vien.dart';
import 'services/nghiep_vu/dich_vu_khoi_dong_hoc_vien.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await bootstrap(
    ElearningApp(
      portal: AppPortal.user,
      appBuilder: (_, child) =>
          UserMaintenanceGate(child: child ?? const SizedBox.shrink()),
      initialHome: UserSplashScreen(nextBuilder: (_) => const LoginScreen()),
      homeBuilder: (duLieu) {
        final userId = duLieu['id'].toString();
        return UserSplashScreen(
          prepare: () => UserStartupService().preload(userId),
          nextBuilder: (_) => UserMainLayout(
            args: UserArguments(
              userId: userId,
              userName:
                  duLieu['name']?.toString() ?? duLieu['username'].toString(),
              email: duLieu['email']?.toString() ?? '',
            ),
          ),
        );
      },
    ),
  );
}
