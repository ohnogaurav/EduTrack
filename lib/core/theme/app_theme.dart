import 'package:flutter/material.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    primaryColor: const Color(0xFF2563EB),
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF2563EB),
      secondary: const Color(0xFF16A34A),
      error: const Color(0xFFDC2626),
      surface: Colors.white,
    ),
    cardColor: Colors.white,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF374151)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    primaryColor: const Color(0xFF3B82F6),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF3B82F6),
      secondary: const Color(0xFF22C55E),
      error: const Color(0xFFEF4444),
      surface: const Color(0xFF1E293B),
    ),
    cardColor: const Color(0xFF1E293B),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF1F5F9)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFCBD5F5)),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
