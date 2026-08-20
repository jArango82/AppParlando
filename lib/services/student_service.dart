import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StudentService {
  // Asumimos que el script PHP está accesible en esta ruta basándonos en la estructura del proyecto web.
  // Esta URL conecta directamente con la API que consulta la base de datos 'parlando_students'.
  static const String _studentsApiUrl = 'https://parlandolingue.com/assets/php/list_students.php';

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
        student['paymentPlans'] = _normalizePaymentPlans(student);
        _cachedStudentData = student as Map<String, dynamic>;
        _lastFetchTime = DateTime.now();
        return _cachedStudentData;
      }
      
      return null; // El estudiante no fue encontrado en la lista devuelta por el servidor

    } catch (e) {
      debugPrint('Error obteniendo el perfil del estudiante: $e');
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

  /// Normaliza los planes de pago de Estado Estudiante para solo lectura en la app.
  /// Si la API no trae `paymentPlans` pero sí datos legacy, arma un plan sintético.
  List<Map<String, dynamic>> _normalizePaymentPlans(Map<String, dynamic> student) {
    final List<Map<String, dynamic>> plans = [];

    if (student['paymentPlans'] != null && student['paymentPlans'] is List) {
      for (final raw in student['paymentPlans'] as List) {
        if (raw is! Map) continue;
        plans.add(_enrichPlan(Map<String, dynamic>.from(raw)));
      }
    }

    // Fallback: matrícula legacy sin planes migrados aún
    if (plans.isEmpty &&
        (student['paymentMethod'] != null &&
            student['paymentMethod'].toString().trim().isNotEmpty)) {
      plans.add(_enrichPlan({
        'id': 0,
        'concept': 'Matrícula / Inscripción',
        'paymentMethod': student['paymentMethod'],
        'totalAmount': student['totalAmount'] ?? 0,
        'contadoPaid': student['contadoPaid'] == true ||
            student['contadoPaid'] == 1 ||
            student['contadoPaid'] == 'true',
        'quotas': student['quotas'] is List ? student['quotas'] : [],
        'createdAt': student['registrationDate'],
      }));
    }

    return plans;
  }

  Map<String, dynamic> _enrichPlan(Map<String, dynamic> plan) {
    final String method = (plan['paymentMethod'] ?? '').toString();
    final double totalAmount =
        double.tryParse(plan['totalAmount']?.toString() ?? '0') ?? 0;
    final bool isContado = method.toLowerCase().contains('contado');
    final List quotas =
        plan['quotas'] is List ? List.from(plan['quotas'] as List) : [];

    int paidQuotas = 0;
    double paidAmount = 0;
    final List<Map<String, dynamic>> normalizedQuotas = [];

    for (var i = 0; i < quotas.length; i++) {
      final q = quotas[i];
      if (q is! Map) continue;
      final bool isPaid =
          q['paid'] == true || q['paid'] == 'true' || q['paid'] == 1;
      final double amount = double.tryParse(q['amount']?.toString() ?? '0') ?? 0;
      if (isPaid) {
        paidQuotas++;
        paidAmount += amount;
      }
      normalizedQuotas.add({
        'number': q['number'] ?? (i + 1),
        'day': q['day']?.toString() ?? '',
        'date': (q['date'] ?? q['day'])?.toString() ?? '',
        'amount': amount,
        'paid': isPaid,
      });
    }

    final bool contadoPaid = plan['contadoPaid'] == true ||
        plan['contadoPaid'] == 1 ||
        plan['contadoPaid'] == 'true';

    if (isContado) {
      paidAmount = contadoPaid ? totalAmount : 0;
    }

    final int pendingCount = isContado
        ? (contadoPaid ? 0 : 1)
        : (normalizedQuotas.length - paidQuotas);
    final bool isFullyPaid = isContado
        ? contadoPaid
        : (normalizedQuotas.isNotEmpty && pendingCount == 0);

    return {
      'id': plan['id'],
      'concept': (plan['concept'] ?? 'Plan de pago').toString(),
      'paymentMethod': method.isEmpty ? 'N/A' : method,
      'totalAmount': totalAmount,
      'contadoPaid': contadoPaid,
      'quotas': normalizedQuotas,
      'comments': plan['comments'] ?? '',
      'createdAt': plan['createdAt']?.toString(),
      'updatedAt': plan['updatedAt']?.toString(),
      'paidAmount': paidAmount,
      'paidQuotas': paidQuotas,
      'totalQuotas': normalizedQuotas.length,
      'pendingCount': pendingCount,
      'isFullyPaid': isFullyPaid,
    };
  }

  // Limpiar caché (útil después de actualizar el perfil o cerrar sesión)
  void clearCache() {
    _cachedStudentData = null;
  }
}
