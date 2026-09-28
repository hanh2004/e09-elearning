// GIAO DIỆN DÙNG CHUNG: Dữ liệu cũ dùng ảnh thương hiệu cho tới khi admin thêm ảnh bìa.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';

/// Dữ liệu cũ dùng ảnh thương hiệu cho tới khi admin thêm ảnh bìa.
class CourseCover extends StatelessWidget {
  const CourseCover({super.key, this.url = '', this.width, this.height = 90});
  final String url;
  final double? width;
  final double height;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      width: width,
      height: height,
      color: const Color(0xFFF6E9E7),
      padding: const EdgeInsets.all(12),
      child: Image.asset(AppTheme.appLogo, fit: BoxFit.contain),
    );
    if (url.startsWith('icon:')) {
      const icons = {
        'book': Icons.menu_book,
        'math': Icons.calculate,
        'computer': Icons.computer,
        'science': Icons.science,
        'language': Icons.translate,
        'safety': Icons.shield,
      };
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF6E9E7),
        child: Icon(
          icons[url.substring(5)] ?? Icons.school,
          color: const Color(0xFFC51F2B),
          size: height * .5,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty
          ? fallback()
          : Image.network(
              url,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }
}
