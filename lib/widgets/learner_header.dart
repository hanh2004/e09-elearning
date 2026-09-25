// GIAO DIỆN DÙNG CHUNG: Thanh đầu trang thống nhất trên điện thoại; tiêu đề dài được xuống hai dòng.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/material.dart';

import '../app/app_theme.dart';

/// Thanh đầu trang thống nhất trên điện thoại; tiêu đề dài được xuống hai dòng.
class LearnerHeader extends AppBar {
  LearnerHeader({
    super.key,
    required Widget title,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    super.automaticallyImplyLeading = true,
    super.actions,
  }) : super(
         title: DefaultTextStyle.merge(
           maxLines: 2,
           overflow: TextOverflow.ellipsis,
           child: title,
         ),
         toolbarHeight: 72,
         backgroundColor: backgroundColor ?? const Color(0xD9FFFFFF),
         foregroundColor:
             foregroundColor ??
             (backgroundColor == null ? AppTheme.navy : Colors.white),
         titleTextStyle: TextStyle(
           fontFamily: 'Arial',
           fontSize: 17,
           fontWeight: FontWeight.w700,
           color:
               foregroundColor ??
               (backgroundColor == null ? AppTheme.navy : Colors.white),
         ),
         centerTitle: true,
         surfaceTintColor: Colors.transparent,
         elevation: elevation ?? 0,
         scrolledUnderElevation: 0,
       );
}
