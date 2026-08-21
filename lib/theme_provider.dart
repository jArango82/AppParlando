import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDarkMode(bool value) async {
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2A60E4),
          surface: Colors.white,
        ),
        useMaterial3: true,
      );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2A60E4),
          surface: Color(0xFF1A1D28),
        ),
        useMaterial3: true,
      );
}

extension AppThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  bool get isWideScreen => MediaQuery.of(this).size.width >= 650;

  Color get bgScaffold =>
      isDarkMode ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA);

  Color get cardColor =>
      isDarkMode ? const Color(0xFF1A1D28) : Colors.white;

  Color get textColor =>
      isDarkMode ? const Color(0xFFE8EAED) : const Color(0xFF1A1D26);

  Color get subtitleColor =>
      isDarkMode ? const Color(0xFF9AA0A6) : const Color(0xFF6B7280);

  Color get borderColor =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE5E7EB);

  Color get shadowColor =>
      isDarkMode
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.05);
}
