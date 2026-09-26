// Modelos y constantes del módulo de asistencias de profesores.
// Alineado con `profesores-asistencia.js`.

class ProfessorRoom {
  final String id;
  final String name;
  final int maxCapacity;

  const ProfessorRoom({
    required this.id,
    required this.name,
    required this.maxCapacity,
  });
}

class ProfessorWeekInfo {
  final String weekKey;
  final String dateRangeText;
  final String statusText;
  final int offset;
  final Map<String, int> dayDates;

  const ProfessorWeekInfo({
    required this.weekKey,
    required this.dateRangeText,
    required this.statusText,
    required this.offset,
    required this.dayDates,
  });
}

class ProfessorStudent {
  final String id;
  final String name;
  final String level;
  final String comment;

  const ProfessorStudent({
    required this.id,
    required this.name,
    this.level = '',
    this.comment = '',
  });

  factory ProfessorStudent.fromJson(Map<String, dynamic> json) {
    final rawComment = json['comment'] ??
        json['comments'] ??
        json['comentario'] ??
        json['nota'] ??
        json['note'] ??
        '';
    return ProfessorStudent(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? json['nombre'] ?? 'Estudiante'}',
      level: '${json['level'] ?? json['nivel'] ?? ''}'.trim(),
      comment: '$rawComment'.trim(),
    );
  }

  /// Texto listo para mostrar (códigos internos → etiqueta legible).
  String get displayComment {
    final c = comment.trim();
    if (c.isEmpty) return '';
    if (c == 'extra_asesor') return 'Clase extra autorizada por el asesor';
    return c;
  }

  bool get hasComment => displayComment.isNotEmpty;
}

class ProfessorClassSlot {
  final String dayKey;
  final String slot;
  final ProfessorRoom room;
  final List<String> levels;
  final List<ProfessorStudent> students;
  final String teacher;
  final String classType;
  final String attendKey;

  const ProfessorClassSlot({
    required this.dayKey,
    required this.slot,
    required this.room,
    required this.levels,
    required this.students,
    required this.teacher,
    required this.classType,
    required this.attendKey,
  });

  String get levelsText =>
      levels.isEmpty ? 'Sin nivel definido' : levels.join(', ');

  String get classTypeLabel {
    final v = classType.toLowerCase().trim();
    if (v == 'gramatica') return 'Gramática';
    if (v == 'conversacion') return 'Conversación';
    return 'Conv/Gram';
  }
}

abstract final class ProfessorAttendanceConsts {
  static const rooms = <ProfessorRoom>[
    ProfessorRoom(id: 'londres', name: 'Londres', maxCapacity: 7),
    ProfessorRoom(id: 'medellin', name: 'Tokyo', maxCapacity: 6),
    ProfessorRoom(id: 'new_york', name: 'New York', maxCapacity: 7),
    ProfessorRoom(id: 'berlin', name: 'Berlín', maxCapacity: 5),
    ProfessorRoom(id: 'roma', name: 'Roma', maxCapacity: 6),
    ProfessorRoom(id: 'paris', name: 'París', maxCapacity: 6),
  ];

  static const dayKeys = <String>[
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
  ];

  static const dayNames = <String, String>{
    'lunes': 'Lunes',
    'martes': 'Martes',
    'miercoles': 'Miércoles',
    'jueves': 'Jueves',
    'viernes': 'Viernes',
    'sabado': 'Sábado',
  };

  static const timeSlots = <String, List<String>>{
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

  static const statuses = <String, String>{
    'presente': 'Presente',
    'ausente': 'Ausente',
    'justificado': 'Justificado',
  };
}

/// Calcula semana ISO igual que `profesores-asistencia.js`.
ProfessorWeekInfo getProfessorWeekInfo(int offset) {
  final now = DateTime.now();
  final jsDay = now.weekday == DateTime.sunday ? 0 : now.weekday;
  final distanceToMonday = jsDay == 0 ? -6 : 1 - jsDay;

  final monday = DateTime(now.year, now.month, now.day)
      .add(Duration(days: distanceToMonday + offset * 7));
  final saturday = monday.add(const Duration(days: 5));
  final target = monday.add(const Duration(days: 3));

  final firstJan = DateTime(target.year, 1, 1);
  final firstJanJsDay =
      firstJan.weekday == DateTime.sunday ? 0 : firstJan.weekday;
  final weekNum =
      ((target.difference(firstJan).inDays + firstJanJsDay + 1) / 7).ceil();
  final weekKey = '${target.year}-W${weekNum.toString().padLeft(2, '0')}';

  const months = [
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
      : '${monday.day} ${months[monday.month - 1]} — ${saturday.day} ${months[saturday.month - 1]}, ${saturday.year}';

  String statusText;
  if (offset == 0) {
    statusText = 'Semana Actual';
  } else if (offset > 0) {
    statusText = offset == 1 ? 'Semana Próxima' : 'En $offset semanas';
  } else {
    final abs = offset.abs();
    statusText = abs == 1 ? 'Semana Pasada' : 'Hace $abs semanas';
  }

  final dayDates = <String, int>{};
  for (var i = 0; i < ProfessorAttendanceConsts.dayKeys.length; i++) {
    dayDates[ProfessorAttendanceConsts.dayKeys[i]] =
        monday.add(Duration(days: i)).day;
  }

  return ProfessorWeekInfo(
    weekKey: weekKey,
    dateRangeText: dateRangeText,
    statusText: statusText,
    offset: offset,
    dayDates: dayDates,
  );
}

String buildAttendKey({
  required String weekKey,
  required String dayKey,
  required String slot,
  required String roomId,
}) {
  return '${weekKey}_${dayKey}_${slot.replaceAll(RegExp(r'\s'), '_')}_$roomId';
}
