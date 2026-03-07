import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import 'course_details_screen.dart';
import '../widgets/custom_loading_indicator.dart';
import '../theme_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<Map<String, dynamic>>? _progressFuture;
  Map<String, dynamic>? _user;

  // Lista de consejos diarios para aprender inglés
  static final List<String> _tips = [
    '🎧 Escucha podcasts en inglés 10 minutos al día — ¡mejora tu comprensión rápidamente!',
    '📝 Escribe 3 oraciones en inglés cada día para ganar confianza escribiendo.',
    '🗣️ Practica hablando en voz alta, incluso solo — ¡tu cerebro aprende al escucharte!',
    '📖 Lee libros infantiles en inglés primero — vocabulario simple, gramática real.',
    '🎵 Aprende canciones en inglés — la música ayuda a retener vocabulario.',
    '🔁 Repasa la lección de ayer antes de comenzar una nueva.',
    '💬 Cambia el idioma de tu celular a inglés para aprender de forma pasiva.',
    '📺 Ve series en inglés con subtítulos en inglés, no en español.',
    '✍️ Lleva un cuaderno de vocabulario y repásalo cada domingo.',
    '🌅 Estudia en la mañana — tu cerebro absorbe idiomas mejor temprano.',
    '🤔 ¡No traduzcas palabra por palabra — piensa directamente en inglés!',
    '👥 Encuentra un compañero de estudio y practiquen conversaciones juntos.',
    '📱 Usa esta app al menos 15 minutos cada día para mejores resultados.',
    '🎯 Ponte una meta específica: "Hoy voy a aprender 5 palabras nuevas."',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getUserData();
    if (mounted) {
      setState(() => _user = user);
      _progressFuture = CourseService().getCourseProgress();
      setState(() {});
    }
  }

  String _getDailyTip() {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return _tips[dayOfYear % _tips.length];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _getMotivationalQuote() {
    final quotes = [
      'Todo experto fue alguna vez un principiante.',
      'Un pequeño progreso sigue siendo progreso.',
      'Aprender nunca cansa la mente.',
      'Cuanto más practicas, mejor te vuelves.',
      'Cree que puedes y ya estás a medio camino.',
      'El único límite eres tú mismo.',
      'Cada día es una nueva oportunidad para aprender.',
    ];
    return quotes[DateTime.now().day % quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        backgroundColor: context.bgScaffold,
        body: const Center(child: CustomLoadingIndicator(size: 80)),
      );
    }

    final String firstName =
        _user!['fullname']?.split(' ').first ?? 'Estudiante';
    final String? userImage = _user!['image_url'];
    final dailyTip = _getDailyTip();

    return Scaffold(
      backgroundColor: context.bgScaffold,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _loadUser();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ENCABEZADO ───────────────────────
                _buildHeader(firstName, userImage, context),
                const SizedBox(height: 24),

                // ── CONTINUAR APRENDIENDO ────────────
                FutureBuilder<Map<String, dynamic>>(
                  future: _progressFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildShimmerCard(context);
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    return _buildContinueLearning(snapshot.data!);
                  },
                ),
                const SizedBox(height: 24),

                // ── CONSEJO DEL DÍA ──────────────────
                _buildDailyTip(dailyTip, context),
                const SizedBox(height: 24),

                // ── PRÁCTICA RÁPIDA ──────────────────
                _buildSectionTitle(
                    'Qué aprenderás', Icons.bolt_rounded, context),
                const SizedBox(height: 12),
                _buildQuickPracticeGrid(context),
                const SizedBox(height: 24),

                // ── FRASE MOTIVACIONAL ───────────────
                _buildMotivationalQuote(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ENCABEZADO ──────────────────────────────────────────────

  Widget _buildHeader(String name, String? imageUrl, BuildContext context) {
    return Row(
      children: [
        // Avatar
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.cardColor,
            shape: BoxShape.circle,
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color: context.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: context.bgScaffold,
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'E',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A60E4)))
                : null,
          ),
        ),
        const SizedBox(width: 14),
        // Saludo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(
                    color: context.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CONTINUAR APRENDIENDO ──────────────────────────────────

  Widget _buildContinueLearning(Map<String, dynamic> data) {
    final course = data['course'];
    final sections = data['sections'] as List<dynamic>? ?? [];

    // Extraer nivel
    String level = 'A1';
    final combined = '${course['fullname'] ?? ''} ${course['shortname'] ?? ''}';
    if (combined.contains('A2')) {
      level = 'A2';
    } else if (combined.contains('B1')) {
      level = 'B1';
    } else if (combined.contains('B2')) {
      level = 'B2';
    }

    // Calcular progreso
    int totalModules = 0, completedModules = 0;
    String nextLesson = 'Comienza tu primera lección';
    bool foundNext = false;

    for (var section in sections) {
      if (section['modules'] != null) {
        for (var module in section['modules']) {
          totalModules++;
          if (module['completionState'] == 1 ||
              module['completionState'] == 2) {
            completedModules++;
          } else if (!foundNext) {
            nextLesson = module['name'] ?? 'Siguiente ejercicio';
            foundNext = true;
          }
        }
      }
    }

    final double progress =
        totalModules > 0 ? completedModules / totalModules : 0.0;
    final int progressPercent = (progress * 100).round();

    // Colores por nivel
    Color accentColor = const Color(0xFF2A60E4);
    if (level == 'A2') {
      accentColor = const Color(0xFF1FAB5E);
    } else if (level == 'B1') {
      accentColor = const Color(0xFFE67E22);
    } else if (level == 'B2') {
      accentColor = const Color(0xFF8E44AD);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailsScreen(course: course),
            ));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Imagen de fondo del curso
              Image.asset(
                'assets/$level.webp',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Capa oscura
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Contenido superpuesto
              Positioned(
                left: 20,
                right: 20,
                top: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text('NIVEL $level',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$progressPercent% completado',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Continuar Aprendiendo',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextLesson,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    // Barra de progreso
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accentColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.play_arrow_rounded,
                              color: accentColor, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONSEJO DEL DÍA ────────────────────────────────────────

  Widget _buildDailyTip(String tip, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? const Color(0xFF2A1C11)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.transparent
                : const Color(0xFFE67E22).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: context.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE67E22).withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]),
            child: const Text('💡', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tip del Día',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFFE67E22))),
                const SizedBox(height: 6),
                Text(tip,
                    style: TextStyle(
                        color: context.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TÍTULO DE SECCIÓN ──────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF2A60E4)),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textColor)),
      ],
    );
  }

  // ── GRID DE PRÁCTICA RÁPIDA ────────────────────────────────

  Widget _buildQuickPracticeGrid(BuildContext context) {
    final practices = [
      {
        'icon': Icons.menu_book_rounded,
        'title': 'Gramática',
        'subtitle': 'Reglas y tiempos',
        'color': const Color(0xFF2A60E4)
      },
      {
        'icon': Icons.headphones_rounded,
        'title': 'Escucha',
        'subtitle': 'Ejercicios de audio',
        'color': const Color(0xFF1FAB5E)
      },
      {
        'icon': Icons.edit_rounded,
        'title': 'Escritura',
        'subtitle': 'Práctica escrita',
        'color': const Color(0xFFE67E22)
      },
      {
        'icon': Icons.quiz_rounded,
        'title': 'Vocabulario',
        'subtitle': 'Aprende palabras',
        'color': const Color(0xFF8E44AD)
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      clipBehavior: Clip.none, // Evita que las sombras se recorten y generen bugs visuales
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15, // Ajustado para dar un poco más de altura vertical
      ),
      itemCount: practices.length,
      itemBuilder: (context, index) {
        final p = practices[index];
        final color = p['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              if (!context.isDarkMode) // Solo mostramos sombra en modo claro para evitar bugs oscuros
                BoxShadow(
                    color: context.shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(p['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p['title'] as String,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: context.textColor)),
                    const SizedBox(height: 2),
                    Text(p['subtitle'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.subtitleColor)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── FRASE MOTIVACIONAL ─────────────────────────────────────

  Widget _buildMotivationalQuote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
              color: context.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2A60E4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${_getMotivationalQuote()}"',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textColor,
                      fontStyle: FontStyle.italic,
                      height: 1.4),
                ),
                const SizedBox(height: 8),
                Text('— Motivación del Día',
                    style: TextStyle(
                        fontSize: 12,
                        color: context.subtitleColor,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PANTALLA DE CARGA (SHIMMER) ────────────────────────────

  Widget _buildShimmerCard(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDarkMode
              ? [const Color(0xFF1E212B), const Color(0xFF2A2D35)]
              : [const Color(0xFFE8EAED), const Color(0xFFF1F3F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(
        child: CustomLoadingIndicator(size: 50),
      ),
    );
  }
}
