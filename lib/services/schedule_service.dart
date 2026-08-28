import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/schedule_models.dart';

/// Agendamiento de clases — mismo backend que hub_estudiante web.
class ScheduleService {
  static const String _apiUrl =
      'https://parlandolingue.com/assets/php/student_schedule_booking.php';

  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  String? _cachedWeekKey;
  String? _cachedStudentId;
  StudentScheduleView? _cachedView;
  DateTime? _lastFetchTime;

  /// Calcula semana ISO igual que `hub-student-schedule.js`.
  ScheduleWeekInfo getWeekInfo(int weeksOffset) {
    final now = DateTime.now();
    final jsDay = now.weekday == DateTime.sunday ? 0 : now.weekday;
    final distanceToMonday = jsDay == 0 ? -6 : 1 - jsDay;

    final monday = DateTime(now.year, now.month, now.day)
        .add(Duration(days: distanceToMonday + weeksOffset * 7));
    final saturday = monday.add(const Duration(days: 5));
    final targetDate = monday.add(const Duration(days: 3));

    final firstJan = DateTime(targetDate.year, 1, 1);
    final firstJanJsDay =
        firstJan.weekday == DateTime.sunday ? 0 : firstJan.weekday;
    final weekNum = ((targetDate.difference(firstJan).inDays +
                firstJanJsDay +
                1) /
            7)
        .ceil();
    final weekKey =
        '${targetDate.year}-W${weekNum.toString().padLeft(2, '0')}';

    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final dateRangeText = monday.month == saturday.month
        ? '${monday.day} al ${saturday.day} de ${months[saturday.month - 1]}, ${saturday.year}'
        : '${monday.day} ${months[monday.month - 1]} - ${saturday.day} ${months[saturday.month - 1]}, ${saturday.year}';

    String statusText;
    if (weeksOffset == 0) {
      statusText = 'Semana actual';
    } else if (weeksOffset < 0) {
      statusText = 'Semana pasada';
    } else if (weeksOffset == 1) {
      statusText = 'Próxima semana';
    } else {
      statusText = 'En $weeksOffset semanas';
    }

    return ScheduleWeekInfo(
      weekKey: weekKey,
      dateRangeText: dateRangeText,
      statusText: statusText,
      weeksOffset: weeksOffset,
    );
  }

  Future<StudentScheduleView?> fetchWeek({
    required String studentId,
    required String weekKey,
    bool forceRefresh = false,
  }) async {
    if (studentId.trim().isEmpty) return null;

    if (!forceRefresh &&
        _cachedView != null &&
        _cachedStudentId == studentId &&
        _cachedWeekKey == weekKey &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inSeconds < 90) {
      return _cachedView;
    }

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'week_key': weekKey,
        'student_id': studentId,
      });
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['student'] == null) {
        throw Exception(data['message']?.toString() ?? 'Respuesta inválida');
      }

      final view = StudentScheduleView.fromJson(
        Map<String, dynamic>.from(data['student'] as Map),
      );

      _cachedView = view;
      _cachedStudentId = studentId;
      _cachedWeekKey = weekKey;
      _lastFetchTime = DateTime.now();
      return view;
    } catch (e) {
      debugPrint('ScheduleService.fetchWeek: $e');
      if (_cachedWeekKey == weekKey && _cachedStudentId == studentId) {
        return _cachedView;
      }
      rethrow;
    }
  }

  Future<({bool success, String message, StudentScheduleView? view})> book({
    required String studentId,
    required String weekKey,
    required String dayKey,
    required String slot,
    required String roomId,
  }) {
    return _mutate(
      studentId: studentId,
      weekKey: weekKey,
      body: {
        'action': 'book',
        'week_key': weekKey,
        'day_key': dayKey,
        'slot': slot,
        'room_id': roomId,
        'student_id': studentId,
      },
    );
  }

  Future<({bool success, String message, StudentScheduleView? view})> unbook({
    required String studentId,
    required String weekKey,
    required String dayKey,
    required String slot,
    required String roomId,
  }) {
    return _mutate(
      studentId: studentId,
      weekKey: weekKey,
      body: {
        'action': 'unbook',
        'week_key': weekKey,
        'day_key': dayKey,
        'slot': slot,
        'room_id': roomId,
        'student_id': studentId,
      },
    );
  }

  Future<({bool success, String message, StudentScheduleView? view})> _mutate({
    required String studentId,
    required String weekKey,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        return (
          success: false,
          message: data['message']?.toString() ?? 'No se pudo completar',
          view: null,
        );
      }

      final view = data['student'] != null
          ? StudentScheduleView.fromJson(
              Map<String, dynamic>.from(data['student'] as Map),
            )
          : null;

      if (view != null) {
        _cachedView = view;
        _cachedStudentId = studentId;
        _cachedWeekKey = weekKey;
        _lastFetchTime = DateTime.now();
      }

      return (
        success: true,
        message: data['message']?.toString() ?? 'Listo',
        view: view,
      );
    } catch (e) {
      debugPrint('ScheduleService._mutate: $e');
      return (success: false, message: 'Error de conexión', view: null);
    }
  }

  void clearCache() {
    _cachedView = null;
    _cachedStudentId = null;
    _cachedWeekKey = null;
    _lastFetchTime = null;
  }
}
