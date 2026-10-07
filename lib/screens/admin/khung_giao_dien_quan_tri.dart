// Khung điều hướng responsive của web admin: sidebar desktop, thanh dưới mobile và mở trang quản trị.
// Tiêu đề và nội dung từng trang nằm trong các màn hình quản trị tương ứng.
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../widgets/bieu_trung_thuong_hieu.dart';
import 'quan_ly_tai_khoan.dart';
import 'quan_ly_khoa_hoc.dart';
import 'quan_ly_tin_tuc.dart';
import 'quan_ly_thong_bao.dart';
import 'trang_chu_quan_tri.dart';
import 'bao_cao_hub.dart';
import 'cai_dat_quan_tri.dart';

const _menuKhoaHoc = {
  'Khóa học không kiểm tra',
  'Khóa học có kiểm tra',
  'Khóa học kết thúc',
};

Widget adminPrimaryPage(int viTri) => switch (viTri) {
  0 => const AdminHomeScreen(),
  1 => const AdminCoursesScreen(initialCourseModeFilter: 'study_only'),
  2 => const AdminReportsHubScreen(),
  3 => const AdminSettingsScreen(),
  _ => const AdminHomeScreen(),
};

void pushAdminPrimary(BuildContext context, int viTri) =>
    Navigator.pushReplacement(context, adminTabRoute(adminPrimaryPage(viTri)));

Widget? adminMobileNavigationBar(
  BuildContext context, {
  required int selectedIndex,
  required ValueChanged<int> onSelected,
}) {
  if (AdminResponsiveShell.isDesktop(context)) return null;
  return BottomNavigationBar(
    currentIndex: selectedIndex,
    onTap: onSelected,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppTheme.red,
    unselectedItemColor: Colors.grey,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
      BottomNavigationBarItem(
        icon: Icon(Icons.assignment),
        label: 'Quản lý khóa học',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Báo cáo'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
    ],
  );
}

PageRoute<void> adminTabRoute(Widget page) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
);

class AdminResponsiveShell extends StatelessWidget {
  const AdminResponsiveShell({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    this.activeExtra,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;
  final String? activeExtra;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) return child;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _thanhBen(context, wide),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _thanhBen(BuildContext context, bool wide) {
    return SizedBox(
      width: wide ? 264 : 72,
      height: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2D5D), Color(0xFF14244D)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _thuongHieu(wide),
                  _muc(
                    'Trang chủ',
                    Icons.home_outlined,
                    wide,
                    activeExtra == null && selectedIndex == 0,
                    () => onSelected(0),
                  ),
                  for (final lienKet in _cacLienKet())
                    _lienKet(context, lienKet, wide),
                  _muc(
                    'Báo cáo',
                    Icons.bar_chart_outlined,
                    wide,
                    selectedIndex == 2,
                    () => onSelected(2),
                  ),
                  _muc(
                    'Cài đặt',
                    Icons.settings_outlined,
                    wide,
                    selectedIndex == 3,
                    () => onSelected(3),
                  ),
                  _lienKet(context, (
                    'Thông báo',
                    Icons.notifications_outlined,
                    const AdminNotificationsScreen(),
                    false,
                  ), wide),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thuongHieu(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(12, 12, 12, wide ? 20 : 10),
    child: Column(
      children: [
        BrandLogo(admin: true, height: wide ? 66 : 40),
        if (wide) ...[
          const SizedBox(height: 14),
          const Text(
            'HỌC TẬP SỐ\nQUẢN TRỊ E09',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
        ],
      ],
    ),
  );

  List<(String, IconData, Widget, bool)> _cacLienKet() => [
    ('Tin tức', Icons.newspaper_outlined, const AdminNewsScreen(), false),
    ('Tài khoản', Icons.people_outline, const AdminAccountScreen(), false),
    (
      'Quản lý khóa học',
      Icons.menu_book_outlined,
      const AdminCoursesScreen(initialCourseModeFilter: 'study_only'),
      false,
    ),
    if (_menuKhoaHoc.contains(activeExtra)) ...[
      (
        'Khóa học không kiểm tra',
        Icons.library_books_outlined,
        const AdminCoursesScreen(initialCourseModeFilter: 'study_only'),
        true,
      ),
      (
        'Khóa học có kiểm tra',
        Icons.assignment_outlined,
        const AdminCoursesScreen(initialCourseModeFilter: 'study_exam'),
        true,
      ),
      (
        'Khóa học kết thúc',
        Icons.lock_clock_outlined,
        const AdminCoursesScreen(ended: true),
        true,
      ),
    ],
  ];

  Widget _lienKet(
    BuildContext context,
    (String, IconData, Widget, bool) lienKet,
    bool wide,
  ) => _muc(
    lienKet.$1,
    lienKet.$2,
    wide,
    activeExtra == lienKet.$1,
    () => Navigator.pushReplacement(context, adminTabRoute(lienKet.$3)),
    child: lienKet.$4,
  );

  Widget _muc(
    String nhan,
    IconData bieuTuong,
    bool wide,
    bool daChon,
    VoidCallback? onTap, {
    bool child = false,
  }) {
    final mau = daChon ? AppTheme.red : Colors.transparent;
    if (!wide) {
      return Padding(
        padding: EdgeInsets.fromLTRB(child ? 20 : 8, 3, 8, 3),
        child: IconButton(
          tooltip: nhan,
          style: IconButton.styleFrom(
            backgroundColor: mau,
            foregroundColor: Colors.white,
          ),
          icon: Icon(bieuTuong),
          onPressed: onTap,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: child ? 20 : 8, right: 8, bottom: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: daChon ? null : mau,
              gradient: daChon
                  ? const LinearGradient(
                      colors: [Color(0xFFBE2028), Color(0xFFA91821)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (daChon)
                  Container(
                    width: 4,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(daChon ? 12 : 14, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(
                          bieuTuong,
                          color: daChon ? Colors.white : Colors.white70,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nhan,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: child ? 12 : 14,
                              fontWeight: daChon
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
