// GIAO DIỆN DÙNG CHUNG: Hiển thị lỗi tải hoặc thao tác với hướng khắc phục.

import 'package:flutter/material.dart';

import '../services/thong_bao_loi_ung_dung.dart';

class AppErrorNotice extends StatelessWidget {
  const AppErrorNotice({
    super.key,
    required this.error,
    required this.feature,
    this.fallbackAction,
    this.padding = EdgeInsets.zero,
    this.centered = true,
    this.style,
  });

  final Object error;
  final String feature;
  final String? fallbackAction;
  final EdgeInsetsGeometry padding;
  final bool centered;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final notice = Padding(
      padding: padding,
      child: Text(
        AppErrorMessage.from(
          error,
          feature: feature,
          fallbackAction: fallbackAction,
        ),
        textAlign: centered ? TextAlign.center : null,
        style: style,
      ),
    );
    return centered ? Center(child: notice) : notice;
  }
}
