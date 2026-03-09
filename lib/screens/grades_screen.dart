import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/course_service.dart';
import '../config/course_config.dart';
import '../widgets/custom_loading_indicator.dart';
import '../theme_provider.dart';

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
      final filtered = courses.cast<Map<String, dynamic>>().where((c) {
        final name = (c['fullname'] ?? '').toString().toLowerCase();
        return !name.contains('examen') &&
            !name.contains('diagnóstico') &&
            !name.contains('diagnostico');
      }).toList();

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
      backgroundColor: context.bgScaffold,
      appBar: AppBar(
        title: Text(
          'Rendimiento Académico',
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
              onPressed: _loadCourses,
              tooltip: 'Actualizar',
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selector de Cursos ──
          if (!_isLoading && _error == null && _courses.isNotEmpty)
            Container(color: context.cardColor, child: _buildCourseChips()),
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
      height: 60,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
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
                            color: gradient[0].withValues(alpha: 0.15),
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
                      Icons.school_rounded,
                      color: gradient[0],
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'Nivel $level',
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
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadCourses,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A60E4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
            Text('No hay cursos disponibles',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    if (_isLoadingDetails) {
      return const Center(child: CustomLoadingIndicator(size: 60));
    }

    if (_courseDetails == null) {
      return Center(
        child: Text('Selecciona un curso',
            style: TextStyle(color: Colors.grey[400])),
      );
    }

    return _buildDashboard();
  }

  // ══════════════════════════════════════════════════════════════════
  //  DASHBOARD (NEW UI)
  // ══════════════════════════════════════════════════════════════════

  Widget _buildDashboard() {
    final course = _courses[_selectedCourseIndex];
    final fullname = course['fullname'] ?? '';
    final shortname = course['shortname'] ?? '';
    final level = _detectLevel(fullname);
    final gradient = _getGradient(level);

    final partsConfig =
        CourseConfig.getPartsForCourse(shortname, fullname: fullname);

    // Calcular estadísticas globales
    int totalExercises = 0;
    int completedExercises = 0;
    int gradedCount = 0;
    double gradeSum = 0;
    List<Map<String, dynamic>> allGradedModules = [];
    Map<String, List<double>> gradesByPart = {};

    final sections = _courseDetails!['sections'] as List<dynamic>? ?? [];

    for (var s in sections) {
      final sNum = int.tryParse(s['section'].toString()) ?? -1;
      String? partName;
      for (var entry in partsConfig.entries) {
        final allowedIds = List<int>.from(entry.value['ids']);
        if (allowedIds.contains(sNum)) {
          partName = entry.key;
          break;
        }
      }

      final modules = s['modules'] as List<dynamic>? ?? [];
      for (var m in modules) {
        final name = m['name']?.toString().toLowerCase() ?? '';
        if (name.contains('ejercicio')) {
          totalExercises++;
          if (m['completionState'] == 1 || m['completionState'] == 2) {
            completedExercises++;
          }
          if (m['grade'] != null && m['grade'] != '-') {
            final raw = _cleanHtml(m['grade'].toString())
                .replaceAll(',', '.')
                .replaceAll(RegExp(r'[^0-9.]'), '');
            final gradeVal = double.tryParse(raw);
            if (gradeVal != null) {
              gradedCount++;
              gradeSum += gradeVal;
              allGradedModules.add({
                'name': m['name'],
                'grade': gradeVal,
                'gradeStr': _cleanHtml(m['grade'].toString()),
              });
              if (partName != null) {
                gradesByPart[partName] ??= [];
                gradesByPart[partName]!.add(gradeVal);
              }
            }
          }
        }
      }
    }

    final String avgGrade = gradedCount > 0
        ? (gradeSum / gradedCount).toStringAsFixed(0) // Sin decimales
        : '0';

    List<Map<String, dynamic>> partsAverages = [];
    for (var entry in partsConfig.entries) {
      final grades = gradesByPart[entry.key] ?? [];
      if (grades.isNotEmpty) {
        final avg = grades.reduce((a, b) => a + b) / grades.length;
        String shortPartName = entry.key;
        if (shortPartName.toLowerCase().contains('parte')) {
          try {
            shortPartName =
                'P${shortPartName.substring(shortPartName.toLowerCase().indexOf('parte') + 5).trim()}';
          } catch (_) {
            // Ignorar y usar el nombre original
          }
        } else if (shortPartName.toLowerCase().contains('intro')) {
          shortPartName = 'Intro';
        }
        partsAverages.add({
          'name': shortPartName,
          'grade': avg,
        });
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjetas de Resumen
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Nota Promedio',
                  value: '$avgGrade%',
                  icon: Icons.auto_graph_rounded,
                  iconColor: const Color(0xFF2A60E4),
                  subtitle: 'Del curso actual',
                  subtitleColor: Colors.grey[500]!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Unidades Listas',
                  value: '$completedExercises',
                  suffix: ' / $totalExercises',
                  icon: Icons.school_rounded,
                  iconColor: const Color(0xFF8E44AD),
                  progress: totalExercises > 0
                      ? completedExercises / totalExercises
                      : 0.0,
                  gradient: gradient,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gráfico de Tendencia
          _buildProgressTrendCard(level, gradient, partsAverages),
          const SizedBox(height: 28),

          // Título de Evaluaciones Recientes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evaluaciones Recientes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textColor,
                ),
              ),
              GestureDetector(
                onTap: () => _showAllGradesSheet(context, gradient),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text(
                    'Ver Todo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: gradient[0],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Evaluaciones List
          allGradedModules.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Aún no tienes notas recientes.',
                        style: TextStyle(color: Colors.grey[400])),
                  ),
                )
              : Column(
                  children: allGradedModules.reversed.take(10).map((m) {
                    return _buildRecentAssessmentCard(m);
                  }).toList(),
                ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? suffix,
    required IconData icon,
    required Color iconColor,
    String? subtitle,
    Color? subtitleColor,
    double? progress,
    List<Color>? gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
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
              Icon(icon, size: 16, color: iconColor.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.subtitleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.textColor,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.subtitleColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: subtitleColor,
              ),
            ),
          if (progress != null && gradient != null) ...[
            const SizedBox(height: 10),
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

  Widget _buildProgressTrendCard(String level, List<Color> gradient,
      List<Map<String, dynamic>> gradedModules) {
    if (gradedModules.length < 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No hay suficientes datos',
              style: TextStyle(
                  color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
            Text(
              'Completa más ejercicios para ver tu tendencia',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            )
          ],
        ),
      );
    }

    // Preparar puntos (tomamos los últimos 15 para no saturar)
    final recentModules = gradedModules.length > 15
        ? gradedModules.sublist(gradedModules.length - 15)
        : gradedModules;

    List<FlSpot> spots = [];
    for (int i = 0; i < recentModules.length; i++) {
      spots.add(FlSpot(i.toDouble(), recentModules[i]['grade'] as double));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tendencia de Progreso',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D26),
                    ),
                  ),
                  Text(
                    'Mejora de tu calificación en el curso',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradient[0].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NIVEL $level',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: gradient[0],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        // Limpia el número si acaba en .0
                        String val = spot.y.toString();
                        if (val.endsWith('.0')) {
                          val = val.substring(0, val.length - 2);
                        }
                        return LineTooltipItem(
                          val,
                          TextStyle(
                            color: gradient[0],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= recentModules.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            recentModules[index]['name'].toString(),
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 10),
                          textAlign: TextAlign.right,
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length.toDouble() - 1,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: gradient[0],
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: gradient[0],
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          gradient[0].withValues(alpha: 0.3),
                          gradient[0].withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAssessmentCard(Map<String, dynamic> module) {
    final double gradeVal = module['grade'] ?? 0.0;
    final String gradeStr = module['gradeStr'] ?? '';
    final String name = module['name'] ?? 'Ejercicio';

    // Reglas de color solicitadas:
    // 80% y 100% -> verde
    // 50 a 80 -> naranja
    // 0 a 50 -> rojo
    Color bgColor;
    Color textColor;

    if (gradeVal >= 80) {
      bgColor = context.isDarkMode
          ? const Color(0xFF0F3628)
          : const Color(0xFFD1FAE5);
      textColor = context.isDarkMode
          ? const Color(0xFF34D399)
          : const Color(0xFF059669);
    } else if (gradeVal >= 50) {
      bgColor = context.isDarkMode
          ? const Color(0xFF3B2A18)
          : const Color(0xFFFFEDD5);
      textColor = context.isDarkMode
          ? const Color(0xFFFDE68A)
          : const Color(0xFFEA580C);
    } else {
      bgColor = context.isDarkMode
          ? const Color(0xFF450A0A)
          : const Color(0xFFFEE2E2);
      textColor = context.isDarkMode
          ? const Color(0xFFF87171)
          : const Color(0xFFDC2626);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Evaluación reciente', // No tenemos fecha real de Moodle, ponemos texto genérico
                      style: TextStyle(
                        fontSize: 12,
                        color: context.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$gradeStr/100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          // Aquí podríamos añadir "Teacher Feedback" si lo tuviéramos de la API
          // Por ahora replicamos el diseño vacío o con un dummy si se desea, pero
          // dado que no hay data real, es mejor dejar el diseño limpio.
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  MODAL BOTTOM SHEET (Ver Todo)
  // ══════════════════════════════════════════════════════════════════

  void _showAllGradesSheet(BuildContext context, List<Color> gradient) {
    if (_courseDetails == null) return;

    final course = _courses[_selectedCourseIndex];
    final shortname = course['shortname'] ?? '';
    final fullname = course['fullname'] ?? '';

    // Obtener la configuración de partes del curso (IDs de las secciones)
    final partsConfig =
        CourseConfig.getPartsForCourse(shortname, fullname: fullname);
    final sections = _courseDetails!['sections'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AllGradesSheetWidget(
          partsConfig: partsConfig,
          sections: sections,
          gradient: gradient,
          buildCardCallback: _buildRecentAssessmentCard,
          cleanHtmlCallback: _cleanHtml,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  STATEFUL WIDGET FOR BOTTOM SHEET (VER TODAS)
// ══════════════════════════════════════════════════════════════════

class _AllGradesSheetWidget extends StatefulWidget {
  final Map<String, dynamic> partsConfig;
  final List<dynamic> sections;
  final List<Color> gradient;
  final Widget Function(Map<String, dynamic>) buildCardCallback;
  final String Function(String) cleanHtmlCallback;

  const _AllGradesSheetWidget({
    required this.partsConfig,
    required this.sections,
    required this.gradient,
    required this.buildCardCallback,
    required this.cleanHtmlCallback,
  });

  @override
  State<_AllGradesSheetWidget> createState() => _AllGradesSheetWidgetState();
}

class _AllGradesSheetWidgetState extends State<_AllGradesSheetWidget> {
  String? _selectedPart;
  int? _selectedSectionId; // null significa "Todos los temas"

  @override
  Widget build(BuildContext context) {
    // 1. Opciones para el filtro "Parte"
    final List<String> partOptions = [
      'Todas las partes',
      ...widget.partsConfig.keys
    ];

    // 2. Opciones para el filtro "Tema" basadas en la "Parte" seleccionada
    List<Map<String, dynamic>> topicOptions = [
      {'id': null, 'name': 'Todos los temas'}
    ];

    if (_selectedPart != null && _selectedPart != 'Todas las partes') {
      final allowedIds =
          List<int>.from(widget.partsConfig[_selectedPart]['ids']);
      final validSections = widget.sections.where((s) {
        final sNum = int.tryParse(s['section'].toString());
        return sNum != null && allowedIds.contains(sNum);
      });

      for (var s in validSections) {
        topicOptions.add({
          'id': int.tryParse(s['section'].toString()),
          'name': s['name']?.toString() ?? 'Tema',
        });
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.bgScaffold,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Agarradera de la hoja y Título ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: context.shadowColor,
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.subtitleColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Todas las Evaluaciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.textColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: context.subtitleColor,
                    ),
                  ],
                ),
                // ── Filtros (Dropdowns) ──
                if (widget.partsConfig.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Filtro Parte
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: context.bgScaffold,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPart ?? 'Todas las partes',
                              isExpanded: true,
                              dropdownColor: context.cardColor,
                              icon: Icon(Icons.keyboard_arrow_down,
                                  color: widget.gradient[0]),
                              style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedPart = newValue == 'Todas las partes'
                                      ? null
                                      : newValue;
                                  _selectedSectionId =
                                      null; // Resetear tema al cambiar de parte
                                });
                              },
                              items: partOptions.map<DropdownMenuItem<String>>(
                                  (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filtro Tema
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _selectedPart == null
                                ? (context.isDarkMode
                                    ? Colors.grey[900]
                                    : Colors.grey[100])
                                : context.bgScaffold,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedSectionId,
                              isExpanded: true,
                              dropdownColor: context.cardColor,
                              hint: Text('Temas',
                                  style: TextStyle(
                                      fontSize: 13, color: context.textColor)),
                              icon: Icon(Icons.keyboard_arrow_down,
                                  color: _selectedPart == null
                                      ? context.subtitleColor
                                      : widget.gradient[0]),
                              style: TextStyle(
                                  color: _selectedPart == null
                                      ? context.subtitleColor
                                      : context.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              disabledHint: const Text('Selecciona Parte',
                                  style: TextStyle(fontSize: 13)),
                              onChanged: _selectedPart == null
                                  ? null
                                  : (int? newValue) {
                                      setState(() {
                                        _selectedSectionId = newValue;
                                      });
                                    },
                              items: _selectedPart == null
                                  ? []
                                  : topicOptions.map<DropdownMenuItem<int?>>(
                                      (Map<String, dynamic> topic) {
                                      return DropdownMenuItem<int?>(
                                        value: topic['id'],
                                        child: Text(topic['name'],
                                            overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Contenido de Notas agrupadas por Partes ──
          Expanded(
            child: widget.partsConfig.isEmpty
                ? Center(
                    child: Text(
                      'No hay configuración de partes para este curso.',
                      style: TextStyle(color: context.subtitleColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    // Si hay una parte seleccionada, solo creamos un elemento para esa parte, si no, para todas
                    itemCount:
                        _selectedPart != null ? 1 : widget.partsConfig.length,
                    itemBuilder: (context, index) {
                      // Determinar qué parte renderizar en este índice
                      final String partName = _selectedPart ??
                          widget.partsConfig.keys.elementAt(index);
                      final allowedIds =
                          List<int>.from(widget.partsConfig[partName]['ids']);

                      // Filtrar secciones (temas) que pertenezcan a esta parte y respetando el filtro de tema (_selectedSectionId)
                      final partSections = widget.sections.where((s) {
                        final sNum = int.tryParse(s['section'].toString());
                        if (sNum == null || !allowedIds.contains(sNum)) {
                          return false;
                        }
                        if (_selectedSectionId != null &&
                            sNum != _selectedSectionId) {
                          return false;
                        }
                        return true;
                      }).toList();

                      // Obtener todos los ejercicios calificados de estas secciones
                      List<Map<String, dynamic>> partExercises = [];
                      for (var s in partSections) {
                        final modules = s['modules'] as List<dynamic>? ?? [];
                        for (var m in modules) {
                          final name =
                              m['name']?.toString().toLowerCase() ?? '';
                          if (name.contains('ejercicio') &&
                              m['grade'] != null &&
                              m['grade'] != '-') {
                            final raw = widget
                                .cleanHtmlCallback(m['grade'].toString())
                                .replaceAll(',', '.')
                                .replaceAll(RegExp(r'[^0-9.]'), '');
                            final gradeVal = double.tryParse(raw);
                            if (gradeVal != null) {
                              partExercises.add({
                                'name': m['name'],
                                'grade': gradeVal,
                                'gradeStr': widget
                                    .cleanHtmlCallback(m['grade'].toString()),
                              });
                            }
                          }
                        }
                      }

                      if (partExercises.isEmpty) {
                        return const SizedBox
                            .shrink(); // No mostrar partes vacías
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título de la Parte (con estilo especial) solo si se muestran TODAS las partes o si no hay filtro de tema
                          if (_selectedPart == null ||
                              _selectedSectionId == null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: widget.gradient,
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    partName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: widget.gradient[0],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Lista de ejercicios de esta parte
                          ...partExercises
                              .map((m) => widget.buildCardCallback(m)),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
