import 'package:shared_preferences/shared_preferences.dart';

/// Autenticación de profesores (misma lógica que Colaboradores.html).
/// No usa Moodle: cuentas locales + sesión en SharedPreferences.
class ProfessorAuth {
  ProfessorAuth._();

  static const _keyRole = 'user_role';
  static const _keyName = 'profesor_name';
  static const _keyUsername = 'profesor_username';

  static const _accounts = <MapEntry<String, String>>[
    MapEntry('Angelo', 'Parlando123'),
    MapEntry('Samuel', 'Parlando123'),
    MapEntry('Andres Granda', 'Parlando123'),
    MapEntry('Andres Botero', 'Parlando123'),
    MapEntry('Yojhan', 'Parlando123'),
    MapEntry('Paolo', 'Parlando123'),
  ];

  static const _canonicalNames = <String, String>{
    'angelo': 'Ángelo',
    'samuel': 'Samuel',
    'andres granda': 'Andrés Granda',
    'andres botero': 'Andrés Botero',
    'yojhan': 'Yojhan',
    'paolo': 'Paolo',
  };

  static String normalize(String? value) {
    var s = (value ?? '').trim().toLowerCase();
    const accents = <String, String>{
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    accents.forEach((from, to) => s = s.replaceAll(from, to));
    return s;
  }

  /// Intenta login de profesor. Devuelve el nombre canónico o null.
  static String? tryLogin(String username, String password) {
    final userNorm = normalize(username);
    for (final account in _accounts) {
      if (normalize(account.key) == userNorm && account.value == password) {
        return _canonicalNames[userNorm] ?? account.key;
      }
    }
    return null;
  }

  static Future<void> saveSession({
    required String displayName,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, 'profesor');
    await prefs.setString(_keyName, displayName);
    await prefs.setString(_keyUsername, username.trim());
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole) == 'profesor' &&
        (prefs.getString(_keyName)?.isNotEmpty ?? false);
  }

  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyRole) != 'profesor') return null;
    return prefs.getString(_keyName);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
    await prefs.remove(_keyName);
    await prefs.remove(_keyUsername);
  }
}
