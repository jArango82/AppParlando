import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Pantalla de logro ÉPICA que se muestra cuando el estudiante
/// completa una sección de diagnóstico.
class AchievementOverlay extends StatefulWidget {
  final String badgeAssetPath;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onDismiss;

  const AchievementOverlay({
    super.key,
    required this.badgeAssetPath,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required String badgeAssetPath,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return AchievementOverlay(
            badgeAssetPath: badgeAssetPath,
            title: title,
            subtitle: subtitle,
            gradientColors: gradientColors,
            onDismiss: () => Navigator.of(context).pop(),
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  State<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<AchievementOverlay>
    with TickerProviderStateMixin {
  // ── Controladores de animación ──
  late AnimationController _entranceController; // Entrada general
  late AnimationController _badgeController; // Badge bounce
  late AnimationController _raysController; // Rayos giratorios
  late AnimationController _ringsController; // Anillos de energía
  late AnimationController _glowPulseController; // Pulso del glow
  late AnimationController _confettiController; // Confetti
  late AnimationController _shimmerController; // Shimmer sobre badge
  late AnimationController _textController; // Texto

  // ── Animaciones ──
  late Animation<double> _entranceFade;
  late Animation<double> _badgeScale;
  late Animation<double> _badgeRotation;
  late Animation<double> _glowPulse;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _shimmerPosition;

  // ── Datos ──
  final List<_ConfettiPiece> _confetti = [];
  final List<_Sparkle> _sparkles = [];
  final Random _rng = Random();

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _generateConfetti();
    _generateSparkles();
    _startEpicSequence();
  }

  void _initAnimations() {
    // 1. Entrada global (fondo)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceFade =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);

    // 2. Badge: escala con rebote épico
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut),
    );
    // Pequeña rotación de entrada
    _badgeRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.easeOutBack),
    );

