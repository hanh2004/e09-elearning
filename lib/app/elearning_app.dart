import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'app_portal.dart';
import 'app_theme.dart';

class ElearningApp extends StatelessWidget {
  const ElearningApp({
    super.key,
    required this.portal,
    required this.homeBuilder,
  });

  final AppPortal portal;
  final Widget Function(Map<String, dynamic>) homeBuilder;

  @override
  Widget build(BuildContext context) {
    return PortalScope(
      portal: portal,
      homeBuilder: homeBuilder,
      child: MaterialApp(
        title: portal.title,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );
  }
}
