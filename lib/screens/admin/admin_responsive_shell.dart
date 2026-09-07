import 'package:flutter/material.dart';

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
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            backgroundColor: const Color(0xFF6B0000),
            indicatorColor: Colors.white.withValues(alpha: 0.18),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            extended: true,
            minExtendedWidth: 220,
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(12, 24, 12, 32),
              child: Text(
                'E-LEARNING\nADMIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                ),
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
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
