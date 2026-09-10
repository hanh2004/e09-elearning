import 'package:flutter/material.dart';

class AppTheme {
  static const red = Color(0xFFB51F24);
  static const navy = Color(0xFF192858);
  static const gold = Color(0xFFD7B558);
  static const background = Color(0xFFF5F7FA);
  static const appLogo = 'lib/assets/images/logo.png';
  static const webLogo = 'lib/assets/images/web_logo.png';
  static const logo = appLogo;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: red,
      primary: red,
      secondary: navy,
      surface: Colors.white,
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: navy,
      displayColor: navy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: navy,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: navy,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8ECF3)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE8ECF3)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE3E8F1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE3E8F1)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: red,
      linearTrackColor: Color(0xFFF5E2E3),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFF8E7E7),
    ),
  );
}
