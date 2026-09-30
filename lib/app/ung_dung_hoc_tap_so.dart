// KHỞI TẠO / GIAO DIỆN: Khung ứng dụng: tiêu đề, giao diện theo cổng và trang đăng nhập.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/man_hinh_dang_nhap.dart';
import 'cong_ung_dung.dart';
import '../widgets/giao_dien_quan_tri.dart';
import 'chu_de_hoc_vien.dart';
import '../services/tai_khoan/phien_dang_nhap_quan_tri_web.dart';

class ElearningApp extends StatefulWidget {
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
  State<ElearningApp> createState() => _ElearningAppState();
}

class _ElearningAppState extends State<ElearningApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _forcedOutSubscription;

  @override
  void initState() {
    super.initState();
    _forcedOutSubscription = AdminWebSession.forcedOut.listen((_) {
      _navigatorKey.currentState?.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _forcedOutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portal = widget.portal;
    final appBuilder = widget.appBuilder;
    return PortalScope(
      portal: portal,
      homeBuilder: widget.homeBuilder,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
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
        home: widget.initialHome ?? const LoginScreen(),
      ),
    );
  }
}
