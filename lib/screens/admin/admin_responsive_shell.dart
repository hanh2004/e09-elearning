import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../widgets/brand_logo.dart';
import 'admin_account_screen.dart';
import 'admin_classes_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_notifications_screen.dart';

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
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) return child;
    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height < 850
                  ? 850
                  : MediaQuery.sizeOf(context).height,
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                backgroundColor: AppTheme.navy,
                indicatorColor: AppTheme.red,
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedIconTheme: const IconThemeData(color: Colors.white70),
                selectedLabelTextStyle: const TextStyle(
                  fontFamily: 'Arial',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: const TextStyle(
                  fontFamily: 'Arial',
                  color: Colors.white70,
                ),
                extended: true,
                minExtendedWidth: 220,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 32),
                  child: Column(
                    children: [
                      const BrandLogo(admin: true),
                      const SizedBox(height: 16),
                      const Text(
                        'HỌC TẬP SỐ\nQUẢN TRỊ E09',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Trang chủ'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: Text('Bài thi'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: Text('Báo cáo'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Cài đặt'),
                  ),
                ],
                trailing: SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      const Divider(
                        color: Colors.white24,
                        indent: 16,
                        endIndent: 16,
                      ),
                      for (final entry in <(String, IconData, Widget)>[
                        (
                          'Tài khoản',
                          Icons.people_outline,
                          const AdminAccountScreen(),
                        ),
                        (
                          'Đơn vị học viên',
                          Icons.groups_outlined,
                          const AdminClassesScreen(),
                        ),
                        (
                          'Khóa học',
                          Icons.menu_book_outlined,
                          const AdminCoursesScreen(),
                        ),
                        (
                          'Thông báo',
                          Icons.notifications_outlined,
                          const AdminNotificationsScreen(),
                        ),
                      ])
                        ListTile(
                          leading: Icon(entry.$2, color: Colors.white70),
                          title: Text(
                            entry.$1,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => entry.$3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
