import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);
  static const String _prefsKey = 'theme_mode';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefsKey) ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDarkMode(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, isDark);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2A60E4),
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      useMaterial3: true,
      fontFamily: 'Inter', // Si tuvieras una, esto ayudaría. Por ahora default.
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF111318),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2A60E4),
        brightness: Brightness.dark,
        surface: const Color(0xFF1A1D26),
      ),
      useMaterial3: true,
      fontFamily: 'Inter',
    );
  }
}

extension AppThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get bgScaffold =>
      isDarkMode ? const Color(0xFF111318) : const Color(0xFFF8F9FB);
  Color get cardColor => isDarkMode ? const Color(0xFF1A1D26) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF1A1D26);
  Color get subtitleColor => isDarkMode ? Colors.grey[400]! : Colors.grey[500]!;
  Color get borderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.grey.withValues(alpha: 0.1);
  Color get shadowColor =>
      isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

  // Specific dynamic colors
  Color get inputBgColor =>
      isDarkMode ? const Color(0xFF232733) : const Color(0xFFF1F3F5);
  Color get appBarColor => isDarkMode ? const Color(0xFF111318) : Colors.white;
}
