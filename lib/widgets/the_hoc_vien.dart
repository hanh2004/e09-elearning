// GIAO DIỆN DÙNG CHUNG: Thẻ nội dung nổi bật dùng chung trong App học viên.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

/// Thẻ nội dung nổi bật dùng chung trong App học viên.
/// Giữ màu nền, bóng đổ và bo góc đồng nhất giữa hồ sơ và lịch sử thi.
class LearnerCard extends StatelessWidget {
  const LearnerCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.accentColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: accentColor?.withValues(alpha: 0.28) ?? const Color(0xFFE8ECF3),
      ),
    ),
    child: padding == null ? child : Padding(padding: padding!, child: child),
  );
}
