import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/schedule_models.dart';
import '../../models/schedule_reminder_models.dart';
import '../../services/schedule_reminder_service.dart';
import '../../theme_provider.dart';

/// Bottom sheet para configurar avisos de cupos.
class ScheduleRemindersSheet extends StatefulWidget {
  final String studentId;

  const ScheduleRemindersSheet({super.key, required this.studentId});

  static Future<ScheduleReminderSettings?> show(
    BuildContext context, {
    required String studentId,
  }) {
    return showModalBottomSheet<ScheduleReminderSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleRemindersSheet(studentId: studentId),
    );
  }

  @override
  State<ScheduleRemindersSheet> createState() => _ScheduleRemindersSheetState();
}

class _ScheduleRemindersSheetState extends State<ScheduleRemindersSheet> {
  static const _brand = Color(0xFF2A60E4);

  final _service = ScheduleReminderService();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  String? _expandedDay;
  late Map<String, Set<String>> _selection;

  @override
  void initState() {
    super.initState();
    _selection = {
      for (final day in scheduleDayKeys) day: <String>{},
    };
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.load(widget.studentId);
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _selection = settings.toEditableMap();
      _loading = false;
      if (_enabled) {
        _expandedDay = scheduleDayKeys.firstWhere(
          (d) => (_selection[d] ?? {}).isNotEmpty,
          orElse: () => 'lunes',
        );
      }
    });
  }

  int get _selectedCount =>
      _selection.values.fold(0, (sum, set) => sum + set.length);

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final result = await _service.save(
      studentId: widget.studentId,
      enabled: _enabled,
      editableMap: _selection,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (result.success) {
      Navigator.of(context).pop(result.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
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
                      'Avisos de cupos',
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        _buildMasterSwitch(context),
                        const SizedBox(height: 12),
                        Text(
                          _enabled
                              ? 'Elige los días y horarios que te interesan. Te enviaremos una notificación cuando se libere un cupo.'
                              : 'Activa los avisos para enterarte cuando se libere un cupo en el horario que quieres.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: context.subtitleColor,
                          ),
                        ),
                        if (_enabled) ...[
                          const SizedBox(height: 16),
                          ...scheduleDayKeys.map(_buildDaySection),
                        ],
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _enabled && _selectedCount > 0
                                ? 'Guardar ($_selectedCount ${_selectedCount == 1 ? 'horario' : 'horarios'})'
                                : 'Guardar',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterSwitch(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _enabled,
        activeThumbColor: Colors.white,
        activeTrackColor: _brand,
        title: Text(
          'Avisarme cuando haya cupo',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.textColor,
          ),
        ),
        subtitle: Text(
          _enabled
              ? 'Solo te avisaremos en los horarios que marques'
              : 'No recibirás avisos de cupos',
          style: TextStyle(fontSize: 12, color: context.subtitleColor),
        ),
        onChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() {
            _enabled = v;
            if (v && _expandedDay == null) _expandedDay = 'lunes';
          });
        },
      ),
    );
  }

  Widget _buildDaySection(String dayKey) {
    final slots = scheduleReminderSlotsByDay[dayKey] ?? const [];
    final selected = _selection[dayKey] ?? {};
    final expanded = _expandedDay == dayKey;
    final label = scheduleDayLabels[dayKey] ?? dayKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected.isNotEmpty
              ? _brand.withValues(alpha: 0.45)
              : context.borderColor,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _expandedDay = expanded ? null : dayKey;
              });
            },
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.textColor,
              ),
            ),
            subtitle: Text(
              selected.isEmpty
                  ? 'Ningún horario'
                  : '${selected.length} horario${selected.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: context.subtitleColor),
            ),
            trailing: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((slot) {
                  final isOn = selected.contains(slot);
                  return FilterChip(
                    selected: isOn,
                    label: Text(slot, style: const TextStyle(fontSize: 12)),
                    selectedColor: _brand.withValues(alpha: 0.15),
                    checkmarkColor: _brand,
                    onSelected: (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        final set = _selection[dayKey]!;
                        if (v) {
                          set.add(slot);
                        } else {
                          set.remove(slot);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
