// KHỞI TẠO / GIAO DIỆN: Điểm chạy app học viên: cấu hình màn hình dọc và thông tin người đăng nhập.
// Chạy: flutter run -t lib/main_user.dart; menu chính nằm trong user_main_layout.dart.

import 'app/app_portal.dart';
import 'app/bootstrap.dart';
import 'app/elearning_app.dart';
import 'models/user_arguments.dart';
import 'screens/user/user_splash_screen.dart';
import 'screens/user/user_main_layout.dart';
import 'services/nghiep_vu/user_startup_service.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await bootstrap(
    ElearningApp(
      portal: AppPortal.user,
      initialHome: const UserSplashScreen(),
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
