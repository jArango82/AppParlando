import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../home_screen.dart';
import '../widgets/custom_loading_indicator.dart';

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
  String? _localImageFile; // Ruta a la imagen seleccionada localmente

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
           'imageUrl': authData?['image_url'], // Foto de perfil original de Moodle
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
         print("Error cargando detalles del estudiante: $e");
         // Si falla, al menos mostramos los datos básicos de autenticación
       }
       setState(() => _isLoading = false);
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
        const SnackBar(content: Text('Foto de perfil actualizada localmente (subida pendiente)')),
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
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
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
    final String document = '${user['documentType'] ?? ''} ${user['documentNumber'] ?? ''}'.trim();
    
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
      return NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(val);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Encabezado del Perfil (Foto + Nombre + Rol)
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    // Lógica para mostrar la imagen: Local > Red > Inicial
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage: _localImageFile != null
                          ? FileImage(File(_localImageFile!))
                          : (user['imageUrl'] != null ? NetworkImage(user['imageUrl']) : null) as ImageProvider?,
                      child: (_localImageFile == null && user['imageUrl'] == null)
                          ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E', style: const TextStyle(fontSize: 40, color: Colors.blue))
                          : null,
                    ),
                  ),
                  // Botón flotante para editar foto
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
               decoration: BoxDecoration(
                 color: Colors.blue.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Text(
                 courseType,
                 style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 13),
               ),
            ),
            const SizedBox(height: 30),

            // 2. Tarjetas de Información Detallada
            _buildSectionTitle('Información Personal'),
            _buildInfoCard([
              _buildInfoRow(Icons.badge, 'Documento', document.isEmpty ? 'N/A' : document),
              _buildInfoRow(Icons.cake, 'Nacimiento', fDate(user['dateOfBirth'])),
              _buildInfoRow(Icons.person, 'Acudiente', user['guardianName'] ?? 'N/A'),
              _buildInfoRow(Icons.phone, 'Contacto', user['contactNumber'] ?? 'N/A'),
            ]),

            const SizedBox(height: 20),
            _buildSectionTitle('Información Académica'),
             _buildInfoCard([
              _buildInfoRow(Icons.school, 'Tipo de Curso', user['courseType'] ?? 'N/A'),
              _buildInfoRow(Icons.calendar_today, 'Inicio Contrato', fDate(user['startDate'])),
              _buildInfoRow(Icons.event_busy, 'Fin Contrato', fDate(user['endDate'])),
              // Opcional: Mostrar número de acta si se requiere
              // _buildInfoRow(Icons.description, 'N° Acta', user['actNumber'] ?? 'N/A'),
            ]),

            const SizedBox(height: 20),
            _buildSectionTitle('Información Financiera'),
            _buildFinancialCard(user, fMoney),
            
            const SizedBox(height: 20),
            
            // Botón de Cerrar Sesión
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Cerrar Sesión', style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            const SizedBox(height: 40), // Espacio inferior para scroll
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para títulos de sección
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title, 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  // Widget contenedor para las tarjetas blancas con sombra
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withOpacity(0.04),
             blurRadius: 10,
             offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta especial con gradiente para datos financieros
  Widget _buildFinancialCard(Map<String, dynamic> user, String Function(dynamic) fMoney) {
    String method = user['paymentMethod'] ?? 'N/A';
    String total = fMoney(user['totalAmount']);
    
    // Si tenemos desglose de cuotas calculado por el servicio, lo mostramos
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A60E4), Color(0xFF1FAB5E)], // Gradiente de Azul a Verde (Colores de marca)
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
             color: const Color(0xFF2A60E4).withOpacity(0.3),
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
              const Text('Estado de Pago', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  method.toUpperCase(), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            total,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          
          // Lógica visual para cuotas vs contado
          if (user['computed_payment_status'] != null) ...[
             Builder(builder: (context) {
               final status = user['computed_payment_status'];
               final int paid = status['paidQuotas'] ?? 0;
               final int totalQ = status['totalQuotas'] ?? 0;
               if (totalQ > 0) {
                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Muestra el progreso de cuotas: Ej. 3 de 10 pagadas
                     Text('Cuotas: $paid de $totalQ pagadas', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                     const SizedBox(height: 6),
                     LinearProgressIndicator(
                       value: totalQ > 0 ? paid / totalQ : 0,
                       backgroundColor: Colors.white.withOpacity(0.3),
                       valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                     ),
                   ],
                 );
               }
               return const SizedBox.shrink();
             }),
          ] else if (method.toLowerCase().contains('cuota')) 
            const Text('Pago a cuotas activo', style: TextStyle(color: Colors.white, fontSize: 13)),
          
          if (method.toLowerCase().contains('contado') || (user['computed_payment_status']?['isFullyPaid'] == true))
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Pagado en su totalidad', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
        ],
      ),
    );
  }
}
