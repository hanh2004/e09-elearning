// KHỞI TẠO / GIAO DIỆN: Khung ứng dụng: tiêu đề, giao diện theo cổng và trang đăng nhập.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../screens/man_hinh_dang_nhap.dart';
import 'cong_ung_dung.dart';
import '../widgets/giao_dien_quan_tri.dart';
import 'chu_de_hoc_vien.dart';

class ElearningApp extends StatelessWidget {
  const ElearningApp({
    super.key,
    required this.portal,
    required this.homeBuilder,
    this.initialHome,
    this.appBuilder,
  });

  final AppPortal portal;
  final Widget Function(Map<String, dynamic>) homeBuilder;
  final Widget? initialHome;
  final TransitionBuilder? appBuilder;

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
            ? (context, child) => LearnerViewport(
                child:
                    appBuilder?.call(context, child) ??
                    child ??
                    const SizedBox.shrink(),
              )
            : appBuilder,
        home: initialHome ?? const LoginScreen(),
      ),
    );
  }
}
