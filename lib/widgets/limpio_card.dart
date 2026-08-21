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

  const LimpioCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deco = BoxDecoration(
      color: isDark ? const Color(0xFF1A1D28) : LimpioTokens.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : LimpioTokens.line,
      ),
      boxShadow: elevated && !isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
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
