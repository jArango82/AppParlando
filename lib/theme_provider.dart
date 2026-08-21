import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);

  static const _brand = Color(0xFF2A60E4);

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
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(
          primary: _brand,
          onPrimary: Colors.white,
          secondary: Color(0xFF1FAB5E),
          surface: Colors.white,
          onSurface: Color(0xFF1A1D26),
          error: Color(0xFFE74C3C),
          outline: Color(0xFFE5E7EB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FA),
          foregroundColor: Color(0xFF1A1D26),
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E7EB),
          thickness: 1,
          space: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _brand;
            return const Color(0xFF9CA3AF);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _brand.withValues(alpha: 0.35);
            }
            return const Color(0xFFE5E7EB);
          }),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1D26),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5B8DEF),
          onPrimary: Colors.white,
          secondary: Color(0xFF34D399),
          surface: Color(0xFF151922),
          onSurface: Color(0xFFF0F2F5),
          error: Color(0xFFF87171),
          outline: Color(0xFF2A3140),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0E14),
          foregroundColor: Color(0xFFF0F2F5),
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF151922),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF2A3140)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A3140),
          thickness: 1,
          space: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF5B8DEF);
            }
            return const Color(0xFF6B7280);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF5B8DEF).withValues(alpha: 0.4);
            }
            return const Color(0xFF2A3140);
          }),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF151922),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF151922),
          modalBackgroundColor: Color(0xFF151922),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E2433),
          contentTextStyle: const TextStyle(color: Color(0xFFF0F2F5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}

extension AppThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  bool get isWideScreen => MediaQuery.of(this).size.width >= 650;

  /// Azul Parlando adaptado al tema (más claro en dark para contraste).
  Color get brandColor =>
      isDarkMode ? const Color(0xFF5B8DEF) : const Color(0xFF2A60E4);

  Color get brandSoft => isDarkMode
      ? const Color(0xFF5B8DEF).withValues(alpha: 0.16)
      : const Color(0xFFE8F0FE);

  Color get bgScaffold =>
      isDarkMode ? const Color(0xFF0B0E14) : const Color(0xFFF5F7FA);

  Color get cardColor =>
      isDarkMode ? const Color(0xFF151922) : Colors.white;

  Color get elevatedSurface =>
      isDarkMode ? const Color(0xFF1C2230) : Colors.white;

  Color get textColor =>
      isDarkMode ? const Color(0xFFF0F2F5) : const Color(0xFF1A1D26);

  Color get subtitleColor =>
      isDarkMode ? const Color(0xFF9AA3B2) : const Color(0xFF6B7280);

  Color get borderColor =>
      isDarkMode ? const Color(0xFF2A3140) : const Color(0xFFE5E7EB);

  Color get shadowColor => isDarkMode
      ? Colors.black.withValues(alpha: 0.45)
      : Colors.black.withValues(alpha: 0.05);

  Color get dangerColor =>
      isDarkMode ? const Color(0xFFF87171) : const Color(0xFFE74C3C);

  Color get successColor =>
      isDarkMode ? const Color(0xFF34D399) : const Color(0xFF1FAB5E);
}
