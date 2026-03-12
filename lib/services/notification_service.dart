import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'student_service.dart';

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Clave para guardar la última vez que se mostró la notificación
  static const String _keyLastNotificationTime =
      'last_contract_notification_time';
  // Intervalo de 72 horas entre notificaciones
  static const int _cooldownHours = 72;

  /// Inicializa el plugin de notificaciones locales.
  /// Debe llamarse al iniciar la app (en main.dart).
  Future<void> initialize() async {
    // Configuración para Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Configuración para iOS/macOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración general multiplataforma
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    // Solicitar permiso de notificaciones (Android 13+)
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Solicitar permiso de notificaciones (iOS)
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Verifica si deben mostrarse notificaciones de contrato y las muestra si corresponde.
  /// Lógica:
  /// 1. Verifica que hayan pasado al menos 72 horas desde la última notificación.
  /// 2. Obtiene los datos del estudiante para leer la fecha de fin de contrato (endDate).
  /// 3. Calcula los días restantes y muestra una notificación informativa.
  Future<void> checkAndShowContractNotification() async {
    try {
      // 1. Verificar cooldown de 72 horas
      final prefs = await SharedPreferences.getInstance();
      final int? lastNotificationMs = prefs.getInt(_keyLastNotificationTime);

      if (lastNotificationMs != null) {
        final DateTime lastNotification =
            DateTime.fromMillisecondsSinceEpoch(lastNotificationMs);
        final Duration elapsed = DateTime.now().difference(lastNotification);

        if (elapsed.inHours < _cooldownHours) {
          // No han pasado 72 horas, no mostramos notificación
          debugPrint(
              'Debug: Notificación omitida. Faltan ${_cooldownHours - elapsed.inHours}h para la próxima.');
          return;
        }
      }

      // 2. Obtener datos del estudiante
      final studentData = await StudentService().getStudentProfile();
      if (studentData == null) {
        debugPrint(
            'Debug: No se encontraron datos del estudiante para notificación.');
        return;
      }

      final String? endDateStr = studentData['endDate'];
      if (endDateStr == null ||
          endDateStr.isEmpty ||
          endDateStr == '0000-00-00') {
        debugPrint('Debug: Fecha de fin de contrato no disponible.');
        return;
      }

      // 3. Calcular días restantes
      final DateTime endDate = DateTime.parse(endDateStr);
      final DateTime now = DateTime.now();
      final int daysLeft = endDate.difference(now).inDays;

      // Construir título y cuerpo del mensaje según los días restantes
      String title;
      String body;

      if (daysLeft < 0) {
        title = '¡Atención! Contrato Vencido';
        body =
            'Tu contrato venció hace ${daysLeft.abs()} día${daysLeft.abs() == 1 ? '' : 's'}. '
            'Contacta a Parlando para renovarlo.';
      } else if (daysLeft == 0) {
        title = '¡Tu contrato vence hoy!';
        body =
            'Tu contrato finaliza hoy. Comunícate con Parlando para renovar.';
      } else if (daysLeft <= 7) {
        title = '¡Contrato por vencer!';
        body = 'Tu contrato vence en $daysLeft día${daysLeft == 1 ? '' : 's'}. '
            '¡Renueva pronto para no perder acceso!';
      } else if (daysLeft <= 30) {
        title = 'Contrato próximo a vencer';
        body = 'Tu contrato finaliza en $daysLeft días. '
            'Te recomendamos planificar tu renovación.';
      } else if (daysLeft <= 60) {
        title = 'Recordatorio de contrato';
        body =
            'Quedan $daysLeft días para que finalice tu contrato con Parlando.';
      } else {
        title = 'Estado de tu contrato';
        body =
            'Tu contrato con Parlando está vigente. Quedan $daysLeft días para su finalización.';
      }

      // 4. Mostrar la notificación con sonido personalizado
      await _showNotification(title, body);

      // 5. Guardar el timestamp actual para el cooldown de 72h
      await prefs.setInt(
          _keyLastNotificationTime, DateTime.now().millisecondsSinceEpoch);

      debugPrint(
          'Debug: Notificación de contrato mostrada. Días restantes: $daysLeft');
    } catch (e) {
      debugPrint('Error al verificar notificación de contrato: $e');
    }
  }

  /// Muestra una notificación local con sonido personalizado (notificacion.wav).
  Future<void> _showNotification(String title, String body) async {
    // Canal de Android con sonido personalizado
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'contract_reminder_channel', // ID del canal
      'Recordatorio de Contrato', // Nombre visible del canal
      channelDescription:
          'Notificaciones sobre el estado de tu contrato con Parlando',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound:
          RawResourceAndroidNotificationSound('notificacion'), // Sin extensión
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
    );

    // Configuración para iOS con sonido personalizado
    // El archivo notificacion.wav debe estar en ios/Runner/
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notificacion.wav', // Con extensión para iOS
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      1001, // ID fijo para notificaciones de contrato
      title,
      body,
      notificationDetails,
    );
  }

  /// Limpia el timestamp de la última notificación (al cerrar sesión).
  /// Esto asegura que al volver a iniciar sesión se muestre la notificación inmediatamente.
  Future<void> clearNotificationTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastNotificationTime);
  }
}
