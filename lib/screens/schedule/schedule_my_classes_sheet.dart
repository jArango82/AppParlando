import 'package:flutter/material.dart';

import '../../models/schedule_models.dart';
import '../../services/schedule_service.dart';
import '../../theme_provider.dart';

typedef MyClassSelection = ({int weekOffset, String dayKey});

/// Clases que el estudiante tiene agendadas (semana actual y próxima).
class ScheduleMyClassesSheet extends StatefulWidget {
  final String studentId;

  const ScheduleMyClassesSheet({super.key, required this.studentId});

  /// Devuelve la semana/día elegidos si el estudiante toca una clase.
  static Future<MyClassSelection?> show(
    BuildContext context, {
    required String studentId,
  }) {
    return showModalBottomSheet<MyClassSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleMyClassesSheet(studentId: studentId),
    );
  }

  @override
  State<ScheduleMyClassesSheet> createState() => _ScheduleMyClassesSheetState();
}

class _ScheduleMyClassesSheetState extends State<ScheduleMyClassesSheet> {
  static const _brand = Color(0xFF2A60E4);
  static const _success = Color(0xFF1FAB5E);
  static const _weekOffsets = [0, 1];

  final _service = ScheduleService();
  final Map<int, StudentScheduleView?> _views = {};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      for (final offset in _weekOffsets) {
        _views[offset] = await _service.fetchWeek(
          studentId: widget.studentId,
          weekKey: _service.getWeekInfo(offset).weekKey,
          forceRefresh: true,
        );
      }
    } catch (_) {
      _failed = true;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.8;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.bgScaffold,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mis clases agendadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.textColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No pudimos cargar tus clases.',
              style: TextStyle(color: context.subtitleColor),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        for (final offset in _weekOffsets) ..._buildWeek(context, offset),
      ],
    );
  }

  List<Widget> _buildWeek(BuildContext context, int offset) {
    final info = _service.getWeekInfo(offset);
    final classes = _views[offset]?.bookedClasses ?? const [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Row(
          children: [
            Text(
              offset == 0 ? 'Esta semana' : 'Próxima semana',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: context.textColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info.dateRangeText,
                style: TextStyle(fontSize: 12, color: context.subtitleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      if (classes.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Text(
            'No tienes clases agendadas.',
            style: TextStyle(color: context.subtitleColor, fontSize: 13),
          ),
        )
      else
        for (final c in classes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop<MyClassSelection>(
                  context,
                  (weekOffset: offset, dayKey: c.dayKey),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (scheduleDayLabels[c.dayKey] ?? c.dayKey)
                              .substring(0, 3),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.slot,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                'Salón ${c.room.name}',
                                c.room.classTypeText,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.subtitleColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ];
  }
}
