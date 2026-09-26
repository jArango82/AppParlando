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
  'course_ended': 'Tu contrato no cubre esta fecha',
  'personalized_room_only': 'Salón exclusivo para clases personalizadas',
  'same_slot': 'Ya tienes una clase en este horario',
  'limit_reached': 'Ya agendaste todas tus clases de esta semana',
  'level_mismatch': 'Este salón no corresponde a tu nivel',
  'room_disabled': 'Salón cerrado en este horario',
};

const _monthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `2026-09-30` → `30 sep 2026`. Devuelve null si no se puede leer.
String? formatScheduleDate(String? isoDate) {
  final date = DateTime.tryParse(isoDate ?? '');
  if (date == null) return null;
  return '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
}

class ScheduleRoom {
  final String id;
  final String name;
  final String teacher;
  final String classTypeText;
  final String levelsText;
  final int enrolledCount;
  final int maxCapacity;
  final bool isPersonalizada;
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
    this.isPersonalizada = false,
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
      isPersonalizada: json['is_personalizada'] == true,
      isBookedHere: json['is_booked_here'] == true,
      canBook: json['can_book'] == true,
      canUnbook: json['can_unbook'] == true,
      blockReason: json['block_reason']?.toString(),
    );
  }

  bool get isFull => maxCapacity > 0 && enrolledCount >= maxCapacity;

  /// Razón efectiva, deduciéndola si el backend no la envía.
  String? get effectiveBlockReason {
    if (blockReason != null && blockReason!.isNotEmpty) return blockReason;
    if (isPersonalizada) return 'personalized_room_only';
    if (isFull) return 'room_full';
    return null;
  }

  String blockMessageFor(StudentScheduleView? view) {
    final reason = effectiveBlockReason;
    if (reason == 'course_ended') {
      final end = formatScheduleDate(view?.endDate);
      return end != null
          ? 'Tu contrato terminó el $end'
          : scheduleBlockReasons['course_ended']!;
    }
    if (reason == 'level_mismatch' &&
        view != null &&
        view.effectiveLevel != '—') {
      return 'Este salón no es para tu nivel (${view.effectiveLevel})';
    }
    return scheduleBlockReasons[reason] ?? 'No puedes agendar en este salón';
  }

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
  final bool courseEnded;
  final String? endDate;
  final Map<String, ScheduleDay> days;

  const StudentScheduleView({
    required this.bookedCount,
    required this.maxWeekly,
    required this.remaining,
    required this.effectiveLevel,
    required this.days,
    this.courseEnded = false,
    this.endDate,
  });

  /// La semana cae (total o parcialmente) fuera del contrato.
  bool get weekBeyondContract =>
      courseEnded ||
      days.values.any((d) => d.slots.any(
          (s) => s.rooms.any((r) => r.blockReason == 'course_ended')));

  /// Clases agendadas en la semana, en orden de día y hora.
  List<({String dayKey, String slot, ScheduleRoom room})> get bookedClasses {
    final result = <({String dayKey, String slot, ScheduleRoom room})>[];
    for (final dayKey in scheduleDayKeys) {
      final day = days[dayKey];
      if (day == null) continue;
      for (final slot in day.slots) {
        for (final room in slot.rooms) {
          if (room.isBookedHere) {
            result.add((dayKey: dayKey, slot: slot.slot, room: room));
          }
        }
      }
    }
    return result;
  }

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
      courseEnded: json['course_ended'] == true,
      endDate: json['end_date']?.toString(),
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
