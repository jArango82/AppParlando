import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'net.dart' as http;

import 'student_service.dart';

class CourseLockInfo {
  final bool locked;

  /// Nivel que el asesor debe certificar para desbloquear (p. ej. `A1`).
  final String? requiredLevel;

  const CourseLockInfo({required this.locked, this.requiredLevel});

  static const unlocked = CourseLockInfo(locked: false);
}

/// Un curso de nivel queda bloqueado hasta que un asesor certifique, en
/// Estado Estudiante, el nivel matriculado inmediatamente anterior.
class CourseLockService {
  CourseLockService._();

  static const _certificationsUrl =
      'https://parlandolingue.com/assets/php/certifications.php';

  static const levelOrder = ['KIDS', 'A1', 'A2', 'B1', 'B2'];

  static String? levelOf(dynamic course) {
    final combined =
        '${course['fullname'] ?? ''} ${course['shortname'] ?? ''}'
            .toUpperCase();
    for (final level in levelOrder) {
      if (combined.contains(level)) return level;
    }
    return null;
  }

  /// Niveles certificados del estudiante en sesión (tabla student_certifications).
  /// Kids en Parlando se guarda como `A Int`; aquí se normaliza a `KIDS`.
  static Future<Set<String>> fetchCertifiedLevels() async {
    final profile = await StudentService().getStudentProfile();
    final studentId = profile?['studentId']?.toString() ?? '';
    if (studentId.isEmpty) {
      throw Exception('Perfil de estudiante no encontrado');
    }

    final uri = Uri.parse(_certificationsUrl).replace(queryParameters: {
      'student_id': studentId,
      '_t': '${DateTime.now().millisecondsSinceEpoch}',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    if (data is! Map || data['success'] != true) {
      throw Exception('Respuesta inválida de certificaciones');
    }

    final certs = data['certifications'];
    final result = <String>{};
    if (certs is List) {
      for (final c in certs) {
        if (c is! Map || '${c['certificationDate'] ?? ''}'.isEmpty) continue;
        final raw = '${c['level']}'.trim().toUpperCase();
        if (raw.isEmpty) continue;
        // En Parlando, Kids se certifica como "A Int" (Intro).
        if (raw == 'A INT' ||
            raw == 'CURSO INTRODUCTORIO' ||
            raw == 'INTRO' ||
            raw == 'KIDS') {
          result.add('KIDS');
        } else {
          result.add(raw);
        }
      }
    }
    return result;
  }

  static Future<Map<int, CourseLockInfo>> computeLocks(
    List<dynamic> courses,
  ) async {
    Set<String>? certified;
    try {
      certified = await fetchCertifiedLevels();
    } catch (e) {
      debugPrint('CourseLockService: no se pudieron leer certificaciones: $e');
    }
    return locksFor(courses, certified);
  }

  /// [certified] null = no se pudo verificar; se bloquea todo salvo el primero.
  static Map<int, CourseLockInfo> locksFor(
    List<dynamic> courses,
    Set<String>? certified,
  ) {
    final result = <int, CourseLockInfo>{};
    final leveled = <({int id, String level})>[];

    for (final c in courses) {
      final id = c['id'] as int;
      final level = levelOf(c);
      if (level == null) {
        result[id] = CourseLockInfo.unlocked;
      } else {
        leveled.add((id: id, level: level));
      }
    }
    leveled.sort((a, b) =>
        levelOrder.indexOf(a.level).compareTo(levelOrder.indexOf(b.level)));

    for (var i = 0; i < leveled.length; i++) {
      final current = leveled[i];
      if (i == 0) {
        result[current.id] = CourseLockInfo.unlocked;
        continue;
      }
      final previous = leveled[i - 1].level;
      final locked = certified == null || !certified.contains(previous);
      result[current.id] = CourseLockInfo(
        locked: locked,
        requiredLevel: locked ? previous : null,
      );
    }
    return result;
  }
}
