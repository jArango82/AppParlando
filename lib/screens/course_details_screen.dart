import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../services/badge_service.dart';
import '../config/course_config.dart';
import '../utils/module_filters.dart';
import '../widgets/achievement_overlay.dart';
import 'exercise_webview_screen.dart';
import '../widgets/custom_loading_indicator.dart';
import '../theme_provider.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> course;

  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  Future<Map<String, dynamic>>? _detailsFuture;
  Map<String, dynamic> _partsConfig = {};
  List<MapEntry<String, dynamic>> _partsList = [];
  int _currentPartIndex = 0;
  int?
      _expandedTopicIndex; // Indica qué tema está expandido actualmente en la lista.

  late Color _accentColor;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadConfig();
    _resolveAccentColor();
    // Verificamos badges al entrar, por si ya cumplió requisitos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowBadges();
    });
  }

  void _loadDetails() {
    _detailsFuture = CourseService().getCourseDetails(widget.course['id']);
  }

  /// Verifica si se ganaron badges despues de regresar de un ejercicio.
  Future<void> _checkAndShowBadges() async {
    try {
      final courseService = CourseService();
      final badgeService = BadgeService();

      // Diagnósticos viven en el mismo curso del nivel
      final courseData =
          await courseService.getCourseDetails(widget.course['id']);
      final courseSections = courseData['sections'] as List<dynamic>? ?? [];
      final diagnosticSections = courseSections;

      // Refrescar la UI del curso
      if (mounted) {
        setState(() {
          _detailsFuture = Future.value(courseData);
        });
      }

      // Obtener config de partes
      final shortname = widget.course['shortname'] ?? '';
      final fullname = widget.course['fullname'] ?? '';
      final partsConfig =
          CourseConfig.getPartsForCourse(shortname, fullname: fullname);

      // Verificar badges
      final newBadges = await badgeService.checkForNewBadges(
        courseSections: courseSections,
        coursePartsConfig: partsConfig,
        diagnosticSections: diagnosticSections,
      );

      if (mounted && newBadges.isNotEmpty) {
        for (var badge in newBadges) {
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

          await badgeService.markBadgeShown(badge.id);
        }
      }
    } catch (e) {
      debugPrint('Debug CourseDetails: Error verificando badges: $e');
    }
  }

  void _loadConfig() {
    final shortname = widget.course['shortname'] ?? '';
    final fullname = widget.course['fullname'] ?? '';
    debugPrint(
        'Depuración CourseDetails: shortname="$shortname" fullname="$fullname"');
    _partsConfig =
        CourseConfig.getPartsForCourse(shortname, fullname: fullname);
    _partsList = _partsConfig.entries.toList();
    debugPrint(
        'Depuración CourseDetails: Se encontraron ${_partsList.length} partes');
  }

  void _resolveAccentColor() {
    final combined =
        '${widget.course['fullname'] ?? ''} ${widget.course['shortname'] ?? ''}';
    if (combined.contains('A1')) {
      _accentColor = const Color(0xFF2A60E4);
    } else if (combined.contains('A2')) {
      _accentColor = const Color(0xFF1FAB5E);
    } else if (combined.contains('B1')) {
      _accentColor = const Color(0xFFE67E22);
    } else if (combined.contains('B2')) {
      _accentColor = const Color(0xFF8E44AD);
    } else {
      _accentColor = const Color(0xFF2A60E4);
    }
  }

  void _nextPart() {
    if (_currentPartIndex < _partsList.length - 1) {
      setState(() {
        _currentPartIndex++;
        _expandedTopicIndex = null;
      });
    }
  }

  void _prevPart() {
    if (_currentPartIndex > 0) {
      setState(() {
        _currentPartIndex--;
        _expandedTopicIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgScaffold,
      appBar: AppBar(
        title: Text(
          widget.course['fullname'] ?? 'Curso',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: context.textColor),
        ),
        backgroundColor: context.cardColor,
        foregroundColor: context.textColor,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.borderColor, height: 1),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoadingIndicator(size: 80));
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text('Error cargando detalles: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.subtitleColor)),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(
                child: Text('No hay contenido disponible',
                    style: TextStyle(color: context.subtitleColor)));
          }

          final sections = snapshot.data!['sections'] as List<dynamic>;

          if (_partsList.isEmpty) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: sections.length,
                  itemBuilder: (context, i) => _buildTopicCard(sections[i], i),
                ),
              ),
            );
          }

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _buildPartView(sections),
            ),
          );
        },
      ),
    );
  }

  // ── VISTA DE PARTES ──────────────────────────────────────────────

  Widget _buildPartView(List<dynamic> allSections) {
    final currentEntry = _partsList[_currentPartIndex];
    final partName = currentEntry.key;
    final config = currentEntry.value;
    final List<int> allowedIds = List<int>.from(config['ids']);

    // Imprimimos todos los IDs de sección para entender los datos que recibimos
    if (_currentPartIndex == 0) {
      for (var s in allSections) {
        final modules = s['modules'] as List<dynamic>? ?? [];
        debugPrint(
            'Depuración Sección: id=${s['id']} section=${s['section']} name="${s['name']}" modules=${modules.length}');
      }
      debugPrint('Depuración AllowedIds para "$partName": $allowedIds');
    }

    // Filtramos por número de 'section' (concepto lógico de orden),
    // no por 'id' que es la llave primaria en la base de datos.
    // También omitimos secciones que no tengan módulos (contenido vacío).
    final partSections = allSections.where((s) {
      final sectionNum = int.tryParse(s['section'].toString());
      final modules = s['modules'] as List<dynamic>? ?? [];
      return sectionNum != null &&
          allowedIds.contains(sectionNum) &&
          modules.isNotEmpty;
    }).toList();

    // Cálculo del progreso: SOLO módulos con "ejercicio" en el nombre
    int completedCount = 0;
    int exerciseCount = 0;
    for (var s in partSections) {
      if (s['modules'] != null) {
        for (var m in s['modules']) {
          final name = m['name']?.toString().toLowerCase() ?? '';
          if (isVideoModule(m)) continue;
          if (!name.contains('ejercicio')) continue;

          exerciseCount++;
          if (isModuleCompleted(m)) {
            completedCount++;
          }
        }
      }
    }
    final double progress = exerciseCount > 0
        ? (completedCount / exerciseCount).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        // Banner Principal de la Parte
        _buildPartBanner(partName, progress, completedCount, exerciseCount,
            partSections.length),

        // Lista de Temas (Scrollable)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            itemCount: partSections.length,
            itemBuilder: (context, i) => _buildTopicCard(partSections[i], i),
          ),
        ),

        // Barra de Navegación Inferior
        _buildBottomNav(),
      ],
    );
  }

  // ── BANNER DE PARTE ────────────────────────────────────────────

  Widget _buildPartBanner(String partName, double progress, int completed,
      int total, int topicCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentColor, _accentColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _accentColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Parte ${_currentPartIndex + 1} de ${_partsList.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.topic_outlined,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$topicCount temas',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(partName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TARJETA DE TEMA (expandible) ────────────────────────────────

  Widget _buildTopicCard(dynamic section, int index) {
    final modules = modulesWithoutVideo(
        section['modules'] as List<dynamic>? ?? []);
    if (modules.isEmpty) return const SizedBox.shrink();

    final sectionName = section['name']?.toString() ?? 'Tema ${index + 1}';
    final bool isExpanded = _expandedTopicIndex == index;

    // Solo contamos módulos con "ejercicio" en el nombre (sin videos)
    final validModules = modules.where((m) {
      return isCountableExercise(m);
    }).toList();

    // Contamos las actividades completadas dentro de este tema específico
    int topicCompleted = 0;
    for (var m in validModules) {
      if (m['completionState'] == 1 || m['completionState'] == 2) {
        topicCompleted++;
      }
    }

    // Para determinar si "todo está hecho", usamos solo las actividades válidas
    // Si no hay actividades válidas (todo videos), consideramos "hecho"
    // si el usuario ha visto al menos el contenido, pero visualmente marcamos check.
    // OJO: Si solo hay videos, validModules.isEmpty es true.
    final bool allDone =
        validModules.isNotEmpty && topicCompleted == validModules.length;
    // Si queremos mantener la barra llena incluso si son solo videos:
    // final double progressValue = validModules.isNotEmpty ? topicCompleted / validModules.length : (modules.isNotEmpty ? 1.0 : 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? _accentColor.withValues(alpha: 0.3)
              : allDone
                  ? Colors.green.withValues(alpha: 0.25)
                  : context.borderColor,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: isExpanded ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Encabezado del tema (se puede tocar para expandir)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedTopicIndex = isExpanded ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Insignia con el número del tema
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: allDone
                            ? Colors.green.withValues(alpha: 0.1)
                            : _accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: allDone
                            ? const Icon(Icons.check_rounded,
                                color: Colors.green, size: 20)
                            : Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  color: _accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Título y barra de progreso pequeña
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sectionName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: allDone
                                  ? context.subtitleColor
                                  : context.textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Mini barra de progreso
                              SizedBox(
                                width: 60,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: validModules.isNotEmpty
                                        ? topicCompleted / validModules.length
                                        : 0,
                                    backgroundColor: context.isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      allDone ? Colors.green : _accentColor,
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$topicCompleted/${validModules.length}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Icono de expansión (flecha)
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.subtitleColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Lista de ejercicios desplegada
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Container(
                          height: 1,
                          color: context.borderColor,
                          margin: const EdgeInsets.only(bottom: 10),
                        ),
                        ...modules.map((m) => _buildExerciseItem(m)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── ITEM DE EJERCICIO (dentro del tema expandido) ──────────────────

  Widget _buildExerciseItem(dynamic module) {
    bool isCompleted =
        module['completionState'] == 1 || module['completionState'] == 2;
    String? grade = module['grade'];

    // Check original grade to determine completion if needed
    if (grade != null && grade != '-') {
      isCompleted = true;
    }

    IconData icon;
    Color iconColor;
    final modname = module['modname'] ?? '';

    if (isCompleted) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else {
      switch (modname) {
        case 'quiz':
          icon = Icons.quiz_outlined;
          iconColor = const Color(0xFFE67E22);
          break;
        case 'h5pactivity':
          icon = Icons.games_outlined;
          iconColor = const Color(0xFF00897B);
          break;
        case 'assign':
          icon = Icons.assignment_outlined;
          iconColor = const Color(0xFF8E44AD);
          break;
        case 'scorm':
          icon = Icons.extension_outlined;
          iconColor = const Color(0xFF2E7D32);
          break;
        default:
          icon = Icons.play_circle_outline;
          iconColor = _accentColor;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final url = module['url'];
          if (url != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ExerciseWebViewScreen(
                        title: module['name'] ?? 'Ejercicio',
                        url: url,
                      )),
            ).then((_) => _checkAndShowBadges());
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module['name'] ?? 'Actividad',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color:
                        isCompleted ? context.subtitleColor : context.textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isCompleted)
                Icon(Icons.arrow_forward_ios,
                    color: Colors.grey[300], size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ── NAVEGACIÓN INFERIOR ──────────────────────────────────────────────

  Widget _buildBottomNav() {
    final bool hasPrev = _currentPartIndex > 0;
    final bool hasNext = _currentPartIndex < _partsList.length - 1;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: context.cardColor,
          boxShadow: [
            BoxShadow(
                color: context.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            if (hasPrev)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prevPart,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('Anterior',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentColor,
                    side: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            if (hasPrev && hasNext) const SizedBox(width: 12),
            if (hasNext)
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextPart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Siguiente Parte',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ),
              ),
            if (!hasNext && hasPrev) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Última Parte',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],
            if (!hasNext && !hasPrev)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Última Parte',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
