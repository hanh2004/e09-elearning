import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Keep the supplied badge pixels; hide only the white area outside its shield.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.admin = false, this.height = 64});
  final bool admin;
  final double height;
  @override
  Widget build(BuildContext context) => admin
      ? ClipPath(
          clipper: _ShieldClipper(),
          child: Image.asset(
            AppTheme.webLogo,
            height: height,
            width: height * 250 / 286,
            fit: BoxFit.fill,
          ),
        )
      : Image.asset(AppTheme.appLogo, height: height, width: height);
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()
      ..moveTo(125, 5)
      ..cubicTo(91, 35, 47, 48, 5, 43)
      ..cubicTo(0, 149, 30, 230, 125, 281)
      ..cubicTo(220, 230, 250, 149, 245, 43)
      ..cubicTo(203, 48, 159, 35, 125, 5)
      ..close();
    return p.transform(
      Matrix4.diagonal3Values(s.width / 250, s.height / 286, 1).storage,
    );
  }

  @override
  bool shouldReclip(_ShieldClipper oldClipper) => false;
}
