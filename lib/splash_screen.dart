import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_screen.dart'; // Esteban bb aquí es a donde iremos nosotros después del video
import 'package:app_parlando/services/auth_service.dart';
import 'main_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    _iniciarVideo();
  }

  void _iniciarVideo() {
    // Esteban, aquí preparamos el video que queremos mostrar
    _controller = VideoPlayerController.asset('assets/Splash-Screen.mp4')
      ..initialize().then((_) {
        _controller.setPlaybackSpeed(1.5);
        // Esto nos asegura que el video esté listo para arrancar sin parpadeos bb
        setState(() {});
      });

    // bb aquí escuchamos cuando el video termina para cambiar de pantalla
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration) {
        _navigateToHome();
      }
    });

    // Primero mostramos nuestro logo por 2 segundos, y luego boom soltamos el video
    Timer(const Duration(seconds: 1), () {
      setState(() {
        _showVideo = true;
      });
      _controller.play();
    });
  }

  Future<void> _navigateToHome() async {
    // Check if user is logged in
    final isLoggedIn = await AuthService().isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // OJO AQUÍ ESTEBAN: Cambié este color para que sea igual al fondo de nuestro video
  final Color _backgroundColor = const Color(0xFFFFFFFF); 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, 
      body: Center(
        child: _showVideo && _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            // bb mientras pasan los segundos iniciales no mostramos nada (SizedBox)
            // Solo se verá el color de fondo limpio, sin logo pre-cargado que parpadee
            : const SizedBox(), 
      ),
    );
  }
}
