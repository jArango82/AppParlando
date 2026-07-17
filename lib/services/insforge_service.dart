import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Servicio singleton que encapsula las llamadas REST al backend de InsForge.
///
/// Provee métodos para interactuar con:
/// - **Database**: operaciones CRUD via PostgREST (query, insert, upsert, update, delete).
/// - **Storage**: subir archivos, obtener URLs públicas, verificar existencia.
///
/// Se inicializa automáticamente leyendo `INSFORGE_URL` e `INSFORGE_ANON_KEY`
/// desde las variables de entorno (env.txt).
class InsforgeService {
  static final InsforgeService _instance = InsforgeService._internal();
  factory InsforgeService() => _instance;
  InsforgeService._internal();

  /// URL base del backend InsForge.
  String get baseUrl => dotenv.env['INSFORGE_URL'] ?? '';

  /// Clave anónima (JWT) para autenticación pública.
  String get anonKey => dotenv.env['INSFORGE_ANON_KEY'] ?? '';

  /// Headers comunes para todas las peticiones.
  Map<String, String> get _headers => {
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      };

  // ── DATABASE ──────────────────────────────────────────────────

  /// Consulta registros de una tabla con filtros opcionales.
  ///
  /// [table]: nombre de la tabla.
  /// [filters]: mapa de filtros PostgREST (ej. {'moodle_user_id': 'eq.123'}).
  /// [select]: columnas a retornar (separadas por coma).
  ///
  /// Retorna una lista de mapas con los registros encontrados.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    Map<String, String>? filters,
    String? select,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (filters != null) queryParams.addAll(filters);
    if (select != null) queryParams['select'] = select;
    if (limit != null) queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/api/database/records/$table')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw InsforgeException(
      'Error consultando tabla $table',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  /// Consulta un solo registro. Retorna null si no existe.
  Future<Map<String, dynamic>?> querySingle(
    String table, {
    Map<String, String>? filters,
    String? select,
  }) async {
    final results = await query(table, filters: filters, select: select, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  /// Inserta uno o más registros en una tabla.
  ///
  /// [records]: lista de mapas con los datos a insertar.
  /// Retorna los registros creados.
  Future<List<Map<String, dynamic>>> insert(
    String table,
    List<Map<String, dynamic>> records,
  ) async {
    final uri = Uri.parse('$baseUrl/api/database/records/$table');
    final headers = {
      ..._headers,
      'Prefer': 'return=representation',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(records),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw InsforgeException(
      'Error insertando en tabla $table',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  /// Upsert (insert o update en conflicto) de registros.
  ///
  /// Usa el header `Prefer: resolution=merge-duplicates` para hacer upsert
  /// basado en la primary key de la tabla.
  Future<List<Map<String, dynamic>>> upsert(
    String table,
    List<Map<String, dynamic>> records,
  ) async {
    final uri = Uri.parse('$baseUrl/api/database/records/$table');
    final headers = {
      ..._headers,
      'Prefer': 'resolution=merge-duplicates,return=representation',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(records),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw InsforgeException(
      'Error haciendo upsert en tabla $table',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  // ── STORAGE ───────────────────────────────────────────────────

  /// URL base del servidor de funciones de InsForge.
  String get _functionsBaseUrl {
    // Las funciones de InsForge usan un subdominio diferente:
    // backend: https://XXXX.us-east.insforge.app
    // functions: https://XXXX.functions.insforge.app
    final uri = Uri.parse(baseUrl);
    final host = uri.host; // e.g. 4mjsj3y6.us-east.insforge.app
    final parts = host.split('.');
    if (parts.length >= 3) {
      // Reemplazar la parte del medio (us-east) con 'functions'
      parts[1] = 'functions';
      return '${uri.scheme}://${parts.join('.')}';
    }
    return baseUrl; // fallback
  }

  /// Sube un archivo a un bucket de InsForge Storage via Edge Function.
  ///
  /// Usa la función serverless `upload-avatar` que corre con permisos
  /// elevados en el servidor, resolviendo el problema de que el rol `anon`
  /// no tiene acceso al esquema `storage`.
  ///
  /// [bucket]: nombre del bucket (actualmente solo 'avatars').
  /// [objectKey]: clave/nombre del archivo en el bucket.
  /// [file]: archivo local a subir.
  /// [contentType]: tipo MIME del archivo.
  ///
  /// Retorna la URL pública completa del objeto subido.
  Future<String> uploadFile(
    String bucket,
    String objectKey,
    File file, {
    String contentType = 'image/jpeg',
  }) async {
    // Extraer el username del objectKey (formato: username_avatar.jpg)
    final username = objectKey.replaceAll('_avatar.jpg', '');

    final uri = Uri.parse('$_functionsBaseUrl/upload-avatar');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $anonKey';
    request.fields['username'] = username;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final String url = data['url'] ?? '';

      // Si la URL es relativa, construir la absoluta
      if (url.startsWith('/')) {
        return '$baseUrl$url';
      }
      return url;
    }

    throw InsforgeException(
      'Error subiendo archivo via función: $bucket/$objectKey',
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  /// Obtiene la URL pública completa de un objeto en un bucket público.
  String getPublicUrl(String bucket, String objectKey) {
    return '$baseUrl/api/storage/buckets/$bucket/objects/$objectKey';
  }

  /// Verifica si un archivo existe en un bucket usando una petición HEAD.
  ///
  /// Retorna true si el archivo existe (HTTP 200), false en caso contrario.
  Future<bool> fileExists(String bucket, String objectKey) async {
    try {
      final url = getPublicUrl(bucket, objectKey);
      final uri = Uri.parse(url);
      final request = await HttpClient().headUrl(uri);
      request.headers.set('Authorization', 'Bearer $anonKey');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('InsforgeService.fileExists: Error verificando $bucket/$objectKey: $e');
      return false;
    }
  }
}

/// Excepción personalizada para errores de InsForge.
class InsforgeException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  const InsforgeException(this.message, {this.statusCode, this.body});

  @override
  String toString() =>
      'InsforgeException: $message (status: $statusCode, body: $body)';
}
