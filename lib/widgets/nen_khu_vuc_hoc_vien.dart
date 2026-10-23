import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';

/// Nền dùng chung cho các màn hình mobile của học viên.
/// Chỉ thay đổi trình bày; nội dung và thao tác của từng màn hình giữ nguyên.
class LearnerSurface extends StatelessWidget {
  const LearnerSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        AppTheme.learnerLightBackground,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
      ColoredBox(color: Colors.white.withValues(alpha: 0.48)),
      child,
    ],
  );
}
