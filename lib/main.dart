import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'splash_screen.dart';
import 'services/notification_service.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno ocultas
  await dotenv.load(fileName: "env.txt");

  // Inicializar el servicio de notificaciones locales
  await NotificationService().initialize();

  // Inicializar el tema (lee preferencia de SharedPreferences)
  await ThemeProvider.init();

  // InsForge se inicializa automáticamente como singleton lazy
  // al leer las variables de entorno INSFORGE_URL e INSFORGE_ANON_KEY.

  runApp(const MainApp());
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
