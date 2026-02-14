import 'package:flutter/material.dart';

class CustomLoadingIndicator extends StatefulWidget {
  final double size;
  
  const CustomLoadingIndicator({
    super.key, 
    this.size = 50.0,
  });

  @override
  State<CustomLoadingIndicator> createState() => _CustomLoadingIndicatorState();
}

class _CustomLoadingIndicatorState extends State<CustomLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  
  // Total de frames en la carpeta assets/Loading_Frames/
  final int _frameCount = 45;

  @override
  void initState() {
    super.initState();
    // Ajustamos la duración para que la animación se vea natural
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), 
    )..repeat();

    _animation = IntTween(begin: 1, end: _frameCount).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final int frame = _animation.value;
          return Image.asset(
            'assets/Loading_Frames/$frame.webp',
            fit: BoxFit.contain,
            gaplessPlayback: true, // Evita parpadeos al cambiar de imagen
          );
        },
      ),
    );
  }
}
