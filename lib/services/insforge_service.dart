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

  /// Sube un archivo a un bucket de InsForge Storage.
  ///
  /// Intenta primero la Storage API directa (`upload-strategy`).
  /// Si falla por permisos, usa la edge function `upload-avatar`
  /// vía el proxy del backend (`/functions/{slug}`), no el subdominio
  /// legacy de Deno Deploy Classic (apagado el 20 jul 2026).
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
    try {
      return await _uploadViaStorageApi(
        bucket,
        objectKey,
        file,
        contentType: contentType,
      );
    } catch (storageError) {
      debugPrint(
        'InsforgeService.uploadFile: Storage API falló, '
        'intentando edge function. Detalle: $storageError',
      );
    }

    return _uploadViaEdgeFunction(
      bucket,
      objectKey,
      file,
      contentType: contentType,
    );
  }

  /// Subida directa con upload-strategy + PUT/POST (sin edge function).
  Future<String> _uploadViaStorageApi(
    String bucket,
    String objectKey,
    File file, {
    String contentType = 'image/jpeg',
  }) async {
    final fileBytes = await file.length();
    final strategyUri =
        Uri.parse('$baseUrl/api/storage/buckets/$bucket/upload-strategy');

    final strategyResponse = await http.post(
      strategyUri,
      headers: _headers,
      body: json.encode({
        'filename': objectKey,
        'contentType': contentType,
        'size': fileBytes,
      }),
    );

    if (strategyResponse.statusCode != 200 &&
        strategyResponse.statusCode != 201) {
      throw InsforgeException(
        'Error obteniendo estrategia de subida: $bucket/$objectKey',
        statusCode: strategyResponse.statusCode,
        body: strategyResponse.body,
      );
    }

    final strategy =
        json.decode(strategyResponse.body) as Map<String, dynamic>;
    final String method = (strategy['method'] ?? 'direct').toString();
    final String rawUploadUrl = (strategy['uploadUrl'] ?? '').toString();
    if (rawUploadUrl.isEmpty) {
      throw const InsforgeException('upload-strategy no devolvió uploadUrl');
    }

    final uploadUrl = rawUploadUrl.startsWith('/')
        ? '$baseUrl$rawUploadUrl'
        : rawUploadUrl;

    final request = http.MultipartRequest(
      method.toLowerCase() == 'presigned' ? 'POST' : 'PUT',
      Uri.parse(uploadUrl),
    );
    request.headers['Authorization'] = 'Bearer $anonKey';

    final fields = strategy['fields'];
    if (fields is Map) {
      fields.forEach((key, value) {
        request.fields[key.toString()] = value.toString();
      });
    }

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: objectKey,
    ));

    final streamedResponse = await request.send();
    final uploadResponse = await http.Response.fromStream(streamedResponse);

    if (uploadResponse.statusCode != 200 &&
        uploadResponse.statusCode != 201) {
      throw InsforgeException(
        'Error subiendo archivo via Storage API: $bucket/$objectKey',
        statusCode: uploadResponse.statusCode,
        body: uploadResponse.body,
      );
    }

    // Confirmar en backends S3 (presigned)
    if (strategy['confirmRequired'] == true) {
      final confirmPath = (strategy['confirmUrl'] ?? '').toString();
      final confirmUri = confirmPath.startsWith('/')
          ? Uri.parse('$baseUrl$confirmPath')
          : Uri.parse(
              confirmPath.isNotEmpty
                  ? confirmPath
                  : '$baseUrl/api/storage/buckets/$bucket/objects/$objectKey/confirm-upload',
            );

      final confirmResponse = await http.post(
        confirmUri,
        headers: _headers,
        body: json.encode({
          'size': fileBytes,
          'contentType': contentType,
        }),
      );

      if (confirmResponse.statusCode != 200 &&
          confirmResponse.statusCode != 201) {
        throw InsforgeException(
          'Error confirmando subida: $bucket/$objectKey',
          statusCode: confirmResponse.statusCode,
          body: confirmResponse.body,
        );
      }

      try {
        final data = json.decode(confirmResponse.body) as Map<String, dynamic>;
        final String url = (data['url'] ?? '').toString();
        if (url.startsWith('/')) return '$baseUrl$url';
        if (url.isNotEmpty) return url;
      } catch (_) {}
    } else {
      try {
        final data = json.decode(uploadResponse.body) as Map<String, dynamic>;
        final String url = (data['url'] ?? '').toString();
        if (url.startsWith('/')) return '$baseUrl$url';
        if (url.isNotEmpty) return url;
      } catch (_) {}
    }

    return getPublicUrl(bucket, objectKey);
  }

  /// Subida vía edge function `upload-avatar` (proxy InsForge).
  ///
  /// Envía JSON con el archivo en base64 porque el proxy de `/functions/{slug}`
  /// no reenvía bien `multipart/form-data`.
  Future<String> _uploadViaEdgeFunction(
    String bucket,
    String objectKey,
    File file, {
    String contentType = 'image/jpeg',
  }) async {
    final username = objectKey.replaceAll('_avatar.jpg', '');
    final bytes = await file.readAsBytes();
    final fileBase64 = base64Encode(bytes);

    final uri = Uri.parse('$baseUrl/functions/upload-avatar');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'username': username,
        'fileBase64': fileBase64,
        'contentType': contentType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final String url = data['url'] ?? '';

      if (url.startsWith('/')) {
        return '$baseUrl$url';
      }
      if (url.isNotEmpty) return url;
      return getPublicUrl(bucket, objectKey);
    }

    final body = response.body;
    final needsRedeploy = body.contains('DEPLOYMENT_NOT_FOUND') ||
        body.contains('Deno Deploy Classic');

    throw InsforgeException(
      needsRedeploy
          ? 'La función upload-avatar está caída (Deno Deploy Classic). '
              'Hay que actualizar el proyecto InsForge a v2.2.2+ y '
              'volver a desplegar la función upload-avatar.'
          : 'Error subiendo archivo via función: $bucket/$objectKey',
      statusCode: response.statusCode,
      body: body,
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
