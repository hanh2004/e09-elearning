// GIAO DIỆN DÙNG CHUNG: Ảnh đại diện mặc định trong suốt, dùng khi tài khoản chưa có ảnh riêng.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';

/// Ảnh đại diện mặc định trong suốt, dùng khi tài khoản chưa có ảnh riêng.
class DefaultUserAvatar extends StatelessWidget {
  const DefaultUserAvatar({super.key, this.radius = 32});

  final double radius;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Image.asset(
        AppTheme.defaultUserAvatar,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person_outline, size: radius, color: Colors.blueGrey),
      ),
    ),
  );
}
