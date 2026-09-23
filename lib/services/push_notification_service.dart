import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Handler de mensajes FCM en background (debe ser top-level).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    'FCM background: ${message.messageId} '
    'title=${message.notification?.title}',
  );
}

/// Push remoto vía Firebase Cloud Messaging (Android + iOS).
///
/// El permiso y el token FCM se piden solo cuando el estudiante
/// activa recordatorios.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _initialized = false;
  String? _cachedToken;

  bool get isInitialized => _initialized;
  String? get currentToken => _cachedToken;

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_isSupportedPlatform) {
      debugPrint('PushNotificationService: plataforma no soportada; se omite.');
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint(
          'FCM foreground: ${message.messageId} '
          'title=${message.notification?.title} '
          'data=${message.data}',
        );
        final title = message.notification?.title ?? 'Parlando';
        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            'Tienes un aviso nuevo';
        // En Android, FCM en foreground no muestra banner solo;
        // lo mostramos como notificación local.
        await NotificationService().showPushAlert(title: title, body: body);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM opened from notification: ${message.data}');
      });

      _initialized = true;
      debugPrint(
        'PushNotificationService: Firebase listo '
        '(${Platform.isIOS ? 'iOS' : 'Android'}).',
      );
    } catch (e) {
      debugPrint('PushNotificationService.initialize: $e');
    }
  }

  /// Pide permiso y obtiene el token FCM.
  Future<String?> requestPermissionAndGetToken() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_isSupportedPlatform || !_initialized) return null;

    try {
      final messaging = FirebaseMessaging.instance;

      if (Platform.isAndroid) {
        final granted =
            await NotificationService().requestAndroidNotificationsPermission();
        if (!granted) {
          debugPrint('PushNotificationService: permiso Android denegado');
          return null;
        }
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final status = settings.authorizationStatus;
      if (status == AuthorizationStatus.denied) {
        debugPrint('PushNotificationService: permiso denegado');
        return null;
      }

      await messaging.setAutoInitEnabled(true);
      if (Platform.isIOS) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      final token = await messaging.getToken();
      _cachedToken = token;
      if (token != null && token.length > 12) {
        debugPrint(
          'PushNotificationService: token FCM=${token.substring(0, 12)}…',
        );
      } else {
        debugPrint('PushNotificationService: token FCM=$token');
      }
      return token;
    } catch (e) {
      debugPrint('PushNotificationService.requestPermissionAndGetToken: $e');
      return null;
    }
  }

  void listenTokenRefresh(void Function(String token) onRefresh) {
    if (!_isSupportedPlatform) return;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _cachedToken = token;
      onRefresh(token);
    });
  }

  Future<void> clearToken() async {
    if (!_isSupportedPlatform || !_initialized) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      _cachedToken = null;
    } catch (e) {
      debugPrint('PushNotificationService.clearToken: $e');
    }
  }
}
