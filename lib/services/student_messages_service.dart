import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio para mensajes asesor → estudiante (`student_messages` en Parlando).
///
/// Incluye check ligero para polling sin descargar toda la lista.
class StudentMessagesService {
  static const String _apiUrl =
      'https://parlandolingue.com/assets/php/student_messages.php';

  static final StudentMessagesService _instance =
      StudentMessagesService._internal();
  factory StudentMessagesService() => _instance;
  StudentMessagesService._internal();

  List<Map<String, dynamic>>? _cachedMessages;
  String? _cachedStudentId;
  DateTime? _lastFetchTime;

  /// Lista mensajes del estudiante (más recientes primero).
  /// Usa caché en memoria ~2 minutos para no saturar el servidor.
  Future<List<Map<String, dynamic>>> getMessages(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    if (studentId.trim().isEmpty) return [];

    if (!forceRefresh &&
        _cachedMessages != null &&
        _cachedStudentId == studentId &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 2) {
      return _cachedMessages!;
    }

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'student_id': studentId,
      });
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['messages'] == null) {
        throw Exception('Respuesta inválida');
      }

      final List raw = data['messages'] as List;
      final messages = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      _cachedMessages = messages;
      _cachedStudentId = studentId;
      _lastFetchTime = DateTime.now();
      return messages;
    } catch (e) {
      debugPrint('StudentMessagesService.getMessages: $e');
      return _cachedMessages ?? [];
    }
  }

  /// Check ligero: ¿hay mensajes con id > [afterId]?
  ///
  /// Respuesta: `{ has_new: bool, count: int, max_id: int }`
  Future<Map<String, dynamic>> checkForNew({
    required String studentId,
    int afterId = 0,
  }) async {
    if (studentId.trim().isEmpty) {
      return {'has_new': false, 'count': 0, 'max_id': afterId};
    }

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'student_id': studentId,
        'check': '1',
        'after_id': afterId.toString(),
      });
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Respuesta inválida');
      }

      return {
        'has_new': data['has_new'] == true,
        'count': (data['count'] as num?)?.toInt() ?? 0,
        'max_id': (data['max_id'] as num?)?.toInt() ?? afterId,
      };
    } catch (e) {
      debugPrint('StudentMessagesService.checkForNew: $e');
      return {'has_new': false, 'count': 0, 'max_id': afterId};
    }
  }

  /// Id máximo conocido en la caché actual (0 si no hay mensajes).
  int maxCachedId() {
    if (_cachedMessages == null || _cachedMessages!.isEmpty) return 0;
    var maxId = 0;
    for (final m in _cachedMessages!) {
      final id = int.tryParse(m['id']?.toString() ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }
    return maxId;
  }

  /// Marca todos los mensajes del estudiante como leídos.
  Future<bool> markAllAsRead(String studentId) async {
    if (studentId.trim().isEmpty) return false;
    try {
      final response = await http.put(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'student_id': studentId}),
      );
      if (response.statusCode == 200) {
        if (_cachedMessages != null && _cachedStudentId == studentId) {
          for (final m in _cachedMessages!) {
            m['is_read'] = true;
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('StudentMessagesService.markAllAsRead: $e');
      return false;
    }
  }

  void clearCache() {
    _cachedMessages = null;
    _cachedStudentId = null;
    _lastFetchTime = null;
  }
}
