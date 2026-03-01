import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar el servicio de notificaciones locales
  await NotificationService().initialize();

  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://dwrspwwylwjfupzpzmvq.supabase.co',
    anonKey: 'sb_publishable_DbIk88XbsHAy56q0bOe0JQ_0t8IJOae',
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Parlando',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
