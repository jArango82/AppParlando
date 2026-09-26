import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../home_screen.dart';
import '../../models/professor_attendance_models.dart';
import '../../services/professor_attendance_service.dart';
import '../../services/professor_auth.dart';
import '../../widgets/custom_loading_indicator.dart';
import '../../widgets/limpio_card.dart';

/// Agenda del profesor: semana, día, clases y registro de asistencia.
/// Es la pantalla principal tras el login de profesor.
class ProfessorAttendanceScreen extends StatefulWidget {
  const ProfessorAttendanceScreen({super.key});

  @override
  State<ProfessorAttendanceScreen> createState() =>
      _ProfessorAttendanceScreenState();
}

class _ProfessorAttendanceScreenState extends State<ProfessorAttendanceScreen> {
  final _service = ProfessorAttendanceService();

  String _professorName = '';
  int _weekOffset = 0;
  String _activeDay = 'lunes';
  ProfessorWeekInfo? _week;
  List<ProfessorClassSlot> _classes = [];
  bool _loading = true;
  String? _error;
  final Set<String> _savingKeys = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final name = await ProfessorAuth.getDisplayName() ?? '';
    if (!mounted) return;
    setState(() => _professorName = name);
    await _loadWeek(0);
  }

  Future<void> _loadWeek(int offset) async {
    setState(() {
      _loading = true;
      _error = null;
      _weekOffset = offset;
      _week = getProfessorWeekInfo(offset);
    });

    try {
      await _service.loadWeek(_week!.weekKey);
      if (!mounted) return;
      _refreshClasses();
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la programación. Revisa tu conexión.';
        _classes = [];
      });
    }
  }

  void _refreshClasses() {
    if (_week == null || _professorName.isEmpty) {
      _classes = [];
      return;
    }
    _classes = _service.classesForDay(
      professorName: _professorName,
      dayKey: _activeDay,
      weekKey: _week!.weekKey,
    );
  }

  Future<void> _saveClass(ProfessorClassSlot cls) async {
    if (_week == null || _savingKeys.contains(cls.attendKey)) return;

    setState(() => _savingKeys.add(cls.attendKey));
    final ok = await _service.saveClassAttendance(
      weekKey: _week!.weekKey,
      dayKey: _activeDay,
      attendKey: cls.attendKey,
      professor: _professorName,
    );
    if (!mounted) return;
    setState(() => _savingKeys.remove(cls.attendKey));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Asistencia guardada · ${cls.room.name}'
              : 'Error al guardar la asistencia',
        ),
        backgroundColor: ok ? LimpioTokens.success : LimpioTokens.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ProfessorAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  String get _dayShortLabel {
    final name = ProfessorAttendanceConsts.dayNames[_activeDay] ?? _activeDay;
    final num = _week?.dayDates[_activeDay];
    if (num == null) return name;
    return '$name $num';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? LimpioTokens.darkInk : LimpioTokens.ink;
    final muted = isDark ? LimpioTokens.darkMuted : LimpioTokens.muted;
    final scaffold =
        isDark ? LimpioTokens.darkScaffold : LimpioTokens.scaffold;
    final week = _week;
    final firstName = _professorName.split(' ').firstWhere(
          (p) => p.isNotEmpty,
          orElse: () => 'Profesor',
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scaffold,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $firstName',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tu agenda de clases',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      onPressed: _logout,
                      icon: Icon(Icons.logout_rounded, color: muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _WeekBar(
                  dateRange: week?.dateRangeText ?? '…',
                  statusText: week?.statusText ?? '',
                  isCurrentWeek: _weekOffset == 0,
                  loading: _loading,
                  onPrev: () => _loadWeek(_weekOffset - 1),
                  onNext: () => _loadWeek(_weekOffset + 1),
                  onToday: _weekOffset == 0 ? null : () => _loadWeek(0),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (var i = 0;
                        i < ProfessorAttendanceConsts.dayKeys.length;
                        i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day =
                                ProfessorAttendanceConsts.dayKeys[i];
                            final selected = day == _activeDay;
                            final dateNum = week?.dayDates[day];
                            final short =
                                (ProfessorAttendanceConsts.dayNames[day] ??
                                        day)
                                    .substring(0, 3);
                            return _DayChip(
                              label: short,
                              dayNumber:
                                  dateNum != null ? '$dateNum' : '–',
                              selected: selected,
                              enabled: !_loading,
                              onTap: () {
                                setState(() {
                                  _activeDay = day;
                                  _refreshClasses();
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    Text(
                      _dayShortLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const Spacer(),
                    if (!_loading && _error == null)
                      Text(
                        _classes.isEmpty
                            ? 'Sin clases'
                            : '${_classes.length} clase${_classes.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CustomLoadingIndicator())
                    : _error != null
                        ? _ErrorState(
                            message: _error!,
                            onRetry: () => _loadWeek(_weekOffset),
                          )
                        : _classes.isEmpty
                            ? _EmptyDay(muted: muted)
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 28),
                                itemCount: _classes.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final cls = _classes[index];
                                  return _ClassAttendanceCard(
                                    cls: cls,
                                    statuses:
                                        _service.statusesFor(cls.attendKey),
                                    saving:
                                        _savingKeys.contains(cls.attendKey),
                                    onStatus: (studentId, status) {
                                      setState(() {
                                        _service.setStatus(
                                          attendKey: cls.attendKey,
                                          studentId: studentId,
                                          status: status,
                                        );
                                      });
                                    },
                                    onSave: () => _saveClass(cls),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final String dateRange;
  final String statusText;
  final bool isCurrentWeek;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  const _WeekBar({
    required this.dateRange,
    required this.statusText,
    required this.isCurrentWeek,
    required this.loading,
    required this.onPrev,
    required this.onNext,
    this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? LimpioTokens.darkInk : LimpioTokens.ink;
    final muted = isDark ? LimpioTokens.darkMuted : LimpioTokens.muted;
    final card = isDark ? LimpioTokens.darkCard : Colors.white;
    final line = isDark ? LimpioTokens.darkLine : LimpioTokens.line;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: loading ? null : onPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                color: ink,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      dateRange,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isCurrentWeek ? LimpioTokens.brand : muted)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrentWeek ? LimpioTokens.brand : muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading ? null : onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                color: ink,
              ),
            ],
          ),
          if (onToday != null)
            TextButton.icon(
              onPressed: loading ? null : onToday,
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Ir a esta semana'),
              style: TextButton.styleFrom(
                foregroundColor: LimpioTokens.brand,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final String dayNumber;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.dayNumber,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? LimpioTokens.darkInk : LimpioTokens.ink;
    final muted = isDark ? LimpioTokens.darkMuted : LimpioTokens.muted;
    final card = isDark ? LimpioTokens.darkCard : Colors.white;
    final line = isDark ? LimpioTokens.darkLine : LimpioTokens.line;

    return Material(
      color: selected ? LimpioTokens.brand : card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? LimpioTokens.brand : line,
              width: selected ? 0 : 1,
            ),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: LimpioTokens.brand.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dayNumber,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final Color muted;
  const _EmptyDay({required this.muted});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy_rounded, size: 34, color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin clases este día',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes clases programadas para este día en la semana seleccionada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 40, color: LimpioTokens.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassAttendanceCard extends StatelessWidget {
  final ProfessorClassSlot cls;
  final Map<String, String> statuses;
  final bool saving;
  final void Function(String studentId, String status) onStatus;
  final VoidCallback onSave;

  const _ClassAttendanceCard({
    required this.cls,
    required this.statuses,
    required this.saving,
    required this.onStatus,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? LimpioTokens.darkInk : LimpioTokens.ink;
    final muted = isDark ? LimpioTokens.darkMuted : LimpioTokens.muted;
    final line = isDark ? LimpioTokens.darkLine : LimpioTokens.line;

    final presente = statuses.values.where((v) => v == 'presente').length;
    final ausente = statuses.values.where((v) => v == 'ausente').length;
    final justificado =
        statuses.values.where((v) => v == 'justificado').length;
    final marked = presente + ausente + justificado;
    final total = cls.students.length;
    final withComments =
        cls.students.where((s) => s.hasComment).length;

    return LimpioCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: isDark
                  ? LimpioTokens.darkElevated
                  : LimpioTokens.brandSoft.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: LimpioTokens.brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(height: 4),
                      Text(
                        _slotShort(cls.slot),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls.slot,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaPill(
                            icon: Icons.meeting_room_outlined,
                            label: cls.room.name,
                          ),
                          _MetaPill(
                            icon: Icons.menu_book_rounded,
                            label: cls.classTypeLabel,
                          ),
                          _MetaPill(
                            icon: Icons.layers_outlined,
                            label: cls.levelsText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? LimpioTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_rounded, size: 14, color: muted),
                      const SizedBox(width: 4),
                      Text(
                        '$total',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (withComments > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.comment_rounded,
                      size: 15, color: LimpioTokens.warning),
                  const SizedBox(width: 6),
                  Text(
                    withComments == 1
                        ? '1 estudiante con comentario'
                        : '$withComments estudiantes con comentario',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: LimpioTokens.warning,
                    ),
                  ),
                ],
              ),
            ),
          if (total > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _MiniStat(
                    label: 'Presentes',
                    value: presente,
                    color: LimpioTokens.success,
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    label: 'Ausentes',
                    value: ausente,
                    color: LimpioTokens.danger,
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    label: 'Justif.',
                    value: justificado,
                    color: LimpioTokens.warning,
                  ),
                  const Spacer(),
                  Text(
                    '$marked/$total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : marked / total,
                  minHeight: 5,
                  backgroundColor: line,
                  color: marked == total
                      ? LimpioTokens.success
                      : LimpioTokens.brand,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                if (cls.students.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? LimpioTokens.darkElevated
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: line),
                    ),
                    child: Text(
                      'Nadie se ha agendado en esta clase todavía.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13.5),
                    ),
                  )
                else
                  ...cls.students.map((st) {
                    final status = statuses[st.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StudentRow(
                        student: st,
                        status: status,
                        onStatus: (s) => onStatus(st.id, s),
                      ),
                    );
                  }),
                if (cls.students.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: saving ? null : onSave,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        saving ? 'Guardando…' : 'Guardar asistencia',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: LimpioTokens.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _slotShort(String slot) {
    // "08:00 am - 09:30 am" → "08:00\nam"
    final start = slot.split(' - ').first.trim();
    final parts = start.split(' ');
    if (parts.length >= 2) {
      return '${parts[0]}\n${parts[1]}';
    }
    return start;
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? LimpioTokens.darkMuted : LimpioTokens.muted;
    final ink = isDark ? LimpioTokens.darkInk : LimpioTokens.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? LimpioTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final ProfessorStudent student;
  final String? status;
  final void Function(String status) onStatus;

  const _StudentRow({
    required this.student,
    required this.status,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? LimpioTokens.darkInk : LimpioTokens.ink;
    final muted = isDark ? LimpioTokens.darkMuted : LimpioTokens.muted;
    final line = isDark ? LimpioTokens.darkLine : LimpioTokens.line;

    Color accent = line;
    if (status == 'presente') accent = LimpioTokens.success;
    if (status == 'ausente') accent = LimpioTokens.danger;
    if (status == 'justificado') accent = LimpioTokens.warning;

    final initials = _initials(student.name);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == null ? line : accent,
          width: status == null ? 1 : 1.4,
        ),
        color: status == null
            ? Colors.transparent
            : accent.withValues(alpha: isDark ? 0.08 : 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(
                  alpha: status == null ? 0.12 : 0.18,
                ),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: status == null ? muted : accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ink,
                        ),
                      ),
                    ),
                    if (student.level.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: LimpioTokens.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          student.level,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: LimpioTokens.brand,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (student.hasComment) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: LimpioTokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: LimpioTokens.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.comment_rounded,
                    size: 16,
                    color: LimpioTokens.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comentario de programación',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: LimpioTokens.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          student.displayComment,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusButton(
                  label: 'Presente',
                  icon: Icons.check_circle_rounded,
                  active: status == 'presente',
                  color: LimpioTokens.success,
                  onTap: () => onStatus('presente'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatusButton(
                  label: 'Ausente',
                  icon: Icons.cancel_rounded,
                  active: status == 'ausente',
                  color: LimpioTokens.danger,
                  onTap: () => onStatus('ausente'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatusButton(
                  label: 'Justif.',
                  icon: Icons.schedule_rounded,
                  active: status == 'justificado',
                  color: LimpioTokens.warning,
                  onTap: () => onStatus('justificado'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
