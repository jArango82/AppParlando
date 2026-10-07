import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'net.dart' as http;

import '../models/professor_attendance_models.dart';
import 'professor_auth.dart';

/// Schedule + attendance APIs usadas por profesores (mismas que la web).
class ProfessorAttendanceService {
  static const _scheduleUrl =
      'https://parlandolingue.com/assets/php/profesores_schedule.php';
  static const _attendanceUrl =
      'https://parlandolingue.com/assets/php/profesores_attendance.php';

  static final ProfessorAttendanceService _instance =
      ProfessorAttendanceService._internal();
  factory ProfessorAttendanceService() => _instance;
  ProfessorAttendanceService._internal();

  /// schedule[day][slot][roomId] → room map
  Map<String, dynamic> _schedule = {};

  /// attendance[attendKey] → { studentId: status }
  Map<String, Map<String, String>> _attendance = {};

  Map<String, Map<String, String>> get attendance => _attendance;

  Future<void> loadWeek(String weekKey) async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_scheduleUrl?week_key=${Uri.encodeComponent(weekKey)}')),
        http.get(
            Uri.parse('$_attendanceUrl?week_key=${Uri.encodeComponent(weekKey)}')),
      ]);

      final schedRes = json.decode(utf8.decode(results[0].bodyBytes));
      final attendRes = json.decode(utf8.decode(results[1].bodyBytes));

      if (schedRes is Map &&
          schedRes['success'] == true &&
          schedRes['schedule'] is Map) {
        _schedule = Map<String, dynamic>.from(schedRes['schedule'] as Map);
      } else {
        _schedule = {};
      }

      final nextAttend = <String, Map<String, String>>{};
      if (attendRes is Map &&
          attendRes['success'] == true &&
          attendRes['attendance'] is Map) {
        final raw = attendRes['attendance'] as Map;
        raw.forEach((key, value) {
          if (value is Map) {
            nextAttend['$key'] = value.map(
              (k, v) => MapEntry('$k', '$v'),
            );
          }
        });
      }
      _attendance = nextAttend;
    } catch (e, st) {
      debugPrint('ProfessorAttendanceService.loadWeek: $e\n$st');
      _schedule = {};
      _attendance = {};
      rethrow;
    }
  }

  List<ProfessorClassSlot> classesForDay({
    required String professorName,
    required String dayKey,
    required String weekKey,
  }) {
    final classes = <ProfessorClassSlot>[];
    final slots = ProfessorAttendanceConsts.timeSlots[dayKey] ?? const [];
    final daySchedule = _asMap(_schedule[dayKey]);

    for (final slot in slots) {
      final slotData = _asMap(daySchedule[slot]);
      for (final room in ProfessorAttendanceConsts.rooms) {
        final rData = _asMap(slotData[room.id]);
        if (rData.isEmpty) continue;

        final enabled = rData['enabled'] == true || rData['enabled'] == 1;
        if (!enabled) continue;

        final teacher = '${rData['teacher'] ?? ''}';
        if (ProfessorAuth.normalize(teacher) !=
            ProfessorAuth.normalize(professorName)) {
          continue;
        }

        final levelsRaw = rData['levels'];
        final levels = levelsRaw is List
            ? levelsRaw.map((e) => '$e').toList()
            : <String>[];

        final studentsRaw = rData['students'];
        final students = <ProfessorStudent>[];
        if (studentsRaw is List) {
          for (final s in studentsRaw) {
            if (s is Map) {
              students.add(
                ProfessorStudent.fromJson(
                  s.map((k, v) => MapEntry('$k', v)),
                ),
              );
            }
          }
        }

        classes.add(
          ProfessorClassSlot(
            dayKey: dayKey,
            slot: slot,
            room: room,
            levels: levels,
            students: students,
            teacher: teacher,
            classType: '${rData['classType'] ?? 'ambas'}',
            attendKey: buildAttendKey(
              weekKey: weekKey,
              dayKey: dayKey,
              slot: slot,
              roomId: room.id,
            ),
          ),
        );
      }
    }
    return classes;
  }

  void setStatus({
    required String attendKey,
    required String studentId,
    required String status,
  }) {
    _attendance.putIfAbsent(attendKey, () => {});
    _attendance[attendKey]![studentId] = status;
  }

  Map<String, String> statusesFor(String attendKey) =>
      Map<String, String>.from(_attendance[attendKey] ?? const {});

  Future<bool> saveClassAttendance({
    required String weekKey,
    required String dayKey,
    required String attendKey,
    required String professor,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_attendanceUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'week_key': weekKey,
          'day': dayKey,
          'attend_key': attendKey,
          'professor': professor,
          'attendance': _attendance[attendKey] ?? {},
        }),
      );

      if (response.statusCode != 200) return false;
      final data = json.decode(utf8.decode(response.bodyBytes));
      return data is Map && data['success'] == true;
    } catch (e, st) {
      debugPrint('ProfessorAttendanceService.save: $e\n$st');
      return false;
    }
  }

  Map<String, int> weekSummaryCounts(String professorName, String weekKey) {
    var presente = 0;
    var ausente = 0;
    var justificado = 0;
    var pending = 0;

    for (final day in ProfessorAttendanceConsts.dayKeys) {
      final classes = classesForDay(
        professorName: professorName,
        dayKey: day,
        weekKey: weekKey,
      );
      for (final cls in classes) {
        final saved = statusesFor(cls.attendKey);
        for (final st in cls.students) {
          final status = saved[st.id];
          if (status == 'presente') {
            presente++;
          } else if (status == 'ausente') {
            ausente++;
          } else if (status == 'justificado') {
            justificado++;
          } else {
            pending++;
          }
        }
      }
    }

    return {
      'presente': presente,
      'ausente': ausente,
      'justificado': justificado,
      'pending': pending,
    };
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}
