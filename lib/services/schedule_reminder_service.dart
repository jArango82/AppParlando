import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/schedule_reminder_models.dart';
import 'insforge_service.dart';
import 'push_notification_service.dart';

/// Persiste recordatorios de cupos en InsForge y gestiona el token FCM.
class ScheduleReminderService {
  static const _table = 'schedule_reminders';

  static final ScheduleReminderService _instance =
      ScheduleReminderService._internal();
  factory ScheduleReminderService() => _instance;
  ScheduleReminderService._internal();

  final _insforge = InsforgeService();
  final _push = PushNotificationService();

  Future<ScheduleReminderSettings> load(String studentId) async {
    if (studentId.trim().isEmpty) {
      return ScheduleReminderSettings.empty(studentId);
    }

    try {
      final row = await _insforge.querySingle(
        _table,
        filters: {'student_id': 'eq.$studentId'},
      );
      if (row == null) {
        return ScheduleReminderSettings.empty(studentId);
      }
      return ScheduleReminderSettings.fromJson(row);
    } catch (e) {
      debugPrint('ScheduleReminderService.load: $e');
      return ScheduleReminderSettings.empty(studentId);
    }
  }

  /// Guarda preferencias. Si [enabled] y hay slots, pide permiso y token FCM.
  /// Si se desactivan, limpia el token local y en InsForge.
  Future<({bool success, String message, ScheduleReminderSettings? settings})>
      save({
    required String studentId,
    required bool enabled,
    required Map<String, Set<String>> editableMap,
  }) async {
    try {
      final reminders =
          ScheduleReminderSettings.fromEditableMap(editableMap);
      final hasSlots = reminders.isNotEmpty;

      if (enabled && !hasSlots) {
        return (
          success: false,
          message: 'Selecciona al menos un día y un horario.',
          settings: null,
        );
      }

      String? token;
      String? platform;

      if (enabled && hasSlots) {
        token = await _push.requestPermissionAndGetToken();
        if (token == null || token.isEmpty) {
          return (
            success: false,
            message:
                'Para recibir avisos, permite las notificaciones de Parlando en los ajustes de tu teléfono.',
            settings: null,
          );
        }
        platform = Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'other';

        _push.listenTokenRefresh((newToken) {
          _persistTokenOnly(studentId, newToken);
        });
      } else {
        await _push.clearToken();
        token = null;
        platform = null;
      }

      final settings = ScheduleReminderSettings(
        studentId: studentId,
        enabled: enabled && hasSlots,
        reminders: reminders,
        fcmToken: token,
        platform: platform,
      );

      await _insforge.upsert(
        _table,
        [settings.toUpsertJson(fcmToken: token, platform: platform)],
        onConflict: 'student_id',
      );

      return (
        success: true,
        message: settings.enabled
            ? 'Listo. Te avisaremos cuando haya cupo.'
            : 'Avisos de cupos desactivados.',
        settings: settings,
      );
    } catch (e) {
      debugPrint('ScheduleReminderService.save: $e');
      return (
        success: false,
        message:
            'No pudimos guardar tus avisos. Intenta de nuevo en un momento.',
        settings: null,
      );
    }
  }

  Future<void> _persistTokenOnly(String studentId, String token) async {
    try {
      final current = await load(studentId);
      if (!current.enabled) return;
      await _insforge.upsert(
        _table,
        [
          current.toUpsertJson(
            fcmToken: token,
            platform: Platform.isIOS
                ? 'ios'
                : Platform.isAndroid
                    ? 'android'
                    : 'other',
          ),
        ],
        onConflict: 'student_id',
      );
    } catch (e) {
      debugPrint('ScheduleReminderService._persistTokenOnly: $e');
    }
  }
}
