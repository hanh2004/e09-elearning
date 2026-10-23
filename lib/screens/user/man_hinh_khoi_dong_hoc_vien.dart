// GIAO DIỆN: Màn hình khởi động của ứng dụng học viên.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../man_hinh_dang_nhap.dart';

class UserSplashScreen extends StatefulWidget {
  const UserSplashScreen({
    super.key,
    this.duration = const Duration(seconds: 2),
    this.prepare,
    this.nextBuilder,
  });

  final Duration duration;
  final Future<void> Function()? prepare;
  final WidgetBuilder? nextBuilder;

  @override
  State<UserSplashScreen> createState() => _TrangThaiKhoiDongHocVien();
}

class _TrangThaiKhoiDongHocVien extends State<UserSplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_batDau());
  }

  Future<void> _batDau() async {
    try {
      if (widget.prepare != null) {
        await widget.prepare!().timeout(const Duration(seconds: 12));
      } else {
        await Future<void>.delayed(widget.duration);
      }
    } catch (_) {
      // Cho phép mở ứng dụng khi mạng tạm thời không sẵn sàng.
    }
    if (!mounted) return;
    _moTiep();
  }

  void _moTiep() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.nextBuilder ?? (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          AppTheme.learnerSplashBackground,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}
