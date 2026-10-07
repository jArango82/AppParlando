import 'dart:convert';
import 'net.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_parlando/services/auth_service.dart';
import 'package:app_parlando/services/course_lock_service.dart';

class CourseService {
  static const String _moodleBaseUrl = 'https://campus.parlandolingue.com';
  static const String _restUrl = '$_moodleBaseUrl/webservice/rest/server.php';

  // Caché en memoria para evitar llamadas repetidas a _getSiteInfo
  static int? _cachedUserId;
  static String? _cachedFullname;

  /// Al cerrar sesión, para que el siguiente usuario no herede el userId anterior.
  static void clearCache() {
    _cachedUserId = null;
    _cachedFullname = null;
  }

  /// Resuelve userId y fullname. Si moodle_id no está en SharedPreferences,
  /// lo obtiene de _getSiteInfo y lo guarda para futuras llamadas.
  Future<Map<String, dynamic>> _resolveUser(String token) async {
    // 1. Caché en memoria (más rápido)
    if (_cachedUserId != null) {
      return {'userId': _cachedUserId!, 'fullname': _cachedFullname ?? 'User'};
    }

    // 2. SharedPreferences
    final userData = await AuthService().getUserData();
    if (userData != null && userData['moodle_id'] != null) {
      _cachedUserId = userData['moodle_id'];
      _cachedFullname = userData['fullname'] ?? 'User';
      return {'userId': _cachedUserId!, 'fullname': _cachedFullname!};
    }

    // 3. Fallback: obtener de Moodle y guardar
    final userInfo = await _getSiteInfo(token);
    _cachedUserId = userInfo['userid'];
    _cachedFullname = userInfo['fullname'] ?? userData?['fullname'] ?? 'User';

    // Guardar moodle_id y fullname en SharedPreferences para que no se repita
    if (userData != null) {
      userData['moodle_id'] = _cachedUserId;
      if (userInfo['fullname'] != null) {
        userData['fullname'] = userInfo['fullname'];
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user_data', json.encode(userData));
    }

    return {'userId': _cachedUserId!, 'fullname': _cachedFullname!};
  }

  Future<List<dynamic>> getCourses() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No session token');

      final resolved = await _resolveUser(token);
      final courses = await _getEnrolledCourses(token, resolved['userId']);
      return courses;
    } catch (e) {
      throw Exception('Failed to load courses: $e');
    }
  }

  Future<Map<String, dynamic>> getCourseDetails(int courseId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No session token');

      final resolved = await _resolveUser(token);
      final int userId = resolved['userId'];

      // Parallelize requests
      final results = await Future.wait([
        _getCourseContents(token, courseId),
        _getGrades(token, courseId, userId),
      ]);

      final sections = results[0];
      final grades = results[1];

      // 3. Merge Data
      _mergeGradesIntoSections(sections, grades);

      return {'sections': sections};
    } catch (e) {
      throw Exception('Failed to load course details: $e');
    }
  }

  Future<Map<String, dynamic>> getCourseProgress() async {
    try {
      // 1. Get User Token
      final token = await AuthService().getToken();
      if (token == null) {
        throw Exception('No session token found. Please login again.');
      }

      // 2. Get User ID & Name (cached)
      final resolved = await _resolveUser(token);
      final int userId = resolved['userId'];
      final String fullname = resolved['fullname'];

      // 3. Get Enrolled Courses (using user token, not admin)
      // core_enrol_get_users_courses works for self enrollments
      final courses = await _getEnrolledCourses(token, userId);

      // If still empty, try fallback method (e.g. classification)
      if (courses.isEmpty) {
        // Log or try another method if available
        // But for now, just throw the specific error to help debug
        throw Exception('Student ($fullname, ID: $userId) is not enrolled in any visible courses.');
      }
      
      // Select the most relevant course (highest ID usually means latest)
      courses.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

      // Nivel más alto que el estudiante ya tiene desbloqueado.
      final visible =
          courses.where((c) => c['id'] != 9 && c['id'] != 10).toList();
      final locks = await CourseLockService.computeLocks(visible);
      final unlocked = visible
          .where((c) => locks[c['id']]?.locked != true)
          .toList()
        ..sort((a, b) => CourseLockService.levelOrder
            .indexOf(CourseLockService.levelOf(b) ?? '')
            .compareTo(CourseLockService.levelOrder
                .indexOf(CourseLockService.levelOf(a) ?? '')));
      final course = unlocked.isNotEmpty ? unlocked.first : courses.first;
      final int courseId = course['id'];

      final results = await Future.wait([
        _getCourseContents(token, courseId),
        _getGrades(token, courseId, userId),
      ]);
      final sections = results[0];
      _mergeGradesIntoSections(sections, results[1]);

      return {
        'course': {
          'id': courseId,
          'fullname': course['fullname'],
          'shortname': course['shortname'],
          'progress': course['progress'], // Often returned by get_users_courses
        },
        'sections': sections,
      };

    } catch (e) {
      throw Exception('Failed to load course progress: $e');
    }
  }

  Future<Map<String, dynamic>> _getSiteInfo(String token) async {
    final response = await http.get(
      Uri.parse('$_restUrl?wstoken=$token&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json')
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['userid'] != null) {
        return data;
      } else if (data['exception'] != null) {
        throw Exception(data['message']);
      }
    }
    throw Exception('Failed to get site info');
  }

  Future<List<dynamic>> _getEnrolledCourses(String token, int userId) async {
    // core_enrol_get_users_courses
    final response = await http.post(
      Uri.parse(_restUrl),
      body: {
        'wstoken': token,
        'wsfunction': 'core_enrol_get_users_courses',
        'moodlewsrestformat': 'json',
        'userid': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
       final data = json.decode(response.body);
       if (data is List) return data;
       if (data is Map && data['exception'] != null) {
         // Fallback: Try core_course_get_enrolled_courses_by_timeline_classification
         return await _getCoursesByTimeline(token);
       }
    }
    return [];
  }

  Future<List<dynamic>> _getCoursesByTimeline(String token) async {
      final response = await http.post(
        Uri.parse(_restUrl),
        body: {
          'wstoken': token,
          'wsfunction': 'core_course_get_enrolled_courses_by_timeline_classification',
          'moodlewsrestformat': 'json',
          'classification': 'all',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['courses'] != null) {
          return data['courses'];
        }
      }
      return [];
  }

  Future<List<dynamic>> _getCourseContents(String token, int courseId) async {
    final response = await http.post(
      Uri.parse(_restUrl),
      body: {
        'wstoken': token,
        'wsfunction': 'core_course_get_contents',
        'moodlewsrestformat': 'json',
        'courseid': courseId.toString(),
      },
    );

    if (response.statusCode == 200) {
       final data = json.decode(response.body);
       if (data is List) return data;
    }
    return [];
  }

  Future<List<dynamic>> _getGrades(String token, int courseId, int userId) async {
    final response = await http.post(
      Uri.parse(_restUrl),
      body: {
        'wstoken': token,
        'wsfunction': 'gradereport_user_get_grade_items',
        'moodlewsrestformat': 'json',
        'courseid': courseId.toString(),
        // userid usually optional for self if capability allows, but safer to pass
        'userid': userId.toString(), 
      },
    );

    if (response.statusCode == 200) {
       final data = json.decode(response.body);
       if (data is Map && data['usergrades'] != null) {
         final userGrades = data['usergrades'] as List;
         if (userGrades.isNotEmpty) {
           return userGrades[0]['gradeitems'] ?? [];
         }
       }
    }
    return [];
  }

  void _mergeGradesIntoSections(List<dynamic> sections, List<dynamic> grades) {
    // iteminstance solo es único dentro de cada tipo de módulo (un quiz y una tarea
    // pueden tener la misma instance), y los totales de curso/categoría también
    // traen iteminstance. Por eso la clave es "módulo:instancia" y solo ítems de actividad.
    final gradeMap = <String, dynamic>{};
    for (var g in grades) {
      if (g['itemtype'] == 'mod' &&
          g['itemmodule'] != null &&
          g['iteminstance'] != null) {
        gradeMap['${g['itemmodule']}:${g['iteminstance']}'] = g;
      }
    }

    for (var section in sections) {
        if (section['modules'] == null) continue;
        for (var module in section['modules']) {
           final key = '${module['modname']}:${module['instance']}';
           if (module['instance'] != null && gradeMap.containsKey(key)) {
             final gradeItem = gradeMap[key];
             if (gradeItem['gradeformatted'] != null && gradeItem['gradeformatted'] != '-') {
                 module['grade'] = gradeItem['gradeformatted'];
                 module['graderaw'] = gradeItem['graderaw'];
                 module['completionState'] = 1; 
             }
           }
        }
    }
  }
}
