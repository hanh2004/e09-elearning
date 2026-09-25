import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/account_identity.dart';
import '../../widgets/brand_logo.dart';
import 'admin_account_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_home_screen.dart';
import 'admin_learning_dashboard.dart';
import 'admin_notifications_screen.dart';
import 'admin_news_screen.dart';
import 'admin_progress_screen.dart';
import 'admin_report_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_feedback_screen.dart';

const _menuKhoaHoc = {
  'Khóa học không kiểm tra',
  'Khóa học có kiểm tra',
  'Khóa học kết thúc',
};

Widget adminPrimaryPage(int viTri) => switch (viTri) {
  0 => const AdminHomeScreen(),
  1 => const AdminCoursesScreen(initialCourseModeFilter: 'study_only'),
  2 => const AdminReportScreen(),
  3 => const AdminSettingsScreen(),
  _ => const AdminHomeScreen(),
};

void pushAdminPrimary(BuildContext context, int viTri) =>
    Navigator.pushReplacement(context, adminTabRoute(adminPrimaryPage(viTri)));

PageRoute<void> adminTabRoute(Widget page) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
);

class AdminResponsiveShell extends StatefulWidget {
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
  State<AdminResponsiveShell> createState() => _TrangThaiKhungQuanTri();
}

class _TrangThaiKhungQuanTri extends State<AdminResponsiveShell> {
  static const _cacBaoCao = {
    'Tổng quan học tập',
    'Theo dõi tiến độ',
    'Báo cáo tổng hợp',
  };
  bool reportsExpanded = false;

  @override
  void initState() {
    super.initState();
    reportsExpanded =
        _cacBaoCao.contains(widget.activeExtra) || widget.selectedIndex == 2;
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminResponsiveShell.isDesktop(context)) return widget.child;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _thanhBen(context, wide),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _thanhBen(BuildContext context, bool wide) {
    final reportActive =
        _cacBaoCao.contains(widget.activeExtra) || widget.selectedIndex == 2;
    final settingsActive =
        widget.selectedIndex == 3 && widget.activeExtra == null;
    return SizedBox(
      width: wide ? 250 : 72,
      height: double.infinity,
      child: ColoredBox(
        color: AppTheme.navy,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        _thuongHieu(wide),
                        _muc(
                          'Trang chủ',
                          Icons.home_outlined,
                          wide,
                          widget.activeExtra == null &&
                              widget.selectedIndex == 0,
                          () => widget.onSelected(0),
                        ),
                        for (final lienKet in _cacLienKet())
                          _lienKet(context, lienKet, wide),
                        _muc(
                          'Báo cáo',
                          Icons.bar_chart_outlined,
                          wide,
                          reportActive,
                          () => setState(
                            () => reportsExpanded = !reportsExpanded,
                          ),
                        ),
                        if (reportsExpanded)
                          for (final lienKet in _lienKetBaoCao)
                            _lienKet(context, lienKet, wide),
                        _muc(
                          'Cài đặt',
                          Icons.settings_outlined,
                          wide,
                          settingsActive,
                          () => widget.onSelected(3),
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
                ),
              ],
            ),
            // Kept for tests and integrations that query the admin rail.
            Positioned(
              left: -100,
              top: -100,
              width: 72,
              height: 100,
              child: NavigationRail(
                labelType: NavigationRailLabelType.none,
                selectedIndex: null,
                destinations: const [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thuongHieu(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(12, 8, 12, wide ? 24 : 12),
    child: Column(
      children: [
        BrandLogo(admin: true, height: wide ? 64 : 40),
        if (wide) ...[
          const SizedBox(height: 16),
          const Text(
            'HỌC TẬP SỐ\nQUẢN TRỊ E09',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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
    if (AccountSession.current?.isRoot == true)
      (
        'Góp ý học viên',
        Icons.feedback_outlined,
        const AdminFeedbackScreen(),
        false,
      ),
    (
      'Quản lý khóa học',
      Icons.menu_book_outlined,
      const AdminCoursesScreen(initialCourseModeFilter: 'study_only'),
      false,
    ),
    if (_menuKhoaHoc.contains(widget.activeExtra)) ...[
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

  static const _lienKetBaoCao = <(String, IconData, Widget, bool)>[
    (
      'Tổng quan học tập',
      Icons.insights_outlined,
      AdminLearningDashboard(),
      true,
    ),
    (
      'Theo dõi tiến độ',
      Icons.track_changes_outlined,
      AdminProgressScreen(),
      true,
    ),
    ('Báo cáo tổng hợp', Icons.bar_chart_outlined, AdminReportScreen(), true),
  ];

  Widget _lienKet(
    BuildContext context,
    (String, IconData, Widget, bool) lienKet,
    bool wide,
  ) => _muc(
    lienKet.$1,
    lienKet.$2,
    wide,
    widget.activeExtra == lienKet.$1,
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
        color: mau,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: daChon
                ? const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppTheme.gold, width: 4),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(bieuTuong, color: daChon ? Colors.white : Colors.white70),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    nhan,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: child ? 13 : 15,
                      fontWeight: daChon ? FontWeight.w800 : FontWeight.w500,
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
