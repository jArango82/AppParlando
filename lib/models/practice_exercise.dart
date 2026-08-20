import 'package:flutter/material.dart';

enum PracticeCategory {
  grammar,
  writing,
  vocabulary;

  String get label {
    switch (this) {
      case PracticeCategory.grammar:
        return 'Gramática';
      case PracticeCategory.writing:
        return 'Escritura';
      case PracticeCategory.vocabulary:
        return 'Vocabulario';
    }
  }

  String get id {
    switch (this) {
      case PracticeCategory.grammar:
        return 'grammar';
      case PracticeCategory.writing:
        return 'writing';
      case PracticeCategory.vocabulary:
        return 'vocabulary';
    }
  }

  Color get color {
    switch (this) {
      case PracticeCategory.grammar:
        return const Color(0xFF2A60E4);
      case PracticeCategory.writing:
        return const Color(0xFFE67E22);
      case PracticeCategory.vocabulary:
        return const Color(0xFF8E44AD);
    }
  }

  IconData get icon {
    switch (this) {
      case PracticeCategory.grammar:
        return Icons.menu_book_rounded;
      case PracticeCategory.writing:
        return Icons.edit_rounded;
      case PracticeCategory.vocabulary:
        return Icons.quiz_rounded;
    }
  }

  static PracticeCategory? fromTitle(String title) {
    switch (title) {
      case 'Gramática':
        return PracticeCategory.grammar;
      case 'Escritura':
        return PracticeCategory.writing;
      case 'Vocabulario':
        return PracticeCategory.vocabulary;
      default:
        return null;
    }
  }
}

enum ExerciseType { multipleChoice, fillBlank, translate }

class PracticeExercise {
  final String id;
  final String level;
  final PracticeCategory category;
  final ExerciseType type;
  final String instruction;
  final String prompt;
  final List<String> options;
  final String answer;
  final String? explanation;

  const PracticeExercise({
    required this.id,
    required this.level,
    required this.category,
    required this.type,
    required this.instruction,
    required this.prompt,
    required this.options,
    required this.answer,
    this.explanation,
  });

  bool isCorrect(String userAnswer) {
    final a = _norm(userAnswer);
    final b = _norm(answer);
    return a == b;
  }

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
