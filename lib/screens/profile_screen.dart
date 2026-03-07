import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/course_service.dart';
import '../services/badge_service.dart';
import '../home_screen.dart';
import '../widgets/custom_loading_indicator.dart';
import '../theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Estos datos vendrán del servicio de Estudiantes (Base de datos parlando_students)
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  String? _localImageFile;
  Map<String, String> _lastBadgePerLevel = {};

  @override
  void initState() {
    super.initState();
    // Inicializamos el formateo de fechas para español antes de cargar el perfil
    initializeDateFormatting('es', null).then((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    // Primero obtenemos los datos básicos de la autenticación actual (nombre usuario, foto moodle)
    final authData = await AuthService().getUserData();

    if (mounted) {
      setState(() {
        // Iniciamos el estado con los datos básicos mientras cargamos el resto
        _studentData = {
          'fullName': authData?['fullname'] ?? 'Estudiante',
          'userName': authData?['username'] ?? '',
          'imageUrl':
              authData?['image_url'], // Foto de perfil original de Moodle
        };
        _isLoading = true;
      });

      try {
        // Intentamos obtener los datos detallados desde la base de datos (PHP)
        final serviceData = await StudentService().getStudentProfile();
        if (serviceData != null) {
          setState(() {
            _studentData = serviceData;
            // Si el servicio no trajo foto (usualmente no la trae), mantenemos la de Moodle
            if (_studentData!['imageUrl'] == null) {
              _studentData!['imageUrl'] = authData?['image_url'];
            }
          });
        }
      } catch (e) {
        debugPrint("Error cargando detalles del estudiante: $e");
        // Si falla, al menos mostramos los datos básicos de autenticación
      }
      setState(() => _isLoading = false);

      // Cargar la última insignia ganada
      _loadLastBadge();
    }
  }

  Future<void> _loadLastBadge() async {
    try {
      final badgeService = BadgeService();
      var earnedIds = await badgeService.getEarnedBadgeIds();

      // Si no hay insignias locales, intentamos sincronizar con los cursos actuales
      // Esto maneja el caso de inicio de sesión en una cuenta con progreso previo
      if (earnedIds.isEmpty) {
        try {
          final courses = await CourseService().getCourses();
          if (courses.isNotEmpty) {
            // Buscar curso principal (que no sea diagnóstico)
            final mainCourse = courses.firstWhere(
              (c) => c['id'] != BadgeService.diagnosticCourseId,
              orElse: () => courses.first,
            );

            // Verificar badges contra la API
            final newBadges = await badgeService.checkForNewBadgesFromApi(
              courseId: mainCourse['id'],
            );

            // Marcar como mostrados para que no salten alertas,
            // ya que estamos en el perfil solo sincronizando
            for (var b in newBadges) {
              await badgeService.markBadgeShown(b.id);
            }

            // Recargar lista de ganados
            if (newBadges.isNotEmpty) {
              earnedIds = await badgeService.getEarnedBadgeIds();
            }
          }
        } catch (e) {
          debugPrint('Debug: Error sync badges en perfil: $e');
        }
      }

      if (earnedIds.isEmpty) return;

      final Map<String, String> perLevel = {};
      final levels = ['A1', 'A2', 'B1', 'B2'];

      for (var level in levels) {
        for (var badge in BadgeService.allBadges.reversed) {
          if (badge.level == level && earnedIds.contains(badge.id)) {
            perLevel[level] = badge.assetPath;
            break;
          }
        }
      }

      if (mounted && perLevel.isNotEmpty) {
        setState(() => _lastBadgePerLevel = perLevel);
      }
    } catch (e) {
      debugPrint('Debug: Error cargando insignias: $e');
    }
  }

  Future<void> _pickImage() async {
    // Permitimos seleccionar una imagen de la galería
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      setState(() {
        _localImageFile = image.path;
      });
      // Nota: Aquí iría la lógica para subir la imagen al servidor (Moodle API o PHP custom)
      // Por ahora, actualizamos la vista localmente.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Foto de perfil actualizada localmente (subida pendiente)')),
      );
    }
  }

  Future<void> _logout() async {
    // Mostramos un diálogo de confirmación antes de cerrar sesión
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas salir?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;

      await AuthService().logout();

      if (!mounted) return;
      // Navegamos al login y limpiamos todo el historial de navegación
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CustomLoadingIndicator(size: 80));
    }

    final user = _studentData ?? {};
    final String fullName = user['fullName'] ?? 'Estudiante';
    // Mostramos el tipo de curso tal cual viene de la base de datos (Presencial, Virtual, etc.)
    final String courseType = user['courseType'] ?? 'N/A';
    final String document =
        '${user['documentType'] ?? ''} ${user['documentNumber'] ?? ''}'.trim();

    // Función auxiliar para formatear fechas (ej. 12 feb 2024)
    String fDate(String? date) {
      if (date == null || date.isEmpty || date == '0000-00-00') return 'N/A';
      try {
        final d = DateTime.parse(date);
        return DateFormat('dd MMM yyyy', 'es').format(d);
      } catch (e) {
        return date;
      }
    }

    // Función auxiliar para formatear moneda (Pesos colombianos, sin decimales)
    String fMoney(dynamic amount) {
      if (amount == null) return '\$0';
      double val = double.tryParse(amount.toString()) ?? 0;
      return NumberFormat.currency(
              locale: 'es_CO', symbol: '\$', decimalDigits: 0)
          .format(val);
    }

    return ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeProvider.themeNotifier,
        builder: (context, themeMode, _) {
          final isDarkMode = themeMode == ThemeMode.dark;

          return Scaffold(
            backgroundColor: context.bgScaffold,
            appBar: AppBar(
              title: Text(
                'Mi Perfil',
                style: TextStyle(
                  color: context.textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              backgroundColor: context.cardColor,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: context.textColor),
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // 1. Encabezado del Perfil (Foto + Nombre + Rol)
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: context.shadowColor,
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: context.bgScaffold,
                            backgroundImage: _localImageFile != null
                                ? FileImage(File(_localImageFile!))
                                : (user['imageUrl'] != null
                                    ? NetworkImage(user['imageUrl'])
                                    : null) as ImageProvider?,
                            child: (_localImageFile == null &&
                                    user['imageUrl'] == null)
                                ? Text(
                                    fullName.isNotEmpty
                                        ? fullName[0].toUpperCase()
                                        : 'E',
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2A60E4)))
                                : null,
                          ),
                        ),
                        // Botón flotante para editar foto
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A60E4),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2A60E4)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A60E4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      courseType,
                      style: const TextStyle(
                        color: Color(0xFF2A60E4),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Insignias por nivel
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLevelBadge('A1', const Color(0xFF2A60E4), context),
                      const SizedBox(width: 10),
                      _buildLevelBadge('A2', const Color(0xFF1FAB5E), context),
                      const SizedBox(width: 10),
                      _buildLevelBadge('B1', const Color(0xFFE67E22), context),
                      const SizedBox(width: 10),
                      _buildLevelBadge('B2', const Color(0xFF8E44AD), context),
                    ],
                  ),

                  const SizedBox(height: 30),

                  _buildSectionTitle('Ajustes de la App', context),
                  _buildInfoCard([
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.dark_mode_rounded,
                                size: 20, color: Colors.purple),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('Modo Oscuro',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.textColor)),
                          ),
                          Switch(
                            value: isDarkMode,
                            onChanged: (value) async {
                              await ThemeProvider.setDarkMode(value);
                            },
                            activeColor: const Color(0xFF2A60E4),
                            inactiveThumbColor: Colors.grey[400],
                            inactiveTrackColor: Colors.grey.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ], context),

                  const SizedBox(height: 20),

                  // 2. Tarjetas de Información Detallada
                  _buildSectionTitle('Información Personal', context),
                  _buildInfoCard([
                    _buildInfoRow(Icons.badge, 'Documento',
                        document.isEmpty ? 'N/A' : document, context),
                    _buildInfoRow(Icons.cake, 'Nacimiento',
                        fDate(user['dateOfBirth']), context),
                    _buildInfoRow(Icons.person, 'Acudiente',
                        user['guardianName'] ?? 'N/A', context),
                    _buildInfoRow(Icons.phone, 'Contacto',
                        user['contactNumber'] ?? 'N/A', context),
                  ], context),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Información Académica', context),
                  _buildInfoCard([
                    _buildInfoRow(Icons.school, 'Tipo de Curso',
                        user['courseType'] ?? 'N/A', context),
                    _buildInfoRow(Icons.calendar_today, 'Inicio Contrato',
                        fDate(user['startDate']), context),
                    _buildInfoRow(Icons.event_busy, 'Fin Contrato',
                        fDate(user['endDate']), context),
                    // Opcional: Mostrar número de acta si se requiere
                    // _buildInfoRow(Icons.description, 'N° Acta', user['actNumber'] ?? 'N/A', context),
                  ], context),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Información Financiera', context),
                  _buildFinancialCard(user, fMoney, context),

                  const SizedBox(height: 20),

                  // Botón de Cerrar Sesión
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon:
                          const Icon(Icons.logout_rounded, color: Colors.white),
                      label: const Text('Cerrar Sesión',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40), // Espacio inferior para scroll
                ],
              ),
            ),
          );
        });
  }

  // Widget auxiliar para títulos de sección
  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.textColor,
          ),
        ),
      ),
    );
  }

  // Widget contenedor para las tarjetas blancas con sombra
  Widget _buildInfoCard(List<Widget> children, BuildContext context) {
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
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, BuildContext context) {
    const iconColor = Color(0xFF2A60E4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: context.subtitleColor,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta especial con gradiente para datos financieros
  Widget _buildFinancialCard(Map<String, dynamic> user,
      String Function(dynamic) fMoney, BuildContext context) {
    String method = user['paymentMethod'] ?? 'N/A';
    String total = fMoney(user['totalAmount']);

    // Si tenemos desglose de cuotas calculado por el servicio, lo mostramos

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estado de Pago',
                  style: TextStyle(
                      color: context.subtitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FAB5E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  method.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF1FAB5E),
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            total,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.textColor),
          ),
          const SizedBox(height: 16),

          // Lógica visual para cuotas vs contado
          if (user['computed_payment_status'] != null) ...[
            Builder(builder: (context) {
              final status = user['computed_payment_status'];
              final int paid = status['paidQuotas'] ?? 0;
              final int totalQ = status['totalQuotas'] ?? 0;
              if (totalQ > 0) {
                final double progressVal = totalQ > 0 ? paid / totalQ : 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cuotas completadas',
                            style: TextStyle(
                                color: context.subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text('$paid de $totalQ',
                            style: TextStyle(
                                color: context.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressVal,
                        backgroundColor: context.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2A60E4)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
          ] else if (method.toLowerCase().contains('cuota'))
            Text('Pago a cuotas activo',
                style: TextStyle(color: context.subtitleColor, fontSize: 13)),

          if (method.toLowerCase().contains('contado') ||
              (user['computed_payment_status']?['isFullyPaid'] == true))
            const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF1FAB5E), size: 18),
                SizedBox(width: 8),
                Text('Pagado en su totalidad',
                    style: TextStyle(
                        color: Color(0xFF1FAB5E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(String level, Color color, BuildContext context) {
    final badgePath = _lastBadgePerLevel[level];
    final bool hasBadge = badgePath != null;

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBadge ? color.withOpacity(0.3) : context.borderColor,
          width: 1.5,
        ),
        boxShadow: hasBadge
            ? [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge image o lock
          hasBadge
              ? Image.asset(
                  badgePath,
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                )
              : Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: Colors.grey[400],
                ),
          const SizedBox(height: 4),
          // Label del nivel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: hasBadge
                  ? color.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              level,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: hasBadge ? color : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
