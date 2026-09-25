// GIAO DIỆN DÙNG CHUNG: Giữ nguyên ảnh huy hiệu; chỉ che phần trắng bên ngoài hình khiên.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Giữ nguyên ảnh huy hiệu; chỉ che phần trắng bên ngoài hình khiên.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.admin = false, this.height = 64});
  final bool admin;
  final double height;
  @override
  Widget build(BuildContext context) => admin
      ? ClipPath(
          clipper: _CatHinhKhien(),
          child: Image.asset(
            AppTheme.webLogo,
            height: height,
            width: height * 250 / 286,
            fit: BoxFit.fill,
          ),
        )
      : Image.asset(AppTheme.appLogo, height: height, width: height);
}

class _CatHinhKhien extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()
      ..moveTo(125, 5)
      ..cubicTo(91, 35, 47, 48, 5, 43)
      ..cubicTo(0, 149, 30, 230, 125, 281)
      ..cubicTo(220, 230, 250, 149, 245, 43)
      ..cubicTo(203, 48, 159, 35, 125, 5)
      ..close();
    final sx = s.width / 250;
    final sy = s.height / 286;
    return p.transform(
      Float64List.fromList([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
  }

  @override
  bool shouldReclip(_CatHinhKhien oldClipper) => false;
}
