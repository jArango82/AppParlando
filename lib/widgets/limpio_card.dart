import 'package:flutter/material.dart';

/// Tokens visuales Parlando limpio (rama rediseño).
abstract final class LimpioTokens {
  static const brand = Color(0xFF2A60E4);
  static const brandSoft = Color(0xFFE8F0FE);
  static const scaffold = Color(0xFFF5F7FA);
  static const card = Colors.white;
  static const ink = Color(0xFF1A1D26);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const success = Color(0xFF1FAB5E);
  static const warning = Color(0xFFE67E22);
  static const purple = Color(0xFF8E44AD);
  static const danger = Color(0xFFE74C3C);

  /// Variantes dark
  static const darkScaffold = Color(0xFF0B0E14);
  static const darkCard = Color(0xFF151922);
  static const darkElevated = Color(0xFF1C2230);
  static const darkInk = Color(0xFFF0F2F5);
  static const darkMuted = Color(0xFF9AA3B2);
  static const darkLine = Color(0xFF2A3140);
  static const brandDark = Color(0xFF5B8DEF);

  static BoxDecoration cardDecoration({bool elevated = true}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      );
}

class LimpioCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? color;

  const LimpioCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deco = BoxDecoration(
      color: color ?? (isDark ? LimpioTokens.darkCard : LimpioTokens.card),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark ? LimpioTokens.darkLine : LimpioTokens.line,
      ),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                blurRadius: isDark ? 18 : 14,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    );

    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: deco,
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }
}
