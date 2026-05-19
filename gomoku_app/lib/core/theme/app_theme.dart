import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFE91E63);
  static const Color secondaryColor = Color(0xFF9C27B0);
  static const Color boardBackground = Color(0xFFDEB887);
  static const Color boardLine = Color(0xFF8B4513);
  static const Color blackStone = Color(0xFF1A1A1A);
  static const Color whiteStone = Color(0xFFF5F5F5);
  static const Color onlineGreen = Color(0xFF4CAF50);
  static const Color offlineGray = Color(0xFF9E9E9E);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
