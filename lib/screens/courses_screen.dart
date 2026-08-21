import 'package:flutter/material.dart';
import '../services/course_service.dart';
import 'course_details_screen.dart';
import '../widgets/custom_loading_indicator.dart';
import '../theme_provider.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  Future<List<dynamic>>? _coursesFuture;
  final Map<int, Future<Map<String, dynamic>>> _courseProgressFutures = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    setState(() {
      _courseProgressFutures.clear();
      _coursesFuture = CourseService().getCourses().then((courses) {
        for (var c in courses) {
          if (c['id'] != 9 && c['id'] != 10) {
            _courseProgressFutures[c['id']] =
                CourseService().getCourseDetails(c['id']);
          }
        }
        return courses;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgScaffold, // Fondo gris claro moderno / oscuro
      appBar: AppBar(
        title: Text(
          'Mis cursos',
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2A60E4)),
            onPressed: _loadCourses,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoadingIndicator(size: 80));
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Error cargando cursos:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCourses,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes cursos inscritos.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final courses = snapshot.data!
              .where((c) => c['id'] != 9 && c['id'] != 10)
              .toList();

          final bool isWide = context.isWideScreen;

          if (isWide) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 500,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _buildCourseCard(course, context);
                  },
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _buildCourseCard(course, context);
            },
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(dynamic course, BuildContext context) {
    final String fullname = course['fullname'] ?? 'Curso Desconocido';
    final String rawShortname = course['shortname'] ?? '';
    final int courseId = course['id'];

    // Extraemos el nivel real del nombre completo (ej. "Curso Ingles A1" → "A1")
    // Esto se usa para asignar la imagen y el color temático
    String displayLevel = rawShortname;
    final combined = '$fullname $rawShortname';
    if (combined.contains('A1')) {
      displayLevel = 'A1';
    } else if (combined.contains('A2')) {
      displayLevel = 'A2';
    } else if (combined.contains('B1')) {
      displayLevel = 'B1';
    } else if (combined.contains('B2')) {
      displayLevel = 'B2';
    }

    // Determinamos el color de acento basado en el nivel
    Color accentColor = Colors.blue;
    if (displayLevel == 'A1') {
      accentColor = const Color(0xFF2A60E4);
    } else if (displayLevel == 'A2') {
      accentColor = const Color(0xFF1FAB5E);
    } else if (displayLevel == 'B1') {
      accentColor = const Color(0xFFE67E22);
    } else if (displayLevel == 'B2') {
      accentColor = const Color(0xFF8E44AD);
    }

    return Container(
      margin: context.isWideScreen ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner con imagen del curso
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                // Imagen de fondo (correspondiente al nivel)
                Image.asset(
                  'assets/$displayLevel.webp',
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    width: double.infinity,
                    color: accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.school,
                        size: 48, color: accentColor.withValues(alpha: 0.3)),
                  ),
                ),
                // Gradiente superpuesto para mejorar legibilidad del texto
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                // Etiqueta de Nivel + Título sobre la imagen
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'NIVEL $displayLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    fullname,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progreso y Botón de Acción
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (true) ...[
                  FutureBuilder<Map<String, dynamic>>(
                    future: _courseProgressFutures[courseId],
                    builder: (context, detailSnap) {
                      if (detailSnap.connectionState ==
                          ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              backgroundColor: context.isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accentColor),
                              minHeight: 8,
                            ),
                          ),
                        );
                      }

                      if (!detailSnap.hasData) return const SizedBox.shrink();

                      final sections =
                          detailSnap.data!['sections'] as List<dynamic>? ?? [];
                      int totalValid = 0;
                      int completedValid = 0;
                      for (var s in sections) {
                        final modules = s['modules'] as List<dynamic>? ?? [];
                        for (var m in modules) {
                          final name =
                              m['name']?.toString().toLowerCase() ?? '';
                          if (name.contains('video')) continue;
                          totalValid++;
                          if (m['completionState'] == 1 ||
                              m['completionState'] == 2) {
                            completedValid++;
                          }
                        }
                      }
                      final double progress = totalValid > 0
                          ? (completedValid / totalValid * 100)
                          : 0;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progreso',
                                style: TextStyle(
                                  color: context.subtitleColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${progress.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (progress / 100).clamp(0.0, 1.0),
                              backgroundColor: context.isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accentColor),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CourseDetailsScreen(course: course),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continuar Aprendiendo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
