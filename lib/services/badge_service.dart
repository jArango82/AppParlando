import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'course_service.dart';
import '../config/course_config.dart';

/// Servicio centralizado para gestionar las insignias (badges) del estudiante.
///
/// Una insignia se otorga cuando el estudiante completa AMBOS requisitos:
/// 1. La sección correspondiente en el curso principal
/// 2. La sección correspondiente en los diagnósticos
///
/// NOTA: "A1 Introductorio" (sección 0 de diagnósticos / parte 0 del curso)
/// NO cuenta para ganar insignias.
class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  static const String _keyEarnedBadges = 'earned_badges';
  static const String _keyShownBadges = 'shown_badges';

  // ── Mapeo de insignias ──────────────────────────────────────────────
  // Cada badge requiere completar una "parte" del curso Y una sección de diagnóstico.
  //
  // badgeId: identificador único de la insignia
  // assetPath: ruta al archivo .webp de la insignia
  // level: nivel (A1, A2, B1, B2)
  // coursePartIndex: índice de la parte del curso (0-based, excluyendo Introductorio)
  //                  Para A1: 0=Introductorio(NO), 1=Parte 1, 2=Parte 2, 3=Parte 3, 4=Parte 4
  // diagnosticSectionNum: número de sección en el curso de diagnóstico (Moodle section number)
  //
  static final List<BadgeDefinition> allBadges = [
    // ── A1 ──
    BadgeDefinition(
      id: 'a1_1',
      assetPath: 'assets/badges/A1/1.webp',
      level: 'A1',
      coursePartName: 'A1 parte 1',
      diagnosticSectionNum: 1,
      title: '¡Sección Completada!',
      subtitle: 'A1 - Parte 1',
    ),
    BadgeDefinition(
      id: 'a1_2',
      assetPath: 'assets/badges/A1/2.webp',
      level: 'A1',
      coursePartName: 'A1 parte 2',
      diagnosticSectionNum: 2,
      title: '¡Sección Completada!',
      subtitle: 'A1 - Parte 2',
    ),
    BadgeDefinition(
      id: 'a1_3',
      assetPath: 'assets/badges/A1/3.webp',
      level: 'A1',
      coursePartName: 'A1 parte 3',
      diagnosticSectionNum: 3,
      title: '¡Sección Completada!',
      subtitle: 'A1 - Parte 3',
    ),
    BadgeDefinition(
      id: 'a1_4',
      assetPath: 'assets/badges/A1/4.webp',
      level: 'A1',
      coursePartName: 'A1 parte 4',
      diagnosticSectionNum: -1, // Solo requiere completar el curso
      title: '¡Nivel A1 Completado!',
      subtitle: 'A1 - Parte 4',
    ),

    // ── A2 ──
    BadgeDefinition(
      id: 'a2_1',
      assetPath: 'assets/badges/A2/1.webp',
      level: 'A2',
      coursePartName: 'A2 Parte 1',
      diagnosticSectionNum: 4,
      title: '¡Sección Completada!',
      subtitle: 'A2 - Parte 1',
    ),
    BadgeDefinition(
      id: 'a2_2',
      assetPath: 'assets/badges/A2/2.webp',
      level: 'A2',
      coursePartName: 'A2 Parte 2',
      diagnosticSectionNum: 5,
      title: '¡Sección Completada!',
      subtitle: 'A2 - Parte 2',
    ),
    BadgeDefinition(
      id: 'a2_3',
      assetPath: 'assets/badges/A2/3.webp',
      level: 'A2',
      coursePartName: 'A2 Parte 3',
      diagnosticSectionNum: 6,
      title: '¡Sección Completada!',
      subtitle: 'A2 - Parte 3',
    ),
    BadgeDefinition(
      id: 'a2_4',
      assetPath: 'assets/badges/A2/4.webp',
      level: 'A2',
      coursePartName: 'A2 Parte 4',
      diagnosticSectionNum: 7,
      title: '¡Sección Completada!',
      subtitle: 'A2 - Parte 4',
    ),
    BadgeDefinition(
      id: 'a2_5',
      assetPath: 'assets/badges/A2/5.webp',
      level: 'A2',
      coursePartName: 'A2 Parte 5',
      diagnosticSectionNum: 8,
      title: '¡Sección Completada!',
      subtitle: 'A2 - Parte 5',
    ),
    BadgeDefinition(
      id: 'a2_6',
      assetPath: 'assets/badges/A2/6.webp',
      level: 'A2',
      coursePartName: 'A2 Parte 6',
      diagnosticSectionNum: 9, 
      title: '¡Nivel A2 Completado!',
      subtitle: 'A2 - Parte 6',
    ),

    // ── B1 ──
    BadgeDefinition(
      id: 'b1_1',
      assetPath: 'assets/badges/B1/1.webp',
      level: 'B1',
      coursePartName: 'B1 Parte 1',
      diagnosticSectionNum: 10,
      title: '¡Sección Completada!',
      subtitle: 'B1 - Parte 1',
    ),
    BadgeDefinition(
      id: 'b1_2',
      assetPath: 'assets/badges/B1/2.webp',
      level: 'B1',
      coursePartName: 'B1 Parte 2',
      diagnosticSectionNum: 11,
      title: '¡Sección Completada!',
      subtitle: 'B1 - Parte 2',
    ),
    BadgeDefinition(
      id: 'b1_3',
      assetPath: 'assets/badges/B1/3.webp',
      level: 'B1',
      coursePartName: 'B1 Parte 3',
      diagnosticSectionNum: 12,
      title: '¡Sección Completada!',
      subtitle: 'B1 - Parte 3',
    ),
    BadgeDefinition(
      id: 'b1_4',
      assetPath: 'assets/badges/B1/4.webp',
      level: 'B1',
      coursePartName: 'B1 Parte 4',
      diagnosticSectionNum: 13,
      title: '¡Sección Completada!',
      subtitle: 'B1 - Parte 4',
    ),
    BadgeDefinition(
      id: 'b1_5',
      assetPath: 'assets/badges/B1/5.webp',
      level: 'B1',
      coursePartName: 'B1 Parte 5',
      diagnosticSectionNum: 14,
      title: '¡Sección Completada!',
      subtitle: 'B1 - Parte 5',
    ),
    BadgeDefinition(
      id: 'b1_6',
      assetPath: 'assets/badges/B1/6.webp',
      level: 'B1',
      coursePartName: 'B1 Parte 6',
      diagnosticSectionNum: 15,
      title: '¡Nivel B1 Completado!',
      subtitle: 'B1 - Parte 6',
    ),

    // ── B2 ──
    BadgeDefinition(
      id: 'b2_1',
      assetPath: 'assets/badges/B2/1.webp',
      level: 'B2',
      coursePartName: 'B2 Parte 1',
      diagnosticSectionNum: 16,
      title: '¡Sección Completada!',
      subtitle: 'B2 - Parte 1',
    ),
    BadgeDefinition(
      id: 'b2_2',
      assetPath: 'assets/badges/B2/2.webp',
      level: 'B2',
      coursePartName: 'B2 Parte 2',
      diagnosticSectionNum: 17,
      title: '¡Sección Completada!',
      subtitle: 'B2 - Parte 2',
    ),
    BadgeDefinition(
      id: 'b2_3',
      assetPath: 'assets/badges/B2/3.webp',
      level: 'B2',
      coursePartName: 'B2 Parte 3',
      diagnosticSectionNum: 18,
      title: '¡Sección Completada!',
      subtitle: 'B2 - Parte 3',
    ),
    BadgeDefinition(
      id: 'b2_4',
      assetPath: 'assets/badges/B2/4.webp',
      level: 'B2',
      coursePartName: 'B2 Parte 4',
      diagnosticSectionNum: 19,
      title: '¡Sección Completada!',
      subtitle: 'B2 - Parte 4',
    ),
    BadgeDefinition(
      id: 'b2_5',
      assetPath: 'assets/badges/B2/5.webp',
      level: 'B2',
      coursePartName: 'B2 Parte 5',
      diagnosticSectionNum: 20,
      title: '¡Sección Completada!',
      subtitle: 'B2 - Parte 5',
    ),
    BadgeDefinition(
      id: 'b2_6',
      assetPath: 'assets/badges/B2/6.webp',
      level: 'B2',
      coursePartName: 'B2 Parte 6',
      diagnosticSectionNum: 21,
      title: '¡Nivel B2 Completado!',
      subtitle: 'B2 - Parte 6',
    ),
  ];

  // ── IDs de cursos ──
  static const int diagnosticCourseId = 9;

  // ── Verificación de completitud ──────────────────────────────────

  /// Verifica si una parte específica del curso está completada.
  /// Usa los datos de secciones ya cargados para evitar calls redundantes.
  bool isCoursePartCompleted(
    List<dynamic> courseSections,
    String partName,
    Map<String, dynamic> partsConfig,
  ) {
    final partConfig = partsConfig[partName];
    if (partConfig == null) return false;

    final List<int> allowedIds = List<int>.from(partConfig['ids']);
    final int totalExpected = partConfig['totalExercises'];

    int completedCount = 0;
    int exerciseCount = 0;
    for (var section in courseSections) {
      final sectionNum = int.tryParse(section['section'].toString());
      if (sectionNum == null || !allowedIds.contains(sectionNum)) continue;

      final modules = section['modules'] as List<dynamic>? ?? [];
      for (var m in modules) {
        final name = m['name']?.toString().toLowerCase() ?? '';
        if (!name.contains('ejercicio')) continue;

        exerciseCount++;
        if (m['completionState'] == 1 || m['completionState'] == 2) {
          completedCount++;
        } else if (m['grade'] != null && m['grade'] != '-') {
          completedCount++;
        }
      }
    }

    if (exerciseCount == 0) return false;
    return completedCount >= exerciseCount;
  }

  /// Verifica si una sección de diagnóstico está completada.
  bool isDiagnosticSectionCompleted(
    List<dynamic> diagnosticSections,
    int sectionNum,
  ) {
    for (var section in diagnosticSections) {
      final num = int.tryParse(section['section'].toString());
      if (num != sectionNum) continue;

      final modules = section['modules'] as List<dynamic>? ?? [];
      if (modules.isEmpty) return false;

      int total = 0;
      int completed = 0;
      for (var m in modules) {
        total++;
        if (m['completionState'] == 1 ||
            m['completionState'] == 2 ||
            (m['grade'] != null && m['grade'] != '-')) {
          completed++;
        }
      }
      return total > 0 && completed == total;
    }
    return false;
  }

  // ── Persistencia ──────────────────────────────────────────────────

  /// Obtiene la lista de IDs de badges ya ganados.
  Future<Set<String>> getEarnedBadgeIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyEarnedBadges);
    if (stored == null) return {};
    final List<dynamic> list = json.decode(stored);
    return list.cast<String>().toSet();
  }

  /// Marca un badge como ganado.
  Future<void> markBadgeEarned(String badgeId) async {
    final earned = await getEarnedBadgeIds();
    earned.add(badgeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEarnedBadges, json.encode(earned.toList()));
  }

  /// Obtiene la lista de IDs de badges cuya animación ya fue mostrada.
  Future<Set<String>> getShownBadgeIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyShownBadges);
    if (stored == null) return {};
    final List<dynamic> list = json.decode(stored);
    return list.cast<String>().toSet();
  }

  /// Marca un badge como ya mostrado (para no repetir la animación).
  Future<void> markBadgeShown(String badgeId) async {
    final shown = await getShownBadgeIds();
    shown.add(badgeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShownBadges, json.encode(shown.toList()));
  }

  /// Verifica y retorna los badges recién ganados que aún no se han mostrado.
  /// Debe llamarse después de que el usuario complete alguna actividad.
  Future<List<BadgeDefinition>> checkForNewBadges({
    required List<dynamic> courseSections,
    required Map<String, dynamic> coursePartsConfig,
    required List<dynamic> diagnosticSections,
  }) async {
    final earned = await getEarnedBadgeIds();
    final shown = await getShownBadgeIds();
    final newBadges = <BadgeDefinition>[];

    for (var badge in allBadges) {
      // Si ya fue ganado y mostrado, saltar
      if (earned.contains(badge.id) && shown.contains(badge.id)) continue;

      // Verificar condiciones
      final courseCompleted = isCoursePartCompleted(
        courseSections,
        badge.coursePartName,
        coursePartsConfig,
      );

      // Si diagnosticSectionNum == -1, no requiere diagnóstico
      final bool diagnosticCompleted;
      if (badge.diagnosticSectionNum == -1) {
        diagnosticCompleted = true;
      } else {
        diagnosticCompleted = isDiagnosticSectionCompleted(
          diagnosticSections,
          badge.diagnosticSectionNum,
        );
      }

      if (courseCompleted && diagnosticCompleted) {
        // Marcar como ganado si es la primera vez
        if (!earned.contains(badge.id)) {
          await markBadgeEarned(badge.id);
        }
        // Si no se ha mostrado aún, agregar a la lista
        if (!shown.contains(badge.id)) {
          newBadges.add(badge);
        }
      }
    }

    return newBadges;
  }

  /// Versión simplificada: verifica badges usando llamadas directas a la API.
  /// Úsese cuando no se tienen las secciones pre-cargadas.
  Future<List<BadgeDefinition>> checkForNewBadgesFromApi({
    required int courseId,
  }) async {
    try {
      final courseService = CourseService();

      // Obtener lista de cursos para identificar el nivel
      final courses = await courseService.getCourses();
      final courseData = courses.firstWhere(
        (c) => c['id'] == courseId, 
        orElse: () => null
      );
      
      if (courseData == null) return [];

      final String shortname = courseData['shortname'] ?? '';
      final String fullname = courseData['fullname'] ?? '';

      // Cargar datos de ambos cursos en paralelo
      final results = await Future.wait([
        courseService.getCourseDetails(courseId),
        courseService.getCourseDetails(diagnosticCourseId),
      ]);

      final courseSections = results[0]['sections'] as List<dynamic>? ?? [];
      final diagnosticSections = results[1]['sections'] as List<dynamic>? ?? [];

      // Determinar la configuración usando CourseConfig
      final coursePartsConfig = CourseConfig.getPartsForCourse(shortname, fullname: fullname);

      return checkForNewBadges(
        courseSections: courseSections,
        coursePartsConfig: coursePartsConfig,
        diagnosticSections: diagnosticSections,
      );
    } catch (e) {
      print('Debug BadgeService: Error checking badges: $e');
      return [];
    }
  }

  /// Limpia los datos de badges (útil al cerrar sesión).
  Future<void> clearBadgeData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEarnedBadges);
    await prefs.remove(_keyShownBadges);
  }
}

/// Modelo de definición de una insignia.
class BadgeDefinition {
  final String id;
  final String assetPath;
  final String level;
  final String coursePartName;
  final int diagnosticSectionNum;
  final String title;
  final String subtitle;

  const BadgeDefinition({
    required this.id,
    required this.assetPath,
    required this.level,
    required this.coursePartName,
    required this.diagnosticSectionNum,
    required this.title,
    required this.subtitle,
  });
}
