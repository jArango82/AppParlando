import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/schedule_models.dart';
import '../../services/schedule_service.dart';
import '../../theme_provider.dart';
import '../../widgets/custom_loading_indicator.dart';
import '../../widgets/limpio_card.dart';

/// Pantalla de auto-agendamiento de clases semanales.
class ScheduleClassesScreen extends StatefulWidget {
  final String studentId;

  const ScheduleClassesScreen({super.key, required this.studentId});

  @override
  State<ScheduleClassesScreen> createState() => _ScheduleClassesScreenState();
}

class _ScheduleClassesScreenState extends State<ScheduleClassesScreen>
    with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF2A60E4);
  static const _success = Color(0xFF1FAB5E);
  static const _danger = Color(0xFFE74C3C);

  final _scheduleService = ScheduleService();

  int _weekOffset = 1;
  String _activeDay = 'lunes';
  StudentScheduleView? _view;
  bool _loading = true;
  String? _error;
  String? _pendingRoomId;
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _loadWeek();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  ScheduleWeekInfo get _weekInfo => _scheduleService.getWeekInfo(_weekOffset);

  Future<void> _loadWeek({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final view = await _scheduleService.fetchWeek(
        studentId: widget.studentId,
        weekKey: _weekInfo.weekKey,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la programación.';
        _loading = false;
      });
    }
  }

  void _changeWeek(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _weekOffset += delta);
    _loadWeek(forceRefresh: true);
  }

  void _goToWeek(int offset) {
    HapticFeedback.selectionClick();
    setState(() => _weekOffset = offset);
    _loadWeek(forceRefresh: true);
  }

  Future<void> _onAction({
    required bool book,
    required String dayKey,
    required String slot,
    required String roomId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(book ? '¿Confirmar agendamiento?' : '¿Cancelar clase?'),
        content: Text(
          book
              ? 'Te agendarás en esta clase de la semana seleccionada.'
              : 'Se quitará tu reserva de esta clase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: book ? _brand : _danger,
            ),
            child: Text(book ? 'Sí, agendarme' : 'Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _pendingRoomId = roomId);
    HapticFeedback.mediumImpact();

    final result = book
        ? await _scheduleService.book(
            studentId: widget.studentId,
            weekKey: _weekInfo.weekKey,
            dayKey: dayKey,
            slot: slot,
            roomId: roomId,
          )
        : await _scheduleService.unbook(
            studentId: widget.studentId,
            weekKey: _weekInfo.weekKey,
            dayKey: dayKey,
            slot: slot,
            roomId: roomId,
          );

    if (!mounted) return;
    setState(() => _pendingRoomId = null);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    setState(() => _view = result.view ?? _view);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekInfo;

    return Scaffold(
      backgroundColor: context.bgScaffold,
      appBar: AppBar(
        title: const Text(
          'Agendar clases',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _enterController,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _enterController,
            curve: Curves.easeOutCubic,
          )),
          child: RefreshIndicator(
            onRefresh: () => _loadWeek(forceRefresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildSummary(context),
                const SizedBox(height: 16),
                _buildWeekBar(context, week),
                const SizedBox(height: 16),
                _buildDayTabs(context),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _loading
                      ? const Padding(
                          key: ValueKey('loading'),
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CustomLoadingIndicator(size: 64)),
                        )
                      : _error != null
                          ? _buildError(key: const ValueKey('error'))
                          : _buildDayContent(key: ValueKey(_activeDay)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final v = _view;
    return LimpioCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: _brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu cupo semanal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: context.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip(
                context,
                label: 'Agendadas',
                value: '${v?.bookedCount ?? '—'}',
                color: _brand,
              ),
              const SizedBox(width: 8),
              _statChip(
                context,
                label: 'Máximo',
                value: '${v?.maxWeekly ?? '—'}',
                color: context.subtitleColor,
              ),
              const SizedBox(width: 8),
              _statChip(
                context,
                label: 'Disponibles',
                value: '${v?.remaining ?? '—'}',
                color: _success,
                highlight: true,
              ),
            ],
          ),
          if (v != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.school_outlined,
                    size: 16, color: context.subtitleColor),
                const SizedBox(width: 6),
                Text(
                  'Nivel: ${v.effectiveLevel}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight
              ? color.withValues(alpha: 0.1)
              : context.isDarkMode
                  ? const Color(0xFF1C2230)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? color.withValues(alpha: 0.25)
                : context.borderColor,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekBar(BuildContext context, ScheduleWeekInfo week) {
    return LimpioCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeWeek(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: _brand.withValues(alpha: 0.08),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      week.dateRangeText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        week.statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _changeWeek(1),
                icon: const Icon(Icons.chevron_right_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: _brand.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goToWeek(0),
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text('Esta semana'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: BorderSide(color: _brand.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _goToWeek(1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Próxima'),
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabs(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: scheduleDayKeys.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = scheduleDayKeys[index];
          final active = key == _activeDay;
          final label = scheduleDayLabels[key] ?? key;
          final short = label.length > 3 ? label.substring(0, 3) : label;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeDay = key);
                },
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? _brand
                        : context.isDarkMode
                            ? const Color(0xFF1C2230)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? _brand : context.borderColor,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _brand.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    short,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: active ? Colors.white : context.textColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: context.subtitleColor),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _loadWeek(forceRefresh: true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDayContent({required Key key}) {
    final day = _view?.days[_activeDay];
    if (day == null || day.slots.isEmpty) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded,
                size: 40, color: context.subtitleColor),
            const SizedBox(height: 12),
            Text(
              'No hay clases disponibles este día.',
              style: TextStyle(color: context.subtitleColor),
            ),
          ],
        ),
      );
    }

    return Column(
      key: key,
      children: [
        for (var i = 0; i < day.slots.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _buildSlotCard(day.slots[i]),
        ],
      ],
    );
  }

  Widget _buildSlotCard(ScheduleSlot slotEntry) {
    return LimpioCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: _brand),
              const SizedBox(width: 8),
              Text(
                slotEntry.slot,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < slotEntry.rooms.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildRoomCard(slotEntry.rooms[i], slotEntry.slot),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomCard(ScheduleRoom room, String slot) {
    final isPending = _pendingRoomId == room.id;
    final capacityColor = room.capacityRatio >= 1
        ? _danger
        : room.capacityRatio >= 0.75
            ? const Color(0xFFE67E22)
            : _success;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: room.isBookedHere
            ? _success.withValues(alpha: 0.06)
            : context.isDarkMode
                ? const Color(0xFF151922)
                : const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: room.isBookedHere
              ? _success.withValues(alpha: 0.35)
              : context.borderColor,
          width: room.isBookedHere ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Salón ${room.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: context.textColor,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: capacityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${room.enrolledCount}/${room.maxCapacity}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: capacityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _metaRow(Icons.person_outline_rounded, room.teacher),
          const SizedBox(height: 4),
          _metaRow(Icons.chat_bubble_outline_rounded, room.classTypeText),
          const SizedBox(height: 4),
          _metaRow(Icons.layers_outlined, room.levelsText),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: room.capacityRatio.clamp(0, 1),
              minHeight: 4,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(capacityColor),
            ),
          ),
          const SizedBox(height: 12),
          _buildRoomAction(room, slot, isPending),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.subtitleColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.subtitleColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomAction(ScheduleRoom room, String slot, bool isPending) {
    if (room.isBookedHere) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _success, size: 18),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Agendado',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _success,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: isPending
                  ? null
                  : () => _onAction(
                        book: false,
                        dayKey: _activeDay,
                        slot: slot,
                        roomId: room.id,
                      ),
              icon: isPending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded, size: 16),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: BorderSide(color: _danger.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      );
    }

    if (room.canBook) {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: FilledButton.icon(
          onPressed: isPending
              ? null
              : () => _onAction(
                    book: true,
                    dayKey: _activeDay,
                    slot: slot,
                    roomId: room.id,
                  ),
          icon: isPending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded, size: 18),
          label: const Text('Agendarme'),
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline_rounded,
            size: 16, color: context.subtitleColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            room.blockMessage,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.subtitleColor,
            ),
          ),
        ),
      ],
    );
  }
}
