/// Modelos para el agendamiento de clases semanales (hub estudiante).
library;

const scheduleDayKeys = [
  'lunes',
  'martes',
  'miercoles',
  'jueves',
  'viernes',
  'sabado',
];

const scheduleDayLabels = {
  'lunes': 'Lunes',
  'martes': 'Martes',
  'miercoles': 'Miércoles',
  'jueves': 'Jueves',
  'viernes': 'Viernes',
  'sabado': 'Sábado',
};

const scheduleBlockReasons = {
  'room_full': 'Salón lleno',
  'same_slot': 'Ya tienes una clase en esta franja',
  'limit_reached': 'Límite semanal alcanzado',
  'level_mismatch': 'Tu nivel no coincide con el salón',
  'room_disabled': 'Salón no disponible',
};

class ScheduleRoom {
  final String id;
  final String name;
  final String teacher;
  final String classTypeText;
  final String levelsText;
  final int enrolledCount;
  final int maxCapacity;
  final bool isBookedHere;
  final bool canBook;
  final bool canUnbook;
  final String? blockReason;

  const ScheduleRoom({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classTypeText,
    required this.levelsText,
    required this.enrolledCount,
    required this.maxCapacity,
    required this.isBookedHere,
    required this.canBook,
    required this.canUnbook,
    this.blockReason,
  });

  factory ScheduleRoom.fromJson(Map<String, dynamic> json) {
    return ScheduleRoom(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      teacher: json['teacher']?.toString() ?? 'Sin asignar',
      classTypeText: json['class_type_text']?.toString() ?? 'Conv/Gram',
      levelsText: json['levels_text']?.toString() ?? 'Todos los niveles',
      enrolledCount: (json['enrolled_count'] as num?)?.toInt() ?? 0,
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 0,
      isBookedHere: json['is_booked_here'] == true,
      canBook: json['can_book'] == true,
      canUnbook: json['can_unbook'] == true,
      blockReason: json['block_reason']?.toString(),
    );
  }

  String get blockMessage =>
      scheduleBlockReasons[blockReason] ?? 'No disponible';

  double get capacityRatio =>
      maxCapacity == 0 ? 0 : enrolledCount / maxCapacity;
}

class ScheduleSlot {
  final String slot;
  final List<ScheduleRoom> rooms;

  const ScheduleSlot({required this.slot, required this.rooms});

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'];
    final rooms = rawRooms is List
        ? rawRooms
            .whereType<Map>()
            .map((r) => ScheduleRoom.fromJson(Map<String, dynamic>.from(r)))
            .toList()
        : <ScheduleRoom>[];
    return ScheduleSlot(
      slot: json['slot']?.toString() ?? '',
      rooms: rooms,
    );
  }
}

class ScheduleDay {
  final String dayKey;
  final String dayName;
  final List<ScheduleSlot> slots;

  const ScheduleDay({
    required this.dayKey,
    required this.dayName,
    required this.slots,
  });

  factory ScheduleDay.fromJson(String key, Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    final slots = rawSlots is List
        ? rawSlots
            .whereType<Map>()
            .map((s) => ScheduleSlot.fromJson(Map<String, dynamic>.from(s)))
            .toList()
        : <ScheduleSlot>[];
    return ScheduleDay(
      dayKey: key,
      dayName: json['day_name']?.toString() ?? scheduleDayLabels[key] ?? key,
      slots: slots,
    );
  }
}

class StudentScheduleView {
  final int bookedCount;
  final int maxWeekly;
  final int remaining;
  final String effectiveLevel;
  final Map<String, ScheduleDay> days;

  const StudentScheduleView({
    required this.bookedCount,
    required this.maxWeekly,
    required this.remaining,
    required this.effectiveLevel,
    required this.days,
  });

  factory StudentScheduleView.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final days = <String, ScheduleDay>{};
    if (rawDays is Map) {
      rawDays.forEach((key, value) {
        if (value is Map) {
          days[key.toString()] = ScheduleDay.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return StudentScheduleView(
      bookedCount: (json['booked_count'] as num?)?.toInt() ?? 0,
      maxWeekly: (json['max_weekly'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      effectiveLevel: json['effective_level']?.toString() ?? '—',
      days: days,
    );
  }
}

class ScheduleWeekInfo {
  final String weekKey;
  final String dateRangeText;
  final String statusText;
  final int weeksOffset;

  const ScheduleWeekInfo({
    required this.weekKey,
    required this.dateRangeText,
    required this.statusText,
    required this.weeksOffset,
  });
}
