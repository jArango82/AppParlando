import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'splash_screen.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cada paso se protege por separado: si uno falla la app debe arrancar igual,
  // en vez de quedarse congelada en el splash nativo sin llegar a runApp.

  // Cargar variables de entorno ocultas
  await _initStep('dotenv', () => dotenv.load(fileName: "env.txt"));

  // Inicializar el servicio de notificaciones locales
  await _initStep('notificaciones', () => NotificationService().initialize());

  // Firebase / FCM (Android e iOS)
  await _initStep('push', () => PushNotificationService().initialize());

  // Inicializar el tema (lee preferencia de SharedPreferences)
  await _initStep('tema', ThemeProvider.init);

  // InsForge se inicializa automáticamente como singleton lazy
  // al leer las variables de entorno INSFORGE_URL e INSFORGE_ANON_KEY.

  runApp(const MainApp());
}

Future<void> _initStep(String name, Future<void> Function() step) async {
  try {
    await step();
  } catch (e, st) {
    debugPrint('Arranque: falló "$name": $e\n$st');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeProvider.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'App Parlando',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
