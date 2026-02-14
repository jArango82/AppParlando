import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import 'course_details_screen.dart';
import '../widgets/custom_loading_indicator.dart';

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
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
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
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FB),
        body: Center(child: CustomLoadingIndicator(size: 80)),
      );
    }

    final String firstName = _user!['fullname']?.split(' ').first ?? 'Estudiante';
    final String? userImage = _user!['image_url'];
    final dailyTip = _getDailyTip();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
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
                _buildHeader(firstName, userImage),
                const SizedBox(height: 24),

                // ── CONTINUAR APRENDIENDO ────────────
                FutureBuilder<Map<String, dynamic>>(
                  future: _progressFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildShimmerCard();
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    return _buildContinueLearning(snapshot.data!);
                  },
                ),
                const SizedBox(height: 24),

                // ── CONSEJO DEL DÍA ──────────────────
                _buildDailyTip(dailyTip),
                const SizedBox(height: 24),

                // ── PRÁCTICA RÁPIDA ──────────────────
                _buildSectionTitle('Práctica Rápida', Icons.bolt_rounded),
                const SizedBox(height: 12),
                _buildQuickPracticeGrid(),
                const SizedBox(height: 24),

                // ── FRASE MOTIVACIONAL ───────────────
                _buildMotivationalQuote(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ENCABEZADO ──────────────────────────────────────────────

  Widget _buildHeader(String name, String? imageUrl) {
    return Row(
      children: [
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A60E4).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF2A60E4),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[50],
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'E',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2A60E4)))
                  : null,
            ),
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
                style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${months[now.month-1]} ${now.day}';
  }

  // ── CONTINUAR APRENDIENDO ──────────────────────────────────

  Widget _buildContinueLearning(Map<String, dynamic> data) {
    final course = data['course'];
    final sections = data['sections'] as List<dynamic>? ?? [];

    // Extraer nivel  
    String level = 'A1';
    final combined = '${course['fullname'] ?? ''} ${course['shortname'] ?? ''}';
    if (combined.contains('A2')) level = 'A2';
    else if (combined.contains('B1')) level = 'B1';
    else if (combined.contains('B2')) level = 'B2';

    // Calcular progreso
    int totalModules = 0, completedModules = 0;
    String nextLesson = 'Comienza tu primera lección';
    bool foundNext = false;

    for (var section in sections) {
      if (section['modules'] != null) {
        for (var module in section['modules']) {
          totalModules++;
          if (module['completionState'] == 1 || module['completionState'] == 2) {
            completedModules++;
          } else if (!foundNext) {
            nextLesson = module['name'] ?? 'Siguiente ejercicio';
            foundNext = true;
          }
        }
      }
    }

    final double progress = totalModules > 0 ? completedModules / totalModules : 0.0;
    final int progressPercent = (progress * 100).round();

    // Colores por nivel
    Color accentColor = const Color(0xFF2A60E4);
    if (level == 'A2') accentColor = const Color(0xFF1FAB5E);
    else if (level == 'B1') accentColor = const Color(0xFFE67E22);
    else if (level == 'B2') accentColor = const Color(0xFF8E44AD);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => CourseDetailsScreen(course: course),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(level,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$progressPercent% completado',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Continuar Aprendiendo',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextLesson,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    // Barra de progreso
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.play_arrow_rounded, color: accentColor, size: 24),
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

  Widget _buildDailyTip(String tip) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tip del Día',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE65100))),
                const SizedBox(height: 6),
                Text(tip,
                  style: TextStyle(color: Colors.grey[800], fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TÍTULO DE SECCIÓN ──────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2A60E4)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  // ── GRID DE PRÁCTICA RÁPIDA ────────────────────────────────

  Widget _buildQuickPracticeGrid() {
    final practices = [
      {'icon': Icons.menu_book_rounded, 'title': 'Gramática', 'subtitle': 'Reglas y tiempos', 'color': const Color(0xFF2A60E4)},
      {'icon': Icons.headphones_rounded, 'title': 'Escucha', 'subtitle': 'Ejercicios de audio', 'color': const Color(0xFF1FAB5E)},
      {'icon': Icons.edit_rounded, 'title': 'Escritura', 'subtitle': 'Práctica escrita', 'color': const Color(0xFFE67E22)},
      {'icon': Icons.quiz_rounded, 'title': 'Vocabulario', 'subtitle': 'Aprende palabras', 'color': const Color(0xFF8E44AD)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: practices.length,
      itemBuilder: (context, index) {
        final p = practices[index];
        final color = p['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
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
                child: Icon(p['icon'] as IconData, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(p['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
              Text(p['subtitle'] as String,
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        );
      },
    );
  }

  // ── FRASE MOTIVACIONAL ─────────────────────────────────────

  Widget _buildMotivationalQuote() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2A60E4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${_getMotivationalQuote()}"',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87, fontStyle: FontStyle.italic, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text('— Motivación del Día',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PANTALLA DE CARGA (SHIMMER) ────────────────────────────

  Widget _buildShimmerCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8EAED), Color(0xFFF1F3F5)],
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
