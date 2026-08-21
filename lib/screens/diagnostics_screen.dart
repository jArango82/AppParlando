import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../services/badge_service.dart';
import '../config/course_config.dart';
import '../utils/module_filters.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/achievement_overlay.dart';
import '../widgets/limpio_card.dart';
import 'exercise_webview_screen.dart';
import '../theme_provider.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with TickerProviderStateMixin {
  /// Secciones Moodle por nivel (A1/A2/B1/B2).
  final Map<String, List<dynamic>> _sectionsByLevel = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _selectedCategoryIndex = 0;

  static final List<_DiagnosticCategory> _categories = [
    _DiagnosticCategory(
      title: 'Nivel A1',
      subtitle: 'Principiante',
      levelKey: 'A1',
      icon: Icons.emoji_events_rounded,
      gradientColors: const [Color(0xFF2A60E4), Color(0xFF56CCF2)],
      courseId: DiagnosticConfig.levels['A1']!.courseId,
      sectionIds: DiagnosticConfig.levels['A1']!.sectionIds,
    ),
    _DiagnosticCategory(
      title: 'Nivel A2',
      subtitle: 'Elemental',
      levelKey: 'A2',
      icon: Icons.trending_up_rounded,
      gradientColors: const [Color(0xFF1FAB5E), Color(0xFF56E89C)],
      courseId: DiagnosticConfig.levels['A2']!.courseId,
      sectionIds: DiagnosticConfig.levels['A2']!.sectionIds,
    ),
    _DiagnosticCategory(
      title: 'Nivel B1',
      subtitle: 'Intermedio',
      levelKey: 'B1',
      icon: Icons.rocket_launch_rounded,
      gradientColors: const [Color(0xFFE67E22), Color(0xFFF7C948)],
      courseId: DiagnosticConfig.levels['B1']!.courseId,
      sectionIds: DiagnosticConfig.levels['B1']!.sectionIds,
    ),
    _DiagnosticCategory(
      title: 'Nivel B2',
      subtitle: 'Intermedio Alto',
      levelKey: 'B2',
      icon: Icons.star_rounded,
      gradientColors: const [Color(0xFF8E44AD), Color(0xFFC66DD8)],
      courseId: DiagnosticConfig.levels['B2']!.courseId,
      sectionIds: DiagnosticConfig.levels['B2']!.sectionIds,
    ),
  ];

  List<dynamic> get _sections =>
      _sectionsByLevel[_categories[_selectedCategoryIndex].levelKey] ??
      const [];

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final courseService = CourseService();
      final results = await Future.wait(
        _categories.map(
          (c) => courseService.getCourseDetails(c.courseId),
        ),
      );

      if (mounted) {
        setState(() {
          for (var i = 0; i < _categories.length; i++) {
            _sectionsByLevel[_categories[i].levelKey] =
                results[i]['sections'] as List<dynamic>? ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // Obtiene una sección de Moodle por su número de sección
  Map<String, dynamic>? _getSectionByNumber(int sectionNum) {
    for (var s in _sections) {
      final num = int.tryParse(s['section'].toString());
      if (num == sectionNum) return s as Map<String, dynamic>;
    }
    return null;
  }

  // Cuenta los módulos completados en una sección (omite videos)
  Map<String, int> _getSectionProgress(Map<String, dynamic> section) {
    final modules = modulesWithoutVideo(
        section['modules'] as List<dynamic>? ?? []);
    int total = 0;
    int completed = 0;
    for (var m in modules) {
      total++;
      if (isModuleCompleted(m)) {
        completed++;
      }
    }
    return {'total': total, 'completed': completed};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgScaffold,
      appBar: AppBar(
        title: Text(
          'Diagnósticos',
          style: TextStyle(
            color: context.textColor,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        backgroundColor: context.bgScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: LimpioTokens.brand),
            onPressed: _loadDiagnostics,
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isLoading && !_hasError && _categories.isNotEmpty)
                _buildCategoryChips(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CustomLoadingIndicator(size: 80));
    }
    if (_hasError) {
      return _buildErrorState();
    }
    return _buildDashboard();
  }

  // ══════════════════════════════════════════════════════════════════
  //  CATEGORY CHIPS (Niveles)
  // ══════════════════════════════════════════════════════════════════

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = _categories[index];
            final selected = index == _selectedCategoryIndex;
            final color = category.gradientColors[0];

            return Material(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : context.cardColor,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (_selectedCategoryIndex == index) return;
                  setState(() => _selectedCategoryIndex = index);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? color : context.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        Icon(category.icon, size: 16, color: color),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        category.levelKey,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: selected ? color : context.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: LimpioTokens.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 36, color: LimpioTokens.danger),
            ),
            const SizedBox(height: 20),
            Text(
              'No se pudieron cargar los diagnósticos',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: context.subtitleColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadDiagnostics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: LimpioTokens.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final category = _categories[_selectedCategoryIndex];
    final color = category.gradientColors[0];

    final List<Map<String, dynamic>> categoryRealSections = [];
    for (var id in category.sectionIds) {
      final section = _getSectionByNumber(id);
      if (section != null) {
        categoryRealSections.add(section);
      }
    }

    int totalModules = 0;
    int completedModules = 0;
    for (var section in categoryRealSections) {
      final progress = _getSectionProgress(section);
      totalModules += progress['total']!;
      completedModules += progress['completed']!;
    }
    final progress =
        totalModules > 0 ? completedModules / totalModules : 0.0;

    return RefreshIndicator(
      onRefresh: _loadDiagnostics,
      color: color,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          LimpioCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(category.icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.textColor,
                            ),
                          ),
                          Text(
                            category.subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$completedModules/$totalModules',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.12),
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalModules == 0
                      ? 'Sin actividades aún'
                      : '${(progress * 100).round()}% completado',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Partes de diagnóstico',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completa cada parte para avanzar en tu nivel.',
            style: TextStyle(fontSize: 14, color: context.subtitleColor),
          ),
          const SizedBox(height: 14),
          if (categoryRealSections.isEmpty)
            LimpioCard(
              child: Text(
                'No hay diagnósticos disponibles.',
                style: TextStyle(color: context.subtitleColor),
              ),
            )
          else
            ...List.generate(categoryRealSections.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSectionCard(
                  categoryRealSections[i],
                  category,
                  context,
                  partIndex: i + 1,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    Map<String, dynamic> section,
    _DiagnosticCategory category,
    BuildContext context, {
    required int partIndex,
  }) {
    final String rawName =
        section['name']?.toString() ?? 'Sección ${section['section']}';
    final modules = modulesWithoutVideo(
        section['modules'] as List<dynamic>? ?? []);
    final progress = _getSectionProgress(section);
    final bool isCompleted =
        progress['total']! > 0 && progress['completed'] == progress['total'];
    final bool hasContent = modules.isNotEmpty;
    final double sectionProgress = progress['total']! > 0
        ? progress['completed']! / progress['total']!
        : 0;
    final color = category.gradientColors[0];

    final statusColor = isCompleted
        ? LimpioTokens.success
        : (hasContent && sectionProgress > 0)
            ? LimpioTokens.warning
            : color;

    return LimpioCard(
      onTap: hasContent ? () => _showSectionDetail(section, category) : null,
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: hasContent ? 1 : 0.55,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : hasContent
                            ? (sectionProgress > 0
                                ? Icons.play_circle_fill_rounded
                                : Icons.quiz_rounded)
                            : Icons.lock_outline_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parte $partIndex',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        rawName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasContent
                            ? '${progress['completed']}/${progress['total']} actividades'
                            : 'Sin contenido',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LimpioTokens.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Hecho',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: LimpioTokens.success,
                      ),
                    ),
                  )
                else if (hasContent && sectionProgress > 0)
                  Text(
                    '${(sectionProgress * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      fontSize: 14,
                    ),
                  )
                else if (hasContent)
                  Icon(Icons.chevron_right_rounded,
                      color: context.subtitleColor),
              ],
            ),
            if (hasContent && !isCompleted && sectionProgress > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sectionProgress,
                  minHeight: 6,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  color: statusColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Verifica si hay nuevos badges ganados y muestra la animación.
  // Se ejecuta después de cerrar el bottom sheet de una sección.
  Future<void> _checkAndShowBadges() async {
    try {
      final courseService = CourseService();
      final badgeService = BadgeService();
      final category = _categories[_selectedCategoryIndex];

      // Recargar el curso del nivel actual (diagnósticos = secciones de ese curso)
      final courseData =
          await courseService.getCourseDetails(category.courseId);
      final sections = courseData['sections'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _sectionsByLevel[category.levelKey] = sections;
        });
      }

      final String shortname = 'Inglés ${category.levelKey}';
      final String fullname = category.title;

      final partsConfig =
          CourseConfig.getPartsForCourse(shortname, fullname: fullname);

      // Mismo curso: progreso de partes + secciones de diagnóstico
      final newBadges = await badgeService.checkForNewBadges(
        courseSections: sections,
        coursePartsConfig: partsConfig,
        diagnosticSections: sections,
      );

      // Mostrar las insignias ganadas (una por una)
      if (mounted && newBadges.isNotEmpty) {
        for (var badge in newBadges) {
          // Determinar los colores del gradiente según el nivel
          List<Color> colors;
          switch (badge.level) {
            case 'A1':
              colors = [const Color(0xFF2A60E4), const Color(0xFF56CCF2)];
              break;
            case 'A2':
              colors = [const Color(0xFF1FAB5E), const Color(0xFF56E89C)];
              break;
            case 'B1':
              colors = [const Color(0xFFE67E22), const Color(0xFFF7C948)];
              break;
            case 'B2':
              colors = [const Color(0xFF8E44AD), const Color(0xFFC66DD8)];
              break;
            default:
              colors = [const Color(0xFF2A60E4), const Color(0xFF56CCF2)];
          }

          if (!mounted) continue;
          await AchievementOverlay.show(
            context,
            badgeAssetPath: badge.assetPath,
            title: badge.title,
            subtitle: badge.subtitle,
            gradientColors: colors,
          );

          // Marcar como mostrado para no repetir
          await badgeService.markBadgeShown(badge.id);
        }
      }
    } catch (e) {
      debugPrint('Debug: Error verificando badges: $e');
    }
  }

  void _showSectionDetail(
      Map<String, dynamic> section, _DiagnosticCategory category) {
    final String sectionName = section['name']?.toString() ?? 'Sección';
    final modules = modulesWithoutVideo(
        section['modules'] as List<dynamic>? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.subtitleColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header del bottom sheet
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: category.gradientColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(category.icon,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sectionName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: context.textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${modules.length} actividades',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: context.borderColor, height: 1),
                  // Lista de módulos/actividades
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        return _buildModuleItem(
                            modules[index], category, index);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // Verificar si se ganó alguna insignia al cerrar el bottom sheet
      _checkAndShowBadges();
    });
  }

  Widget _buildModuleItem(
      dynamic module, _DiagnosticCategory category, int index) {
    final String name = module['name'] ?? 'Actividad';
    final String? url = module['url'];
    final String modname = module['modname'] ?? '';
    final bool isCompleted = module['completionState'] == 1 ||
        module['completionState'] == 2 ||
        (module['grade'] != null && module['grade'] != '-');

    IconData icon;
    Color iconBgColor;
    Color iconColor;

    if (isCompleted) {
      icon = Icons.check_circle_rounded;
      iconBgColor = context.isDarkMode
          ? const Color(0xFF0F3628)
          : Colors.green.withValues(alpha: 0.1);
      iconColor = context.isDarkMode ? const Color(0xFF34D399) : Colors.green;
    } else {
      switch (modname) {
        case 'quiz':
          icon = Icons.quiz_rounded;
          iconBgColor = const Color(0xFFFFF3E0);
          iconColor = const Color(0xFFE67E22);
          break;
        case 'h5pactivity':
          icon = Icons.games_rounded;
          iconBgColor = const Color(0xFFE0F2F1);
          iconColor = const Color(0xFF00897B);
          break;
        case 'assign':
          icon = Icons.assignment_rounded;
          iconBgColor = context.isDarkMode
              ? const Color(0xFF38164A)
              : const Color(0xFFF3E5F5);
          iconColor = context.isDarkMode
              ? const Color(0xFFD8B4E2)
              : const Color(0xFF8E44AD);
          break;
        default:
          icon = Icons.play_circle_rounded;
          iconBgColor = category.gradientColors[0].withValues(alpha: 0.1);
          iconColor = category.gradientColors[0];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? (context.isDarkMode
                ? Colors.green.withValues(alpha: 0.05)
                : const Color(0xFFF8FFF8))
            : (context.isDarkMode
                ? Colors.transparent
                : const Color(0xFFFAFBFF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? (context.isDarkMode
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15))
              : context.borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: url != null
              ? () {
                  Navigator.pop(context); // Cierra el bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseWebViewScreen(
                        title: name,
                        url: url,
                      ),
                    ),
                  ).then((_) => _checkAndShowBadges());
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icono
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Nombre y nota
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? context.subtitleColor.withValues(alpha: 0.6)
                              : context.textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Flecha
                if (!isCompleted && url != null)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: category.gradientColors[0].withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: category.gradientColors[0],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modelo de datos para categorías de diagnóstico
class _DiagnosticCategory {
  final String title;
  final String subtitle;
  final String levelKey;
  final IconData icon;
  final List<Color> gradientColors;
  final int courseId;
  final List<int> sectionIds;

  const _DiagnosticCategory({
    required this.title,
    required this.subtitle,
    required this.levelKey,
    required this.icon,
    required this.gradientColors,
    required this.courseId,
    required this.sectionIds,
  });
}
