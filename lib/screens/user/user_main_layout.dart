import 'user_dashboard_screen.dart';
import '../../app/app_theme.dart';
import 'secure_exam_screen.dart';
import 'user_courses_screen.dart';
import 'user_notifications_screen.dart';

import 'package:flutter/material.dart';

import 'user_home_screen.dart';
import 'user_profile_screen.dart';
import '../../models/user_arguments.dart';
import '../../services/learning_service.dart';
import '../../services/secure_exam_service.dart';

class UserMainLayout extends StatefulWidget {
  final UserArguments args;

  const UserMainLayout({
    super.key,
    required this.args,
    this.learningService,
    this.examService,
  });
  final LearningService? learningService;
  final SecureExamService? examService;

  @override
  State<UserMainLayout> createState() => _UserMainLayoutState();
}

class _UserMainLayoutState extends State<UserMainLayout> {
  int _selectedIndex = 0;
  final Color primaryColor = const Color(0xFFB51F24);

  // Danh sách màn hình cho thanh Bottom Navigation
  @override
  Widget build(BuildContext context) {
    final pages = [
      UserDashboardScreen(
        args: widget.args,
        service: widget.learningService,
        onSelect: (index) => setState(() => _selectedIndex = index),
      ),
      UserCoursesScreen(
        uid: widget.args.userId,
        service: widget.learningService,
      ),
      const bool.fromEnvironment('USE_SECURE_BACKEND', defaultValue: true)
          ? SecureExamHomeScreen(service: widget.examService)
          : UserHomeScreen(args: widget.args),
      UserNotificationsScreen(
        uid: widget.args.userId,
        service: widget.learningService,
      ),
      UserProfileScreen(args: widget.args, service: widget.learningService),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Scaffold(
          body: Row(
            children: [
              if (isDesktop)
                NavigationRail(
                  extended: constraints.maxWidth >= 1180,
                  backgroundColor: Colors.white,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Image.asset(AppTheme.logo, width: 56, height: 56),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Trang chủ'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book),
                      label: Text('Khóa học'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      label: Text('Kiểm tra'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.notifications_outlined),
                      label: Text('Thông báo'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Cá nhân'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: pages),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: primaryColor,
                  unselectedItemColor: Colors.grey,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'Trang chủ',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.menu_book),
                      label: 'Khóa học',
                    ),
                    BottomNavigationBarItem(
                      icon: CircleAvatar(
                        backgroundColor: AppTheme.red,
                        child: Icon(
                          Icons.assignment_outlined,
                          color: Colors.white,
                        ),
                      ),
                      label: 'Kiểm tra',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.notifications_outlined),
                      label: 'Thông báo',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person),
                      label: 'Cá nhân',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
