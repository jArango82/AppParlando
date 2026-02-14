import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_parlando/services/auth_service.dart';

class CourseService {
  static const String _moodleBaseUrl = 'https://campus.parlandolingue.edu.co';
  static const String _restUrl = '$_moodleBaseUrl/webservice/rest/server.php';

  Future<List<dynamic>> getCourses() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No session token');

      final userData = await AuthService().getUserData();
      final int userId = userData != null ? userData['moodle_id'] : (await _getSiteInfo(token))['userid'];

      final courses = await _getEnrolledCourses(token, userId);
      return courses;
    } catch (e) {
      throw Exception('Failed to load courses: $e');
    }
  }

  Future<Map<String, dynamic>> getCourseDetails(int courseId) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No session token');

      final userData = await AuthService().getUserData();
      final int userId = userData != null ? userData['moodle_id'] : (await _getSiteInfo(token))['userid'];

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

      // 2. Get User ID & Name (locally if possible)
      int userId;
      String fullname;
      final userData = await AuthService().getUserData();
      
      if (userData != null) {
        userId = userData['moodle_id'];
        fullname = userData['fullname'] ?? 'User';
      } else {
        final userInfo = await _getSiteInfo(token);
        userId = userInfo['userid'];
        fullname = userInfo['fullname'];
      }

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
      final course = courses.first; 
      final int courseId = course['id'];

      // 4. Get Course Contents & Grades in Parallel
      final results = await Future.wait([
        _getCourseContents(token, courseId),
        _getGrades(token, courseId, userId),
      ]);

      final sections = results[0];
      final grades = results[1];

      // 6. Merge Data
      _mergeGradesIntoSections(sections, grades);

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
    final gradeMap = <int, dynamic>{};
    for (var g in grades) {
      if (g['iteminstance'] != null) {
        gradeMap[g['iteminstance']] = g;
      }
    }

    for (var section in sections) {
        if (section['modules'] == null) continue;
        for (var module in section['modules']) {
           final instanceId = module['instance'];
           if (instanceId != null && gradeMap.containsKey(instanceId)) {
             final gradeItem = gradeMap[instanceId];
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
