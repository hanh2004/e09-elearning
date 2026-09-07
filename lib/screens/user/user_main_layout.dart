import 'package:flutter/material.dart';

import 'user_home_screen.dart';
import 'user_profile_screen.dart';
import '../../models/user_arguments.dart';

class UserMainLayout extends StatefulWidget {
  final UserArguments args;

  const UserMainLayout({super.key, required this.args});

  @override
  State<UserMainLayout> createState() => _UserMainLayoutState();
}

class _UserMainLayoutState extends State<UserMainLayout> {
  int _selectedIndex = 0;
  final Color primaryColor = const Color(0xFF6B0000);

  // Danh sách màn hình cho thanh Bottom Navigation
  @override
  Widget build(BuildContext context) {
    final pages = [
      UserHomeScreen(args: widget.args),
      UserProfileScreen(args: widget.args),
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
                    child: Icon(
                      Icons.school_rounded,
                      size: 36,
                      color: primaryColor,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Trang chủ'),
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
