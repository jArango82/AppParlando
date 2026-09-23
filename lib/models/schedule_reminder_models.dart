/// Preferencias de recordatorios push para cupos de matrícula.
library;

import 'schedule_models.dart';

/// Franjas horarias por día (mismo orden que el backend Parlando).
const scheduleReminderSlotsByDay = <String, List<String>>{
  'lunes': [
    '07:00 am - 08:30 am',
    '08:30 am - 10:00 am',
    '10:00 am - 11:30 am',
    '11:30 am - 01:00 pm',
    '01:00 pm - 02:30 pm',
    '02:30 pm - 04:00 pm',
    '04:00 pm - 05:30 pm',
    '05:30 pm - 07:00 pm',
  ],
  'martes': [
    '08:00 am - 09:30 am',
    '09:30 am - 11:00 am',
    '11:00 am - 12:30 pm',
    '12:30 pm - 02:00 pm',
    '02:00 pm - 03:30 pm',
    '03:30 pm - 05:00 pm',
    '05:00 pm - 06:30 pm',
    '06:30 pm - 08:00 pm',
  ],
  'miercoles': [
    '08:00 am - 09:30 am',
    '09:30 am - 11:00 am',
    '11:00 am - 12:30 pm',
    '12:30 pm - 02:00 pm',
    '02:00 pm - 03:30 pm',
    '03:30 pm - 05:00 pm',
    '05:00 pm - 06:30 pm',
    '06:30 pm - 08:00 pm',
  ],
  'jueves': [
    '08:00 am - 09:30 am',
    '09:30 am - 11:00 am',
    '11:00 am - 12:30 pm',
    '12:30 pm - 02:00 pm',
    '02:00 pm - 03:30 pm',
    '03:30 pm - 05:00 pm',
    '05:00 pm - 06:30 pm',
    '06:30 pm - 08:00 pm',
  ],
  'viernes': [
    '07:00 am - 08:30 am',
    '08:30 am - 10:00 am',
    '10:00 am - 11:30 am',
    '11:30 am - 01:00 pm',
    '01:00 pm - 02:30 pm',
    '02:30 pm - 04:00 pm',
    '04:00 pm - 05:30 pm',
    '05:30 pm - 07:00 pm',
  ],
  'sabado': [
    '08:00 am - 09:30 am',
    '09:30 am - 11:00 am',
    '11:00 am - 12:30 pm',
  ],
};

class DayReminderPreference {
  final String dayKey;
  final List<String> slots;

  const DayReminderPreference({
    required this.dayKey,
    required this.slots,
  });

  factory DayReminderPreference.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    return DayReminderPreference(
      dayKey: json['day']?.toString() ?? json['day_key']?.toString() ?? '',
      slots: rawSlots is List
          ? rawSlots.map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'day': dayKey,
        'slots': slots,
      };

  String get dayLabel => scheduleDayLabels[dayKey] ?? dayKey;
}

class ScheduleReminderSettings {
  final String studentId;
  final bool enabled;
  final List<DayReminderPreference> reminders;
  final String? fcmToken;
  final String? platform;

  const ScheduleReminderSettings({
    required this.studentId,
    required this.enabled,
    required this.reminders,
    this.fcmToken,
    this.platform,
  });

  factory ScheduleReminderSettings.empty(String studentId) {
    return ScheduleReminderSettings(
      studentId: studentId,
      enabled: false,
      reminders: const [],
    );
  }

  factory ScheduleReminderSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['reminders'];
    final list = <DayReminderPreference>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(DayReminderPreference.fromJson(item));
        } else if (item is Map) {
          list.add(DayReminderPreference.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ScheduleReminderSettings(
      studentId: json['student_id']?.toString() ?? '',
      enabled: json['enabled'] == true,
      reminders: list.where((r) => r.dayKey.isNotEmpty && r.slots.isNotEmpty).toList(),
      fcmToken: json['fcm_token']?.toString(),
      platform: json['platform']?.toString(),
    );
  }

  int get selectedSlotCount =>
      reminders.fold(0, (sum, day) => sum + day.slots.length);

  bool get hasActiveReminders => enabled && selectedSlotCount > 0;

  /// Mapa mutable dayKey -> set de slots (para editar en UI).
  Map<String, Set<String>> toEditableMap() {
    final map = <String, Set<String>>{
      for (final day in scheduleDayKeys) day: <String>{},
    };
    for (final rem in reminders) {
      map[rem.dayKey] = rem.slots.toSet();
    }
    return map;
  }

  static List<DayReminderPreference> fromEditableMap(
    Map<String, Set<String>> map,
  ) {
    return scheduleDayKeys
        .where((day) => (map[day] ?? {}).isNotEmpty)
        .map(
          (day) => DayReminderPreference(
            dayKey: day,
            slots: (map[day]!.toList()
              ..sort((a, b) {
                final order = scheduleReminderSlotsByDay[day] ?? const [];
                return order.indexOf(a).compareTo(order.indexOf(b));
              })),
          ),
        )
        .toList();
  }

  Map<String, dynamic> toUpsertJson({
    String? fcmToken,
    String? platform,
  }) {
    return {
      'student_id': studentId,
      'enabled': enabled,
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'fcm_token': fcmToken ?? this.fcmToken,
      'platform': platform ?? this.platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
