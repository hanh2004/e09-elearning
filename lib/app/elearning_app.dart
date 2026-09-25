// KHỞI TẠO / GIAO DIỆN: Khung ứng dụng: tiêu đề, giao diện theo cổng và trang đăng nhập.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'app_portal.dart';
import '../widgets/admin_ui.dart';
import 'learner_theme.dart';

class ElearningApp extends StatelessWidget {
  const ElearningApp({
    super.key,
    required this.portal,
    required this.homeBuilder,
    this.initialHome,
  });

  final AppPortal portal;
  final Widget Function(Map<String, dynamic>) homeBuilder;
  final Widget? initialHome;

  @override
  Widget build(BuildContext context) {
    return PortalScope(
      portal: portal,
      homeBuilder: homeBuilder,
      child: MaterialApp(
        title: portal.title,
        debugShowCheckedModeBanner: false,
        theme: portal == AppPortal.user ? LearnerTheme.light : AdminUi.theme,
        builder: portal == AppPortal.user
            ? (context, child) =>
                  LearnerViewport(child: child ?? const SizedBox.shrink())
            : null,
        home: initialHome ?? const LoginScreen(),
      ),
    );
  }
}
