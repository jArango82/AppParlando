import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/insforge_service.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/student_messages_service.dart';
import '../models/practice_exercise.dart';
import 'course_details_screen.dart';
import 'practice/practice_level_select_screen.dart';
import '../widgets/custom_loading_indicator.dart';
import '../theme_provider.dart';

class HomePage extends StatefulWidget {
  /// True cuando la pestaña Inicio está visible (IndexedStack).
  final bool isActive;

  const HomePage({super.key, this.isActive = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 45);

  Future<Map<String, dynamic>>? _progressFuture;
  Map<String, dynamic>? _user;
  String? _profileImageUrl;
  String? _studentId;
  List<Map<String, dynamic>> _messages = [];
  bool _messagesLoading = true;
  int _lastKnownMaxId = 0;
  bool _appInForeground = true;
  Timer? _pollTimer;
  bool _pollInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncPolling();
      // Al volver a Inicio, un check inmediato por si hubo mensajes nuevos
      if (widget.isActive && _appInForeground) {
        _pollCheck();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inForeground = state == AppLifecycleState.resumed;
    if (_appInForeground == inForeground) return;
    _appInForeground = inForeground;
    _syncPolling();
    if (inForeground && widget.isActive) {
      _pollCheck();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncPolling() {
    final shouldPoll =
        widget.isActive && _appInForeground && _studentId != null;
    if (shouldPoll) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollCheck());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollCheck() async {
    if (!mounted ||
        !widget.isActive ||
        !_appInForeground ||
        _studentId == null ||
        _pollInFlight) {
      return;
    }

    _pollInFlight = true;
    try {
      final result = await StudentMessagesService().checkForNew(
        studentId: _studentId!,
        afterId: _lastKnownMaxId,
      );
      if (!mounted) return;
      if (result['has_new'] == true) {
        await _loadMessages(forceRefresh: true, showLoading: false);
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getUserData();
    final prefs = await SharedPreferences.getInstance();
    String? savedImageUrl = prefs.getString('profile_image_url');

    // Si no hay foto guardada localmente, buscar en InsForge
    if (savedImageUrl == null && user?['username'] != null) {
      savedImageUrl = await _fetchAvatarFromInsforge(user!['username']);
    }

    if (mounted) {
      setState(() {
        _user = user;
        _profileImageUrl = savedImageUrl;
      });
      _progressFuture = CourseService().getCourseProgress();
      setState(() {});
    }

    await _loadMessages(forceRefresh: true);
  }

  Future<void> _loadMessages({
    bool forceRefresh = false,
    bool showLoading = true,
  }) async {
    if (mounted && showLoading) {
      setState(() => _messagesLoading = true);
    }

    try {
      final profile = await StudentService().getStudentProfile();
      final studentId = profile?['studentId']?.toString();
      if (studentId == null || studentId.isEmpty) {
        if (mounted) {
          setState(() {
            _studentId = null;
            _messages = [];
            _messagesLoading = false;
            _lastKnownMaxId = 0;
          });
        }
        _syncPolling();
        return;
      }

      final messages = await StudentMessagesService().getMessages(
        studentId,
        forceRefresh: forceRefresh,
      );

      var maxId = 0;
      for (final m in messages) {
        final id = int.tryParse(m['id']?.toString() ?? '') ?? 0;
        if (id > maxId) maxId = id;
      }

      // Marcar como leídos en servidor sin quitar el highlight de esta sesión
      final hasUnread = messages.any((m) => m['is_read'] != true);
      if (hasUnread) {
        StudentMessagesService().markAllAsRead(studentId);
      }

      if (mounted) {
        setState(() {
          _studentId = studentId;
          _messages = messages;
          _messagesLoading = false;
          _lastKnownMaxId = maxId;
        });
      }
      _syncPolling();
    } catch (e) {
      debugPrint('HomePage._loadMessages: $e');
      if (mounted) {
        setState(() => _messagesLoading = false);
      }
    }
  }

  /// Busca el avatar del usuario en InsForge Storage
  Future<String?> _fetchAvatarFromInsforge(String username) async {
    try {
      final insforge = InsforgeService();
      final String fileName = '${username.toLowerCase()}_avatar.jpg';

      // Verificar si el archivo realmente existe
      final bool exists = await insforge.fileExists('avatars', fileName);

      if (exists) {
        final String baseImageUrl = insforge.getPublicUrl('avatars', fileName);
        final String finalImageUrl =
            '$baseImageUrl?t=${DateTime.now().millisecondsSinceEpoch}';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_url', finalImageUrl);

        return finalImageUrl;
      }
      return null;
    } catch (e) {
      debugPrint('Debug: Error buscando avatar en InsForge: $e');
      return null;
    }
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

  String _formatMessageDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (_) {
      return raw;
    }
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

    return Scaffold(
      backgroundColor: context.bgScaffold,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUser();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── ENCABEZADO ───────────────────────
                    _buildHeader(firstName, _profileImageUrl, context),
                    const SizedBox(height: 24),

                    // ── CONTINUAR APRENDIENDO ────────────
                    FutureBuilder<Map<String, dynamic>>(
                      future: _progressFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildShimmerCard(context);
                        } else if (snapshot.hasError || !snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        return _buildContinueLearning(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── MENSAJES DEL ASESOR ──────────────
                    _buildMessagesSection(context),
                    const SizedBox(height: 24),

                    // ── PRÁCTICA RÁPIDA ──────────────────
                    _buildSectionTitle(
                        'Práctica rápida', Icons.bolt_rounded, context),
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
                color: accentColor.withValues(alpha: 0.3),
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
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.7)],
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
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.7),
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
                                color: accentColor.withValues(alpha: 0.4),
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
                            color: Colors.white.withValues(alpha: 0.2),
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
                          color: Colors.white.withValues(alpha: 0.8),
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
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
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

  // ── MENSAJES DEL ASESOR ────────────────────────────────────

  Widget _buildMessagesSection(BuildContext context) {
    const accent = Color(0xFF2A60E4);
    final preview = _messages.take(3).toList();
    final hasMore = _messages.length > 3;

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
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mensajes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: context.textColor,
                  ),
                ),
              ),
              if (!_messagesLoading && _messages.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_messages.length}',
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_messagesLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else if (_messages.isEmpty)
            Text(
              'No tienes mensajes por ahora.',
              style: TextStyle(
                color: context.subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            )
          else ...[
            ...preview.map((m) => _buildMessageItem(m, context)),
            if (hasMore) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showAllMessages(context),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Ver todos (${_messages.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message, BuildContext context) {
    final content = message['content']?.toString() ?? '';
    final author = message['author']?.toString() ?? 'Asesor';
    final date = _formatMessageDate(message['created_at']?.toString());
    final isUnread = message['is_read'] != true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread
            ? const Color(0xFF2A60E4).withValues(alpha: 0.06)
            : (context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF2A60E4).withValues(alpha: 0.18)
              : context.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  author,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.textColor,
                  ),
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: context.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllMessages(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Todos los mensajes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(_messages[index], context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  String _detectPracticeLevel(Map<String, dynamic>? course) {
    if (course == null) return 'A1';
    final combined = '${course['fullname'] ?? ''} ${course['shortname'] ?? ''}';
    if (combined.contains('B2')) return 'B2';
    if (combined.contains('B1')) return 'B1';
    if (combined.contains('A2')) return 'A2';
    return 'A1';
  }

  Future<void> _openPractice(PracticeCategory category) async {
    String? suggested;
    try {
      final data =
          await (_progressFuture ?? CourseService().getCourseProgress());
      suggested =
          _detectPracticeLevel(data['course'] as Map<String, dynamic>?);
    } catch (_) {
      suggested = null;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeLevelSelectScreen(
          category: category,
          suggestedLevel: suggested,
        ),
      ),
    );
  }

  // ── GRID DE PRÁCTICA RÁPIDA ────────────────────────────────

  Widget _buildQuickPracticeGrid(BuildContext context) {
    final practices = [
      {
        'icon': Icons.menu_book_rounded,
        'title': 'Gramática',
        'subtitle': 'Reglas y tiempos',
        'color': const Color(0xFF2A60E4),
        'category': PracticeCategory.grammar,
      },
      {
        'icon': Icons.headphones_rounded,
        'title': 'Escucha',
        'subtitle': 'Próximamente',
        'color': const Color(0xFF1FAB5E),
        'category': null,
      },
      {
        'icon': Icons.edit_rounded,
        'title': 'Escritura',
        'subtitle': 'Práctica escrita',
        'color': const Color(0xFFE67E22),
        'category': PracticeCategory.writing,
      },
      {
        'icon': Icons.quiz_rounded,
        'title': 'Vocabulario',
        'subtitle': 'Aprende palabras',
        'color': const Color(0xFF8E44AD),
        'category': PracticeCategory.vocabulary,
      },
    ];

    final bool isWide = context.isWideScreen;

    return GridView.builder(
      shrinkWrap: true,
      clipBehavior: Clip.none,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isWide ? 1.3 : 1.15,
      ),
      itemCount: practices.length,
      itemBuilder: (context, index) {
        final p = practices[index];
        final color = p['color'] as Color;
        final title = p['title'] as String;
        final category = p['category'] as PracticeCategory?;
        final enabled = category != null;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? () => _openPractice(category) : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderColor),
                  boxShadow: [
                    if (!context.isDarkMode)
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
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(p['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title,
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
              ),
            ),
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
