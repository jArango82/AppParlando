class CourseConfig {
  // Configuración de partes para A1 (id 7)
  static final Map<String, dynamic> a1Parts = {
      'A1 Introductorio': {'ids': List.generate(22, (i) => i + 2), 'totalExercises': 107}, // 2-23
      'A1 parte 1': {'ids': List.generate(26, (i) => i + 25), 'totalExercises': 138}, // 25-50
      'A1 parte 2': {'ids': List.generate(25, (i) => i + 52), 'totalExercises': 106}, // 52-76
      'A1 parte 3': {'ids': List.generate(23, (i) => i + 78), 'totalExercises': 100}, // 78-100
      'A1 parte 4': {'ids': List.generate(23, (i) => i + 102), 'totalExercises': 110} // 102-124
  };

  // Configuración de partes para A2 (id 11)
  static final Map<String, dynamic> a2Parts = {
      'A2 Parte 1': {'ids': List.generate(28, (i) => i + 1), 'totalExercises': 132},
      'A2 Parte 2': {'ids': List.generate(22, (i) => i + 30), 'totalExercises': 131},
      'A2 Parte 3': {'ids': List.generate(26, (i) => i + 53), 'totalExercises': 154},
      'A2 Parte 4': {'ids': List.generate(23, (i) => i + 80), 'totalExercises': 135},
      'A2 Parte 5': {'ids': List.generate(23, (i) => i + 104), 'totalExercises': 137},
      'A2 Parte 6': {'ids': List.generate(19, (i) => i + 128), 'totalExercises': 136}
  };

  // Configuración de partes para B1 (id 12)
  static final Map<String, dynamic> b1Parts = {
      'B1 Parte 1': {'ids': List.generate(23, (i) => i + 1), 'totalExercises': 132},
      'B1 Parte 2': {'ids': List.generate(25, (i) => i + 25), 'totalExercises': 131},
      'B1 Parte 3': {'ids': List.generate(23, (i) => i + 51), 'totalExercises': 154},
      'B1 Parte 4': {'ids': List.generate(23, (i) => i + 75), 'totalExercises': 135},
      'B1 Parte 5': {'ids': List.generate(25, (i) => i + 99), 'totalExercises': 137},
      'B1 Parte 6': {'ids': List.generate(23, (i) => i + 125), 'totalExercises': 136}
  };

  // Configuración de partes para B2 (id 13)
  static final Map<String, dynamic> b2Parts = {
      'B2 Parte 1': {'ids': List.generate(26, (i) => i + 1), 'totalExercises': 132},
      'B2 Parte 2': {'ids': List.generate(26, (i) => i + 28), 'totalExercises': 131},
      'B2 Parte 3': {'ids': List.generate(26, (i) => i + 55), 'totalExercises': 154},
      'B2 Parte 4': {'ids': List.generate(24, (i) => i + 82), 'totalExercises': 135},
      'B2 Parte 5': {'ids': List.generate(24, (i) => i + 107), 'totalExercises': 137},
      'B2 Parte 6': {'ids': List.generate(28, (i) => i + 132), 'totalExercises': 136}
  };

  // Configuración de partes para Introduction KIDS (id 14)
  static final Map<String, dynamic> kidsParts = {
      'KIDS Parte 1': {'ids': List.generate(24, (i) => i)}, // 0-23
      'KIDS Parte 2': {'ids': List.generate(8, (i) => i + 26)}, // 26-33
      'KIDS Parte 3': {'ids': List.generate(22, (i) => i + 36)}, // 36-57
      'KIDS Parte 4': {'ids': List.generate(20, (i) => i + 60)}, // 60-79
      'KIDS Parte 5': {'ids': List.generate(23, (i) => i + 82)} // 82-104
  };

  static bool isKids(String shortname, {String fullname = ''}) =>
      '$shortname $fullname'.toUpperCase().contains('KIDS');

  static Map<String, dynamic> getPartsForCourse(String shortname, {String fullname = ''}) {
    final combined = '$shortname $fullname';
    if (isKids(shortname, fullname: fullname)) return kidsParts;
    if (combined.contains('A1')) return a1Parts;
    if (combined.contains('A2')) return a2Parts;
    if (combined.contains('B1')) return b1Parts;
    if (combined.contains('B2')) return b2Parts;
    return {};
  }
}

/// Diagnósticos: viven en el mismo curso del nivel; cada "Parte" es una sección Moodle.
class DiagnosticConfig {
  static const Map<String, DiagnosticLevelConfig> levels = {
    'A1': DiagnosticLevelConfig(
      courseId: 7,
      sectionIds: [51, 78, 103, 128],
    ),
    'A2': DiagnosticLevelConfig(
      courseId: 11,
      sectionIds: [29, 53, 81, 106, 131, 152],
    ),
    'B1': DiagnosticLevelConfig(
      courseId: 12,
      sectionIds: [24, 51, 76, 101, 128, 153],
    ),
    'B2': DiagnosticLevelConfig(
      courseId: 13,
      sectionIds: [27, 55, 83, 109, 135, 165],
    ),
    // En KIDS cada diagnóstico ocupa dos secciones.
    'KIDS': DiagnosticLevelConfig(
      courseId: 14,
      sectionIds: [24, 25, 34, 35, 58, 59, 80, 81],
      partGroups: [
        [24, 25],
        [34, 35],
        [58, 59],
        [80, 81],
      ],
    ),
  };

  static DiagnosticLevelConfig? forLevel(String level) => levels[level];

  static int? courseIdForLevel(String level) => levels[level]?.courseId;

  /// Curso legado de diagnósticos (ya no se usa).
  static const int legacyDiagnosticCourseId = 9;
}

class DiagnosticLevelConfig {
  final int courseId;
  final List<int> sectionIds;
  final List<List<int>>? partGroups;

  const DiagnosticLevelConfig({
    required this.courseId,
    required this.sectionIds,
    this.partGroups,
  });

  /// Secciones de cada parte de diagnóstico (una por parte si no hay grupos).
  List<List<int>> get parts =>
      partGroups ?? [for (final id in sectionIds) [id]];
}
