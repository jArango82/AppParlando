import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // URLs principales del sistema
  static const String _moodleBaseUrl = 'https://campus.parlandolingue.edu.co';
  static const String _tokenUrl = '$_moodleBaseUrl/login/token.php';
  static const String _restUrl = '$_moodleBaseUrl/webservice/rest/server.php';
  
  // Token de Administrador (para consultas privilegiadas)
  static const String _adminToken = '95d1b208404ee73b87e212b4409a48ab';

  // Implementación del patrón Singleton para una única instancia del servicio
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Claves de almacenamiento local (SharedPreferences)
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user_data';
  static const String _keyCredentials = 'auth_credentials';
  static const String _keyMoodleSession = 'moodle_session_cookie';

  String get moodleBaseUrl => _moodleBaseUrl;

  // ── INICIO DE SESIÓN ────────────────────────────────────────────────
  
  // Realiza el proceso de login completo: Obtiene token, detalles del usuario y cookie de sesión web.
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // 1. Obtener Token de la API (Servicio moodle_mobile_app)
      final tokenResponse = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'username': username,
          'password': password,
          'service': 'moodle_mobile_app', 
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Error conectando con el servidor');
      }

      final tokenData = json.decode(tokenResponse.body);
      
      if (tokenData['error'] != null || tokenData['token'] == null) {
        throw Exception(tokenData['error'] ?? 'Credenciales inválidas');
      }

      final String userToken = tokenData['token'];

      // 2. Obtener Detalles del Usuario (Usando token de admin para buscar por username)
      final detailsResponse = await http.post(
        Uri.parse(_restUrl),
        body: {
          'wstoken': _adminToken,
          'wsfunction': 'core_user_get_users_by_field',
          'moodlewsrestformat': 'json',
          'field': 'username',
          'values[0]': username,
        },
      );

      Map<String, dynamic>? moodleUser;
      
      if (detailsResponse.statusCode == 200) {
        final detailsData = json.decode(detailsResponse.body);
        if (detailsData is List && detailsData.isNotEmpty) {
          moodleUser = detailsData[0];
        } else if (detailsData is Map && detailsData['exception'] != null) {
          // Si falla la búsqueda, intentamos obtener info básica del sitio
          moodleUser = await _fetchUserSiteInfo(userToken);
        }
      }

      // Si no logramos obtener detalles, usamos datos básicos
      if (moodleUser == null) {
         moodleUser = {'username': username, 'fullname': username};
      }

      // Estructuramos los datos del usuario para uso en la app
      final user = {
        'username': username,
        'fullname': moodleUser['fullname'] ?? username,
        'email': moodleUser['email'],
        'moodle_id': moodleUser['id'],
        'image_url': moodleUser['profileimageurl'],
      };

      // 3. Guardar todo localmente (Persistencia de sesión)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, userToken);
      await prefs.setString(_keyUser, json.encode(user));
      await prefs.setString(_keyCredentials, json.encode({
        'username': username,
        'password': password,
      }));

      // 4. Pre-generar cookie de sesión web para uso en WebViews transparentes
      await _refreshWebSession(username, password);

      return {
        'success': true,
        'user': user,
        'token': userToken,
      };

    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // ── SESIÓN WEB (Inyección de Cookies) ───────────────────────────────

  /// Realiza un inicio de sesión web real a través de HTTP para obtener la cookie MoodleSession.
  /// Esta cookie permite acceder a vistas web sin volver a loguearse.
  Future<String?> _refreshWebSession(String username, String password) async {
    final client = io.HttpClient();
    client.autoUncompress = true; // Maneja gzip automáticamente

    try {
      // Paso 1: GET a la página de login para extraer el logintoken (CSRF) y cookies iniciales
      final getRequest = await client.getUrl(Uri.parse('$_moodleBaseUrl/login/index.php'));
      final getResponse = await getRequest.close();
      final getBody = await getResponse.transform(const Utf8Decoder()).join();

      // Extraemos el logintoken del formulario HTML
      final tokenMatch = RegExp(r'name="logintoken"\s+value="([^"]+)"').firstMatch(getBody);
      final loginToken = tokenMatch?.group(1) ?? '';

      // Recolectamos las cookies de la respuesta GET
      final getCookies = getResponse.cookies;

      // Paso 2: POST con las credenciales + logintoken + cookies previas
      final postRequest = await client.postUrl(Uri.parse('$_moodleBaseUrl/login/index.php'));
      postRequest.headers.contentType = io.ContentType('application', 'x-www-form-urlencoded');
      postRequest.followRedirects = false; // Importante para capturar la cookie en la redirección

      // Adjuntamos las cookies obtenidas en el GET
      for (var cookie in getCookies) {
        postRequest.cookies.add(cookie);
      }

      final body = 'username=${Uri.encodeComponent(username)}'
          '&password=${Uri.encodeComponent(password)}'
          '&logintoken=${Uri.encodeComponent(loginToken)}';
      postRequest.write(body);

      final postResponse = await postRequest.close();
      // Consumimos el cuerpo de la respuesta para evitar fugas de memoria
      await postResponse.drain();

      // Paso 3: Extraemos la cookie MoodleSession de la respuesta del POST
      String? sessionCookie;
      for (var cookie in postResponse.cookies) {
        if (cookie.name == 'MoodleSession') {
          sessionCookie = cookie.value;
          break;
        }
      }

      if (sessionCookie != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyMoodleSession, sessionCookie);
        print('Debug: Cookie MoodleSession obtenida exitosamente');
      } else {
        print('Debug: Cookie MoodleSession NO encontrada en la respuesta');
      }

      return sessionCookie;
    } catch (e) {
      print('Debug: Error de sesión web: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Retorna la cookie de sesión web almacenada, o la refresca si es necesario.
  Future<String?> getWebSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    String? session = prefs.getString(_keyMoodleSession);

    if (session != null) return session;

    // Si no hay sesión, intentamos refrescarla usando las credenciales guardadas
    final creds = await getCredentials();
    if (creds != null) {
      session = await _refreshWebSession(creds['username']!, creds['password']!);
    }
    return session;
  }

  /// Fuerza el refresco de la sesión web (útil si la cookie expira)
  Future<String?> refreshWebSessionCookie() async {
    final creds = await getCredentials();
    if (creds != null) {
      return await _refreshWebSession(creds['username']!, creds['password']!);
    }
    return null;
  }

  // ── MÉTODOS AUXILIARES ──────────────────────────────────────────────

  // Obtiene información básica del usuario a través de webservice_get_site_info
  Future<Map<String, dynamic>?> _fetchUserSiteInfo(String token) async {
    try {
      final response = await http.get(Uri.parse('$_restUrl?wstoken=$token&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['userid'] != null) {
          return {
            'id': data['userid'],
            'fullname': data['fullname'],
            'profileimageurl': data['userpictureurl']
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyCredentials);
    await prefs.remove(_keyMoodleSession);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyToken);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString(_keyUser);
    if (userStr != null) {
      return json.decode(userStr);
    }
    return null;
  }

  Future<Map<String, String>?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final String? credStr = prefs.getString(_keyCredentials);
    if (credStr != null) {
      final decoded = json.decode(credStr);
      return {
        'username': decoded['username'],
        'password': decoded['password'],
      };
    }
    return null;
  }
}
