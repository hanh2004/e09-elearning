// KHỞI TẠO / GIAO DIỆN: Màn hình học viên có kiểu riêng, độc lập với Admin.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import 'app_theme.dart';
import '../widgets/learner_surface.dart';

/// Màn hình học viên có kiểu riêng, độc lập với Admin.
class LearnerTheme {
  static ThemeData get light => AppTheme.light.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Arial'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppTheme.navy,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Arial',
        color: AppTheme.navy,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppTheme.red,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      titleTextStyle: TextStyle(
        fontFamily: 'Arial',
        color: AppTheme.navy,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Arial',
        color: Color(0xFF68758C),
        fontSize: 13,
        height: 1.5,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFF8E7E7),
      side: const BorderSide(color: Color(0xFFE4E8F0)),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontFamily: 'Arial',
        color: AppTheme.navy,
        fontSize: 12,
      ),
    ),
  );
}

/// Giữ chiều rộng nội dung dễ đọc và khoảng an toàn trên mọi trang học viên.
class LearnerViewport extends StatelessWidget {
  const LearnerViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LearnerSurface(
    child: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      ),
    ),
  );
}
