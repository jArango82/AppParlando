import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../services/badge_service.dart';
import '../config/course_config.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/achievement_overlay.dart';
import 'exercise_webview_screen.dart';
import '../theme_provider.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with TickerProviderStateMixin {
  static const int _diagnosticCourseId = 9;

  List<dynamic> _sections = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _selectedCategoryIndex = 0;

  // Definición de las categorías de diagnóstico con sus secciones y estilo visual
  // Cada categoría agrupa secciones de Moodle por nivel
  static final List<_DiagnosticCategory> _categories = [
    const _DiagnosticCategory(
      title: 'Nivel A1',
      subtitle: 'Principiante',
      icon: Icons.emoji_events_rounded,
      gradientColors: [Color(0xFF2A60E4), Color(0xFF56CCF2)],
      sectionIds: [0, 1, 2, 3], // Sección 0 agregada aquí
    ),
    const _DiagnosticCategory(
      title: 'Nivel A2',
      subtitle: 'Elemental',
      icon: Icons.trending_up_rounded,
      gradientColors: [Color(0xFF1FAB5E), Color(0xFF56E89C)],
      sectionIds: [4, 5, 6, 7, 8, 9],
    ),
    const _DiagnosticCategory(
      title: 'Nivel B1',
      subtitle: 'Intermedio',
      icon: Icons.rocket_launch_rounded,
      gradientColors: [Color(0xFFE67E22), Color(0xFFF7C948)],
      sectionIds: [10, 11, 12, 13, 14, 15],
    ),
    const _DiagnosticCategory(
      title: 'Nivel B2',
      subtitle: 'Intermedio Alto',
      icon: Icons.star_rounded,
      gradientColors: [Color(0xFF8E44AD), Color(0xFFC66DD8)],
      sectionIds: [16, 17, 18, 19, 20, 21],
    ),
  ];

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
      final data = await CourseService().getCourseDetails(_diagnosticCourseId);
      final sections = data['sections'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _sections = sections;
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

  // Cuenta los módulos completados en una sección
  Map<String, int> _getSectionProgress(Map<String, dynamic> section) {
    final modules = section['modules'] as List<dynamic>? ?? [];
    int total = 0;
    int completed = 0;
    for (var m in modules) {
      total++;
      if (m['completionState'] == 1 ||
          m['completionState'] == 2 ||
          (m['grade'] != null && m['grade'] != '-')) {
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
              fontSize: 20),
        ),
        backgroundColor: context.cardColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: context.bgScaffold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF2A60E4)),
              onPressed: _loadDiagnostics,
              tooltip: 'Actualizar',
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selector de Niveles (Diagnósticos) ──
          if (!_isLoading && !_hasError && _categories.isNotEmpty)
            Container(color: context.cardColor, child: _buildCategoryChips()),
          // ── Cuerpo ──
          Expanded(child: _buildBody()),
        ],
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
    return Container(
      height: 60,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = index == _selectedCategoryIndex;
          final gradient = category.gradientColors;

          return GestureDetector(
            onTap: () {
              if (_selectedCategoryIndex == index) return;
              setState(() => _selectedCategoryIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? context.bgScaffold : Colors.transparent,
                borderRadius: BorderRadius.circular(20), // Aspecto de píldora
                border: Border.all(
                  color: isSelected ? gradient[0] : context.borderColor,
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: gradient[0].withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(
                      category.icon,
                      color: gradient[0],
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    category.title, // Ej: "Nivel A1"
                    style: TextStyle(
                      color: isSelected ? gradient[0] : Colors.grey[500],
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 20),
            const Text(
              'No se pudieron cargar los diagnósticos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDiagnostics,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A60E4),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final category = _categories[_selectedCategoryIndex];
    final gradient = category.gradientColors;

    // Obtenemos las secciones reales de esta categoría
    final List<Map<String, dynamic>> categoryRealSections = [];
    for (var id in category.sectionIds) {
      final section = _getSectionByNumber(id);
      if (section != null) {
        categoryRealSections.add(section);
      }
    }

    // Progreso total de la categoría
    int totalModules = 0;
    int completedModules = 0;
    for (var section in categoryRealSections) {
      final progress = _getSectionProgress(section);
      totalModules += progress['total']!;
      completedModules += progress['completed']!;
    }

    return RefreshIndicator(
      onRefresh: _loadDiagnostics,
      color: gradient[0],
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de módulos completados
            _buildSummaryCard(
              title: category.title,
              value: '$completedModules',
              suffix: ' / $totalModules',
              icon: category.icon,
              iconColor: gradient[0],
              subtitle: category.subtitle,
              subtitleColor: Colors.grey[500]!,
              progress:
                  totalModules > 0 ? completedModules / totalModules : 0.0,
              gradient: gradient,
            ),
            const SizedBox(height: 28),

            // Título de Secciones
            Text(
              'Módulos de Diagnóstico',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Secciones
            if (categoryRealSections.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('No hay diagnósticos disponibles.',
                      style: TextStyle(color: Colors.grey[400])),
                ),
              )
            else
              Column(
                children: categoryRealSections.map((section) {
                  return _buildSectionCard(section, category, context);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? suffix,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
    required Color subtitleColor,
    double? progress,
    List<Color>? gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: context.textColor,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
            ],
          ),
          if (progress != null && gradient != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    context.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(gradient[0]),
                minHeight: 6,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section,
      _DiagnosticCategory category, BuildContext context) {
    final String sectionName =
        section['name']?.toString() ?? 'Sección ${section['section']}';
    final modules = section['modules'] as List<dynamic>? ?? [];
    final progress = _getSectionProgress(section);
    final bool isCompleted =
        progress['total']! > 0 && progress['completed'] == progress['total'];
    final bool hasContent = modules.isNotEmpty;
    final double sectionProgress = progress['total']! > 0
        ? progress['completed']! / progress['total']!
        : 0;

    Color bgColor;
    Color textColor;

    if (isCompleted) {
      bgColor = context.isDarkMode
          ? const Color(0xFF0F3628)
          : const Color(0xFFECFDF5);
      textColor = context.isDarkMode
          ? const Color(0xFF34D399)
          : const Color(0xFF10B981);
    } else if (hasContent && sectionProgress > 0) {
      bgColor = context.isDarkMode
          ? const Color(0xFF3B2A18)
          : const Color(0xFFFFF7ED);
      textColor = context.isDarkMode
          ? const Color(0xFFFDE68A)
          : const Color(0xFFE67E22);
    } else {
      bgColor = context.cardColor;
      textColor = context.textColor;
    }

    return GestureDetector(
      onTap: hasContent ? () => _showSectionDetail(section, category) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCompleted
                  ? textColor.withOpacity(0.3)
                  : context.borderColor),
          boxShadow: [
            if (!isCompleted)
              BoxShadow(
                color: context.shadowColor,
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? textColor.withOpacity(0.15)
                        : hasContent
                            ? category.gradientColors[0].withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : hasContent
                            ? Icons.quiz_rounded
                            : Icons.lock_outline_rounded,
                    color: isCompleted
                        ? textColor
                        : hasContent
                            ? category.gradientColors[0]
                            : Colors.grey[400],
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: hasContent ? textColor : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${progress['completed']} / ${progress['total']} actividades',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted ? textColor : Colors.grey[500],
                          fontWeight:
                              isCompleted ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasContent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? textColor.withOpacity(0.2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: isCompleted
                          ? null
                          : Border.all(color: Colors.grey.withOpacity(0.15)),
                    ),
                    child: Text(
                      '${(sectionProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color:
                            isCompleted ? textColor : const Color(0xFF1A1D26),
                      ),
                    ),
                  ),
              ],
            ),
            if (hasContent && !isCompleted && sectionProgress > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sectionProgress,
                  backgroundColor: textColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  minHeight: 4,
                ),
              ),
            ]
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

      // Recargar datos de diagnósticos (podrían haber cambiado)
      final diagData =
          await courseService.getCourseDetails(_diagnosticCourseId);
      final diagnosticSections = diagData['sections'] as List<dynamic>? ?? [];

      // Actualizar las secciones locales con los datos frescos
      if (mounted) {
        setState(() => _sections = diagnosticSections);
      }

      // Obtener el curso del estudiante para verificar la otra condición
      final courses = await courseService.getCourses();
      if (courses.isEmpty) return;

      // Buscar el primer curso que no sea el de diagnósticos
      courses.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      final mainCourse = courses.firstWhere(
        (c) => c['id'] != _diagnosticCourseId,
        orElse: () => courses.first,
      );
      final int mainCourseId = mainCourse['id'];
      final String shortname = mainCourse['shortname'] ?? '';
      final String fullname = mainCourse['fullname'] ?? '';

      // Obtener secciones del curso principal
      final courseData = await courseService.getCourseDetails(mainCourseId);
      final courseSections = courseData['sections'] as List<dynamic>? ?? [];

      // Obtener config de partes del curso
      final partsConfig =
          CourseConfig.getPartsForCourse(shortname, fullname: fullname);

      // Verificar badges pendientes
      final newBadges = await badgeService.checkForNewBadges(
        courseSections: courseSections,
        coursePartsConfig: partsConfig,
        diagnosticSections: diagnosticSections,
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
    final modules = section['modules'] as List<dynamic>? ?? [];

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
                      color: context.subtitleColor.withOpacity(0.3),
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
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
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
          : Colors.green.withOpacity(0.1);
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
          iconBgColor = category.gradientColors[0].withOpacity(0.1);
          iconColor = category.gradientColors[0];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? (context.isDarkMode
                ? Colors.green.withOpacity(0.05)
                : const Color(0xFFF8FFF8))
            : (context.isDarkMode
                ? Colors.transparent
                : const Color(0xFFFAFBFF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? (context.isDarkMode
                  ? Colors.green.withOpacity(0.15)
                  : Colors.green.withOpacity(0.15))
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
                              ? context.subtitleColor.withOpacity(0.6)
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
                      color: category.gradientColors[0].withOpacity(0.08),
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
  final IconData icon;
  final List<Color> gradientColors;
  final List<int> sectionIds;

  const _DiagnosticCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.sectionIds,
  });
}
