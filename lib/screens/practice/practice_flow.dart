import 'package:flutter/material.dart';

import '../../models/practice_exercise.dart';
import '../../widgets/custom_loading_indicator.dart';
import 'practice_session_screen.dart';

/// Arranca una sesión de práctica con carga fullscreen breve.
Future<void> startPracticeFlow(
  BuildContext context, {
  required PracticeCategory category,
  required String level,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = category.color;
  final navigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: Material(
          color: isDark ? const Color(0xFF0F1117) : const Color(0xFF6BA4D8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BalloonCloudLoadingIndicator(
                size: MediaQuery.sizeOf(dialogContext).shortestSide * 0.38,
                expand: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(dialogContext).bottom + 36,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : const Color(0xFF4A90C8))
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Preparando práctica…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  await Future<void>.delayed(const Duration(milliseconds: 1400));

  if (!navigator.mounted) return;
  navigator.pop();

  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PracticeSessionScreen(
        category: category,
        level: level,
        accentColor: accent,
      ),
    ),
  );
}
