// GIAO DIỆN DÙNG CHUNG: Tự xuống dòng các thẻ tổng hợp để chữ lớn không bị ép vào ba cột.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

/// Tự xuống dòng các thẻ tổng hợp để chữ lớn không bị ép vào ba cột.
class LearnerMetrics extends StatelessWidget {
  const LearnerMetrics({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth < 300 || scaled > 1.4
          ? 1
          : children.length.clamp(1, 3);
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final child in children)
            SizedBox(
              width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
              child: child,
            ),
        ],
      );
    },
  );
}
