import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StudentService {
  // Asumimos que el script PHP está accesible en esta ruta basándonos en la estructura del proyecto web.
  // Esta URL conecta directamente con la API que consulta la base de datos 'parlando_students'.
  static const String _studentsApiUrl = 'https://parlandolingue.edu.co/assets/php/list_students.php';

  static final StudentService _instance = StudentService._internal();
  factory StudentService() => _instance;
  StudentService._internal();

  // Variables de caché para evitar saturar el servidor con peticiones repetidas
  Map<String, dynamic>? _cachedStudentData;
  DateTime? _lastFetchTime;

  Future<Map<String, dynamic>?> getStudentProfile() async {
    // Si tenemos datos en caché y son recientes (menos de 5 minutos), los usamos.
    if (_cachedStudentData != null && 
        _lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
      return _cachedStudentData!;
    }

    try {
      final user = await AuthService().getUserData();
      if (user == null || user['username'] == null) {
        throw Exception('El usuario no ha iniciado sesión');
      }
      final String currentUsername = user['username'];

      // Añadimos un timestamp a la URL para evitar que el navegador/proxy cachee la respuesta
      final response = await http.get(Uri.parse('$_studentsApiUrl?_t=${DateTime.now().millisecondsSinceEpoch}'));

      if (response.statusCode != 200) {
        throw Exception('Fallo al cargar los datos del estudiante desde el servidor');
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['students'] == null) {
        throw Exception('Respuesta inválida de la API');
      }

      final List students = data['students'];
      
      // Buscamos al estudiante específico por nombre de usuario (ignorando mayúsculas/minúsculas)
      final student = students.firstWhere(
        (s) => s['userName']?.toString().toLowerCase() == currentUsername.toLowerCase(),
        orElse: () => null,
      );

      if (student != null) {
        // Procesamos la información de pagos y cuotas para facilitar su visualización en la UI
        student['computed_payment_status'] = _computePaymentStatus(student);
        _cachedStudentData = student as Map<String, dynamic>;
        _lastFetchTime = DateTime.now();
        return _cachedStudentData;
      }
      
      return null; // El estudiante no fue encontrado en la lista devuelta por el servidor

    } catch (e) {
      print('Error obteniendo el perfil del estudiante: $e');
      return null;
    }
  }

  // Método auxiliar para analizar el estado de los pagos (Contado vs Cuotas)
  Map<String, dynamic> _computePaymentStatus(Map<String, dynamic> student) {
    // Valores por defecto
    int totalQuotas = 0;
    int paidQuotas = 0;
    double paidAmount = 0;
    double totalAmount = double.tryParse(student['totalAmount']?.toString() ?? '0') ?? 0;
    String method = student['paymentMethod'] ?? 'Desconocido';
    bool isFullyPaid = false;

    if (method.toLowerCase().contains('contado')) {
      isFullyPaid = true; // Asumimos que el pago de contado implica totalidad pagada
      paidAmount = totalAmount;
    } else {
      // Analizamos el array de cuotas si existe
      if (student['quotas'] != null && student['quotas'] is List) {
        final List quotas = student['quotas'];
        totalQuotas = quotas.length;
        for (var q in quotas) {
          // Verificamos si la cuota está marcada como pagada (puede venir como bool, string 'true', o int 1)
          bool isPaid = q['paid'] == true || q['paid'] == 'true' || q['paid'] == 1;
          if (isPaid) {
            paidQuotas++;
            paidAmount += double.tryParse(q['amount']?.toString() ?? '0') ?? 0;
          }
        }
      }
      // Si no hay cuotas definidas pero tampoco es contado, es un caso ambiguo.
      // Si todas las cuotas listadas están pagas, marcamos como pagado total.
      if (totalQuotas > 0 && paidQuotas == totalQuotas) {
        isFullyPaid = true;
      }
    }

    return {
      'method': method,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'totalQuotas': totalQuotas,
      'paidQuotas': paidQuotas,
      'isFullyPaid': isFullyPaid,
    };
  }

  // Limpiar caché (útil después de actualizar el perfil o cerrar sesión)
  void clearCache() {
    _cachedStudentData = null;
  }
}
