import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../services/badge_service.dart';
import '../config/course_config.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/achievement_overlay.dart';
import 'exercise_webview_screen.dart';

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

  // Definición de las categorías de diagnóstico con sus secciones y estilo visual
  // Cada categoría agrupa secciones de Moodle por nivel
  static final List<_DiagnosticCategory> _categories = [
    _DiagnosticCategory(
      title: 'Nivel A1',
      subtitle: 'Principiante',
      icon: Icons.emoji_events_rounded,
      gradientColors: [const Color(0xFF2A60E4), const Color(0xFF56CCF2)],
      sectionIds: [0, 1, 2, 3], // Sección 0 agregada aquí
    ),
    _DiagnosticCategory(
      title: 'Nivel A2',
      subtitle: 'Elemental',
      icon: Icons.trending_up_rounded,
      gradientColors: [const Color(0xFF1FAB5E), const Color(0xFF56E89C)],
      sectionIds: [4, 5, 6, 7, 8, 9],
    ),
    _DiagnosticCategory(
      title: 'Nivel B1',
      subtitle: 'Intermedio',
      icon: Icons.rocket_launch_rounded,
      gradientColors: [const Color(0xFFE67E22), const Color(0xFFF7C948)],
      sectionIds: [10, 11, 12, 13, 14, 15],
    ),
    _DiagnosticCategory(
      title: 'Nivel B2',
      subtitle: 'Intermedio Alto',
      icon: Icons.star_rounded,
      gradientColors: [const Color(0xFF8E44AD), const Color(0xFFC66DD8)],
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Diagnósticos',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CustomLoadingIndicator(size: 80))
          : _hasError
              ? _buildErrorState()
              : _buildContent(),
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
              child: const Icon(Icons.error_outline, size: 40, color: Colors.red),
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

  Widget _buildContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Espaciado superior inicial para separar del AppBar
        const SliverPadding(padding: EdgeInsets.only(top: 16)),

        // Lista de categorías
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildCategoryCard(_categories[index], index);
              },
              childCount: _categories.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(_DiagnosticCategory category, int categoryIndex) {
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
    final double categoryProgress =
        totalModules > 0 ? completedModules / totalModules : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (categoryIndex * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: category.gradientColors[0].withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header de la categoría con gradiente
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: category.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Icono de la categoría
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  // Título y subtítulo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge de progreso
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(categoryProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Barra de progreso general
            Container(
              height: 4,
              width: double.infinity,
              color: Colors.grey.withOpacity(0.1),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: categoryProgress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: category.gradientColors),
                  ),
                ),
              ),
            ),

            // Grid de secciones
            Padding(
              padding: const EdgeInsets.all(14),
              child: categoryRealSections.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No hay secciones disponibles',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: categoryRealSections.map((section) {
                        return _buildSectionTile(section, category);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile(
      Map<String, dynamic> section, _DiagnosticCategory category) {
    final String sectionName =
        section['name']?.toString() ?? 'Sección ${section['section']}';
    final modules = section['modules'] as List<dynamic>? ?? [];
    final progress = _getSectionProgress(section);
    final bool isCompleted =
        progress['total']! > 0 && progress['completed'] == progress['total'];
    final bool hasContent = modules.isNotEmpty;
    final double sectionProgress =
        progress['total']! > 0 ? progress['completed']! / progress['total']! : 0;

    // Determinamos el ancho disponible para hacer tarjetas adaptativas
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = (screenWidth - 20 * 2 - 14 * 2 - 10) / 2; // 2 columnas

    return GestureDetector(
      onTap: hasContent
          ? () => _showSectionDetail(section, category)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: tileWidth,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFFF0FFF4)
              : hasContent
                  ? const Color(0xFFF8F9FF)
                  : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withOpacity(0.3)
                : hasContent
                    ? category.gradientColors[0].withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono de estado + actividades
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icono de estado
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.15)
                        : category.gradientColors[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : hasContent
                            ? Icons.quiz_rounded
                            : Icons.lock_outline_rounded,
                    color: isCompleted
                        ? Colors.green
                        : hasContent
                            ? category.gradientColors[0]
                            : Colors.grey[400],
                    size: 18,
                  ),
                ),
                if (hasContent)
                  Text(
                    '${progress['completed']}/${progress['total']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? Colors.green
                          : Colors.grey[500],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Nombre de la sección
            Text(
              sectionName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasContent ? const Color(0xFF1A1D2E) : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            // Barra de mini-progreso
            if (hasContent) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: sectionProgress,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : category.gradientColors[0],
                  ),
                  minHeight: 4,
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

      // Recargar datos de diagnósticos (podrían haber cambiado)
      final diagData = await courseService.getCourseDetails(_diagnosticCourseId);
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
      final partsConfig = CourseConfig.getPartsForCourse(shortname, fullname: fullname);

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
      print('Debug: Error verificando badges: $e');
    }
  }

  void _showSectionDetail(
      Map<String, dynamic> section, _DiagnosticCategory category) {
    final String sectionName =
        section['name']?.toString() ?? 'Sección';
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
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
                            gradient: LinearGradient(
                                colors: category.gradientColors),
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
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1D2E),
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
                  Divider(color: Colors.grey[100], height: 1),
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
    final String? grade = module['grade'];

    IconData icon;
    Color iconBgColor;
    Color iconColor;

    if (isCompleted) {
      icon = Icons.check_circle_rounded;
      iconBgColor = Colors.green.withOpacity(0.1);
      iconColor = Colors.green;
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
          iconBgColor = const Color(0xFFF3E5F5);
          iconColor = const Color(0xFF8E44AD);
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
            ? const Color(0xFFF8FFF8)
            : const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.08),
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
                              ? Colors.black45
                              : const Color(0xFF1A1D2E),
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