    // 3. Rayos giratorios (loop continuo)
    _raysController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // 4. Anillos de energía expandiéndose
    _ringsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 5. Glow pulsante
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowPulseController, curve: Curves.easeInOut),
    );

    // 6. Confetti
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // 7. Shimmer sobre badge
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // 8. Texto
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeOut);
  }

  void _generateConfetti() {
    final confettiColors = [
      widget.gradientColors[0],
      widget.gradientColors[1],
      const Color(0xFFFFD700),
      const Color(0xFFFF6B6B),
      const Color(0xFF48DBFB),
      const Color(0xFFFECA57),
      Colors.white,
      const Color(0xFF00D2D3),
      const Color(0xFFFF9FF3),
    ];

    for (int i = 0; i < 60; i++) {
      _confetti.add(_ConfettiPiece(
        x: _rng.nextDouble(),
        y: -_rng.nextDouble() * 0.3,
        size: _rng.nextDouble() * 10 + 4,
        speed: _rng.nextDouble() * 0.6 + 0.3,
        drift: (_rng.nextDouble() - 0.5) * 0.3,
        rotation: _rng.nextDouble() * 2 * pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 6,
        color: confettiColors[_rng.nextInt(confettiColors.length)],
        shape:
            _ConfettiShape.values[_rng.nextInt(_ConfettiShape.values.length)],
        delay: _rng.nextDouble() * 0.3,
      ));
    }
  }

  void _generateSparkles() {
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * pi;
      final distance = _rng.nextDouble() * 60 + 80;
      _sparkles.add(_Sparkle(
        angle: angle,
        distance: distance,
        size: _rng.nextDouble() * 4 + 2,
        delay: _rng.nextDouble() * 0.5,
        color: _rng.nextBool() ? Colors.white : const Color(0xFFFFD700),
      ));
    }
  }

  void _startEpicSequence() async {
    // Sonido
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.setSourceAsset('sound/achievement.wav');
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Debug: Error reproduciendo sonido: $e');
    }

    // Fase 1: Fondo aparece
    _entranceController.forward();
    await Future.delayed(const Duration(milliseconds: 300));

    // Fase 2: Rayos empiezan a girar
    _raysController.repeat();

    // Fase 3: Badge aparece con bounce épico
    await Future.delayed(const Duration(milliseconds: 200));
    _badgeController.forward();

    // Fase 4: Anillos de energía
    _ringsController.forward();
    _glowPulseController.repeat(reverse: true);

    // Fase 5: Confetti + shimmer
    await Future.delayed(const Duration(milliseconds: 400));
    _confettiController.forward();
    _shimmerController.repeat();

    // Fase 6: Texto
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();

    // Auto-cierre
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _entranceController.dispose();
    _badgeController.dispose();
    _raysController.dispose();
    _ringsController.dispose();
    _glowPulseController.dispose();
    _confettiController.dispose();
    _shimmerController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2 - 30);

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _entranceFade,
          builder: (context, child) {
            return Opacity(
              opacity: _entranceFade.value,
              child: child,
            );
          },
          child: Stack(
            children: [
              // ── Fondo con gradiente radial oscuro ──
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.5,
                    colors: [
                      widget.gradientColors[0].withValues(alpha: 0.3),
                      const Color(0xFF0A0E21).withValues(alpha: 0.97),
                      const Color(0xFF0A0E21),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // ── Rayos de luz giratorios ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _raysController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _LightRaysPainter(
                        center: center,
                        rotation: _raysController.value * 2 * pi,
                        color: widget.gradientColors[1],
                        opacity: _badgeScale.value.clamp(0.0, 1.0) * 0.15,
                      ),
                    );
                  },
                ),
              ),

              // ── Anillos de energía ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ringsController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _EnergyRingsPainter(
                        center: center,
                        progress: _ringsController.value,
                        color: widget.gradientColors[1],
                      ),
                    );
                  },
                ),
              ),

              // ── Confetti ──
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        confetti: _confetti,
                        progress: _confettiController.value,
                        size: size,
                      ),
                    );
                  },
                ),
              ),

              // ── Contenido central ──
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título: "¡LOGRO DESBLOQUEADO!" con efecto
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -_textSlide.value),
                            child:
                                Opacity(opacity: _textFade.value, child: child),
                          );
                        },
                        child: Column(
                          children: [
                            // Emoji + texto secundario
                            const Text(
                              '✦ ✦ ✦',
                              style: TextStyle(
                                fontSize: 18,
                                letterSpacing: 8,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Colors.white,
                                  Color(0xFFFFD700),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                '¡LOGRO DESBLOQUEADO!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 15,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── BADGE con glow, shimmer y sparkles ──
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _badgeController,
                          _glowPulseController,
                          _shimmerController,
                        ]),
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _badgeScale.value,
                            child: Transform.rotate(
                              angle: _badgeRotation.value,
                              child: SizedBox(
                                width: 260,
                                height: 260,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Glow exterior pulsante
                                    Container(
                                      width: 240,
                                      height: 240,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.gradientColors[0]
                                                .withValues(alpha: 
                                                    _glowPulse.value * 0.4),
                                            blurRadius: 80,
                                            spreadRadius: 30,
                                          ),
                                          BoxShadow(
                                            color: widget.gradientColors[1]
                                                .withValues(alpha: 
                                                    _glowPulse.value * 0.3),
                                            blurRadius: 50,
                                            spreadRadius: 15,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFFFFD700)
                                                .withValues(alpha: 
                                                    _glowPulse.value * 0.15),
                                            blurRadius: 100,
                                            spreadRadius: 40,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Sparkles alrededor del badge
                                    ..._sparkles.map((sparkle) {
                                      final progress =
                                          ((_badgeController.value -
                                                  sparkle.delay)
                                              .clamp(0.0, 1.0));
                                      final sparkleOpacity =
                                          (sin(progress * pi)).clamp(0.0, 1.0);
                                      final dx = cos(sparkle.angle) *
                                          sparkle.distance *
                                          progress;
                                      final dy = sin(sparkle.angle) *
                                          sparkle.distance *
                                          progress;

                                      return Positioned(
                                        left: 130 + dx - sparkle.size / 2,
                                        top: 130 + dy - sparkle.size / 2,
                                        child: Opacity(
                                          opacity: sparkleOpacity * 0.9,
                                          child: Container(
                                            width: sparkle.size,
                                            height: sparkle.size,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: sparkle.color,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: sparkle.color
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                    // Imagen del badge
                                    Image.asset(
                                      widget.badgeAssetPath,
                                      width: 190,
                                      height: 190,
                                      fit: BoxFit.contain,
                                    ),

                                    // Shimmer (brillo que recorre el badge)
                                    ClipOval(
                                      child: SizedBox(
                                        width: 190,
                                        height: 190,
                                        child: ShaderMask(
                                          shaderCallback: (bounds) {
                                            return LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withValues(alpha: 0.25),
                                                Colors.transparent,
                                              ],
                                              stops: [
                                                (_shimmerPosition.value - 0.3)
                                                    .clamp(0.0, 1.0),
                                                _shimmerPosition.value
                                                    .clamp(0.0, 1.0),
                                                (_shimmerPosition.value + 0.3)
                                                    .clamp(0.0, 1.0),
                                              ],
                                            ).createShader(bounds);
                                          },
                                          blendMode: BlendMode.srcATop,
                                          child: Container(
                                            color:
                                                Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 36),

                      // ── Texto inferior: nombre de la sección ──
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _textSlide.value * 0.8),
                            child:
                                Opacity(opacity: _textFade.value, child: child),
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.gradientColors[0].withValues(alpha: 0.3),
                                    widget.gradientColors[1].withValues(alpha: 0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color:
                                      widget.gradientColors[1].withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Indicador para continuar con animación de pulso
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.5, end: 1.0),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) {
                                return Opacity(opacity: value, child: child);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Toca para continuar',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAINTERS PERSONALIZADOS
// ═══════════════════════════════════════════════════════════════════════

/// Rayos de luz que giran detrás del badge
class _LightRaysPainter extends CustomPainter {
  final Offset center;
  final double rotation;
  final Color color;
  final double opacity;

  _LightRaysPainter({
    required this.center,
    required this.rotation,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    const rayCount = 12;
    const rayWidth = 0.08;
    final maxRadius = size.longestSide;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 2 * pi;
      final path = Path();
      path.moveTo(0, 0);
      path.lineTo(
        cos(angle - rayWidth) * maxRadius,
        sin(angle - rayWidth) * maxRadius,
      );
      path.lineTo(
        cos(angle + rayWidth) * maxRadius,
        sin(angle + rayWidth) * maxRadius,
      );
      path.close();

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxRadius));

      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter old) =>
      old.rotation != rotation || old.opacity != opacity;
}

/// Anillos de energía que se expanden
class _EnergyRingsPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final Color color;

  _EnergyRingsPainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final ringDelay = i * 0.15;
      final ringProgress =
          ((progress - ringDelay) / (1.0 - ringDelay)).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;

      final radius = 60.0 + ringProgress * 200;
      final opacity = (1.0 - ringProgress) * 0.6;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1.0 - ringProgress) + 0.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyRingsPainter old) =>
      old.progress != progress;
}

/// Confetti que cae con gravedad y rotación
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> confetti;
  final double progress;
  final Size size;

  _ConfettiPainter({
    required this.confetti,
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (var c in confetti) {
      final adjustedProgress =
          ((progress - c.delay) / (1.0 - c.delay)).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      // Posición con gravedad y drift lateral
      final x = c.x * size.width + c.drift * adjustedProgress * size.width;
      final y =
          c.y * size.height + adjustedProgress * c.speed * size.height * 1.3;
      final rotation = c.rotation + adjustedProgress * c.rotationSpeed;

      // Fade al final
      final opacity =
          adjustedProgress < 0.7 ? 1.0 : (1.0 - (adjustedProgress - 0.7) / 0.3);

      final paint = Paint()
        ..color = c.color.withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      switch (c.shape) {
        case _ConfettiShape.rectangle:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: c.size, height: c.size * 0.5),
              const Radius.circular(1),
            ),
            paint,
          );
          break;
        case _ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, c.size * 0.35, paint);
          break;
        case _ConfettiShape.triangle:
          final path = Path()
            ..moveTo(0, -c.size * 0.4)
            ..lineTo(c.size * 0.35, c.size * 0.3)
            ..lineTo(-c.size * 0.35, c.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case _ConfettiShape.star:
          _drawMiniStar(canvas, c.size * 0.4, paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawMiniStar(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? radius : radius * 0.4;
      final angle = (i * pi / 4) - pi / 2;
      final point = Offset(r * cos(angle), r * sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═══════════════════════════════════════════════════════════════════════

enum _ConfettiShape { rectangle, circle, triangle, star }

class _ConfettiPiece {
  final double x, y, size, speed, drift, rotation, rotationSpeed, delay;
  final Color color;
  final _ConfettiShape shape;

  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.shape,
    required this.delay,
  });
}

class _Sparkle {
  final double angle, distance, size, delay;
  final Color color;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.color,
  });
}
