import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_screen.dart'; // Esteban bb aquí es a donde iremos nosotros después del video

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
    // Arango, reduje el tiempo antes de reproducir porque queríamos que fuera fluido
    Timer(const Duration(seconds: 1), () {
      setState(() {
        _showVideo = true;
      });
      _controller.play();
    });
  }

  void _navigateToHome() {
    // Listo bb, nos vamos a la Home sin animación de transición (instantáneo)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
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
            // Arango, mientras pasan los segundos iniciales no mostramos nada (SizedBox)
            // Solo se verá el color de fondo limpio, sin logo pre-cargado que parpadee
            : const SizedBox(), 
      ),
    );
  }
}
