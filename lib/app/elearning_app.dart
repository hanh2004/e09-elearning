import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'app_portal.dart';

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
        theme: ThemeData(
          fontFamily: 'Arial',
          scaffoldBackgroundColor: const Color(0xFFF6F7FB),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B0000),
            primary: const Color(0xFF6B0000),
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3E5EA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE3E5EA)),
            ),
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
