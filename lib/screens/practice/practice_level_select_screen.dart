import 'package:flutter/material.dart';

import '../../models/practice_exercise.dart';
import '../../theme_provider.dart';
import 'practice_flow.dart';

/// Pantalla para que el estudiante elija el nivel (A1–B2) de una categoría.
class PracticeLevelSelectScreen extends StatelessWidget {
  final PracticeCategory category;
  final String? suggestedLevel;

  const PracticeLevelSelectScreen({
    super.key,
    required this.category,
    this.suggestedLevel,
  });

  static const _levels = [
    (
      'A1',
      'Principiante',
      'Muy fácil · saludos, to be, vocabulario básico',
      Color(0xFF2A60E4),
    ),
    (
      'A2',
      'Elemental',
      'Fácil · pasado simple, comparativos, rutinas',
      Color(0xFF1FAB5E),
    ),
    (
      'B1',
      'Intermedio',
      'Medio · perfectos, condicionales, pasiva',
      Color(0xFFE67E22),
    ),
    (
      'B2',
      'Intermedio alto',
      'Retador · estructuras avanzadas y vocabulario preciso',
      Color(0xFF8E44AD),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = category.color;

    return Scaffold(
      backgroundColor: context.bgScaffold,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        title: Text(
          category.label,
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: context.textColor),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(category.icon, color: accent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elige tu nivel',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A1 es el más fácil. Puedes practicar cualquier nivel.',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.subtitleColor,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ..._levels.map((lvl) {
                  final code = lvl.$1;
                  final title = lvl.$2;
                  final subtitle = lvl.$3;
                  final color = lvl.$4;
                  final isSuggested = suggestedLevel == code;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          startPracticeFlow(
                            context,
                            category: category,
                            level: code,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSuggested
                                  ? color
                                  : context.borderColor,
                              width: isSuggested ? 2 : 1,
                            ),
                            boxShadow: [
                              if (!context.isDarkMode)
                                BoxShadow(
                                  color: context.shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  code,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: context.textColor,
                                          ),
                                        ),
                                        if (isSuggested) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Tu curso',
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.subtitleColor,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: context.subtitleColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
