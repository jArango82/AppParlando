import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../config/course_config.dart';
import '../widgets/custom_loading_indicator.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool _isLoading = true;
  String? _error;

  // Cursos del estudiante (filtrados)
  List<Map<String, dynamic>> _courses = [];
  int _selectedCourseIndex = 0;

  // Datos del curso seleccionado
  Map<String, dynamic>? _courseDetails;
  bool _isLoadingDetails = false;

  // Partes expandidas (índice de la parte)
  int? _expandedPartIndex;

  // Gradientes por nivel
  static const Map<String, List<Color>> _levelGradients = {
    'A1': [Color(0xFF2A60E4), Color(0xFF56CCF2)],
    'A2': [Color(0xFF1FAB5E), Color(0xFF56E89C)],
    'B1': [Color(0xFFE67E22), Color(0xFFF7C948)],
    'B2': [Color(0xFF8E44AD), Color(0xFFC66DD8)],
  };

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final courses = await CourseService().getCourses();

      // Filtrar: solo cursos de nivel (A1, A2, B1, B2), sin exámenes ni diagnósticos
      final filtered = courses
          .cast<Map<String, dynamic>>()
          .where((c) {
            final name = (c['fullname'] ?? '').toString().toLowerCase();
            return !name.contains('examen') &&
                !name.contains('diagnóstico') &&
                !name.contains('diagnostico');
          })
          .toList();

      // Ordenar por nivel
      filtered.sort((a, b) {
        final pa = _getCoursePriority(a['fullname'] ?? '');
        final pb = _getCoursePriority(b['fullname'] ?? '');
        if (pa != pb) return pa.compareTo(pb);
        return (b['id'] as int).compareTo(a['id'] as int);
      });

      setState(() {
        _courses = filtered;
        _isLoading = false;
        _selectedCourseIndex = 0;
      });

      if (filtered.isNotEmpty) {
        _loadCourseDetails(filtered[0]['id']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error cargando cursos: $e';
      });
    }
  }

  int _getCoursePriority(String name) {
    final n = name.toUpperCase();
    if (n.contains('A1')) return 0;
    if (n.contains('A2')) return 1;
    if (n.contains('B1')) return 2;
    if (n.contains('B2')) return 3;
    return 4;
  }

  Future<void> _loadCourseDetails(int courseId) async {
    setState(() {
      _isLoadingDetails = true;
      _expandedPartIndex = null;
    });

    try {
      final details = await CourseService().getCourseDetails(courseId);
      if (mounted) {
        setState(() {
          _courseDetails = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _courseDetails = null;
        });
      }
    }
  }

  String _detectLevel(String name) {
    final n = name.toUpperCase();
    if (n.contains('A1')) return 'A1';
    if (n.contains('A2')) return 'A2';
    if (n.contains('B1')) return 'B1';
    if (n.contains('B2')) return 'B2';
    return 'A1';
  }

  List<Color> _getGradient(String level) {
    return _levelGradients[level] ?? _levelGradients['A1']!;
  }

  // Limpia tags HTML
  String _cleanHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Mis Notas',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadCourses,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selector de Cursos ──
          if (!_isLoading && _error == null && _courses.isNotEmpty)
            _buildCourseChips(),
          // ── Cuerpo ──
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  COURSE CHIPS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildCourseChips() {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          final isSelected = index == _selectedCourseIndex;
          final level = _detectLevel(course['fullname'] ?? '');
          final gradient = _getGradient(level);

          return GestureDetector(
            onTap: () {
              if (_selectedCourseIndex == index) return;
              setState(() => _selectedCourseIndex = index);
              _loadCourseDetails(course['id']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.15)),
                boxShadow: isSelected
                    ? [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Center(
                child: Text(
                  level,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  BODY
  // ══════════════════════════════════════════════════════════════════

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CustomLoadingIndicator(size: 80));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadCourses,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A60E4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay cursos disponibles', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    if (_isLoadingDetails) {
      return const Center(child: CustomLoadingIndicator(size: 60));
    }

    if (_courseDetails == null) {
      return Center(
        child: Text('Selecciona un curso', style: TextStyle(color: Colors.grey[400])),
      );
    }

    return _buildPartsAccordion();
  }

  // ══════════════════════════════════════════════════════════════════
  //  PARTS ACCORDION
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPartsAccordion() {
    final course = _courses[_selectedCourseIndex];
    final shortname = course['shortname'] ?? '';
    final fullname = course['fullname'] ?? '';
    final level = _detectLevel(fullname);
    final gradient = _getGradient(level);

    final partsConfig = CourseConfig.getPartsForCourse(shortname, fullname: fullname);
    final sections = _courseDetails!['sections'] as List<dynamic>? ?? [];

    if (partsConfig.isEmpty) {
      return Center(
        child: Text('Sin configuración de partes', style: TextStyle(color: Colors.grey[400])),
      );
    }

    final partEntries = partsConfig.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: partEntries.length,
      itemBuilder: (context, partIndex) {
        final partName = partEntries[partIndex].key;
        final config = partEntries[partIndex].value;
        final allowedIds = List<int>.from(config['ids']);
        final isExpanded = _expandedPartIndex == partIndex;

        // Filtrar secciones de esta parte
        final partSections = sections.where((s) {
          final sNum = int.tryParse(s['section'].toString());
          return sNum != null && allowedIds.contains(sNum);
        }).toList();

        // Calcular stats (solo ejercicios)
        int totalExercises = 0;
        int completedExercises = 0;
        int gradedCount = 0;
        double gradeSum = 0;

        for (var s in partSections) {
          final modules = s['modules'] as List<dynamic>? ?? [];
          for (var m in modules) {
            final name = m['name']?.toString().toLowerCase() ?? '';
            if (!name.contains('ejercicio')) continue;

            totalExercises++;
            if (m['completionState'] == 1 || m['completionState'] == 2) {
              completedExercises++;
            }
            if (m['grade'] != null && m['grade'] != '-') {
              final raw = _cleanHtml(m['grade'].toString())
                  .replaceAll(',', '.')
                  .replaceAll(RegExp(r'[^0-9.]'), ''); // quitar %, espacios, etc.
              final gradeVal = double.tryParse(raw);
              if (gradeVal != null) {
                gradedCount++;
                gradeSum += gradeVal;
              }
            }
          }
        }

        final double progress = totalExercises > 0
            ? (completedExercises / totalExercises).clamp(0.0, 1.0)
            : 0.0;

        final String avgGrade = gradedCount > 0
            ? (gradeSum / gradedCount).toStringAsFixed(1)
            : '—';

        return _buildPartCard(
          partIndex: partIndex,
          partName: partName,
          isExpanded: isExpanded,
          gradient: gradient,
          level: level,
          progress: progress,
          completed: completedExercises,
          total: totalExercises,
          avgGrade: avgGrade,
          partSections: partSections,
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  PART CARD (ACCORDION)
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPartCard({
    required int partIndex,
    required String partName,
    required bool isExpanded,
    required List<Color> gradient,
    required String level,
    required double progress,
    required int completed,
    required int total,
    required String avgGrade,
    required List<dynamic> partSections,
  }) {
    final bool isDone = total > 0 && completed >= total;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? gradient[0].withOpacity(0.35)
              : isDone
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? gradient[0].withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: isExpanded ? 16 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header (tap to expand) ──
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedPartIndex = isExpanded ? null : partIndex;
                });
              },
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Icono de estado
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: isDone
                                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                                : LinearGradient(colors: [gradient[0].withOpacity(0.15), gradient[1].withOpacity(0.1)]),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                : Text(
                                    '${partIndex + 1}',
                                    style: TextStyle(
                                      color: gradient[0],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Nombre + stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1A1D26),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _buildMiniStat(Icons.task_alt_rounded, '$completed/$total', Colors.grey[600]!),
                                  const SizedBox(width: 14),
                                  _buildMiniStat(Icons.star_rounded, avgGrade, const Color(0xFFE67E22)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Porcentaje
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFFECFDF5)
                                : gradient[0].withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              color: isDone ? const Color(0xFF10B981) : gradient[0],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 22),
                        ),
                      ],
                    ),
                    // Barra de progreso
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(isDone ? const Color(0xFF10B981) : gradient[0]),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded Content ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? _buildExpandedContent(partSections, gradient)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  EXPANDED CONTENT (Topics + Grades)
  // ══════════════════════════════════════════════════════════════════

  Widget _buildExpandedContent(List<dynamic> partSections, List<Color> gradient) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Container(height: 1, color: Colors.grey.withOpacity(0.08)),
          const SizedBox(height: 10),
          ...partSections.map((section) {
            final sectionName = section['name']?.toString() ?? 'Tema';
            final modules = section['modules'] as List<dynamic>? ?? [];

            // Filtrar solo ejercicios con nota
            final gradedExercises = modules.where((m) {
              final name = m['name']?.toString().toLowerCase() ?? '';
              return name.contains('ejercicio') &&
                  (m['grade'] != null && m['grade'] != '-');
            }).toList();

            if (gradedExercises.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del tema
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sectionName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ejercicios con nota
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: gradedExercises.map((m) {
                      final grade = _cleanHtml(m['grade'].toString());
                      final gradeNum = double.tryParse(grade.replaceAll(',', '.'));
                      
                      Color pillColor;
                      Color pillBg;
                      if (gradeNum != null) {
                        if (gradeNum >= 80) {
                          pillColor = const Color(0xFF10B981);
                          pillBg = const Color(0xFFECFDF5);
                        } else if (gradeNum >= 50) {
                          pillColor = const Color(0xFFE67E22);
                          pillBg = const Color(0xFFFFF7ED);
                        } else {
                          pillColor = const Color(0xFFEF4444);
                          pillBg = const Color(0xFFFEF2F2);
                        }
                      } else {
                        pillColor = const Color(0xFF6B7280);
                        pillBg = const Color(0xFFF3F4F6);
                      }

                      // Nombre corto del ejercicio
                      String shortName = m['name']?.toString() ?? 'Ejercicio';
                      // Extraer número si existe
                      final numMatch = RegExp(r'(\d+)').firstMatch(shortName);
                      final label = numMatch != null ? 'Ej. ${numMatch.group(1)}' : 'Ej.';

                      return Tooltip(
                        message: shortName,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: pillColor.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                grade,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: pillColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
