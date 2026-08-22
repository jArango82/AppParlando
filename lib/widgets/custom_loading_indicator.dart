import 'package:flutter/material.dart';

/// Loading clásico: flipbook de `assets/Loading_Frames/1..45.webp`.
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
  final int _frameCount = 45;

  @override
  void initState() {
    super.initState();
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
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}

/// Misma animación de frames del globo + nubes bajando (imagen asset).
class BalloonCloudLoadingIndicator extends StatefulWidget {
  final double size;

  /// Si es true, ocupa todo el espacio disponible (pantalla completa).
  final bool expand;

  const BalloonCloudLoadingIndicator({
    super.key,
    this.size = 120.0,
    this.expand = false,
  });

  @override
  State<BalloonCloudLoadingIndicator> createState() =>
      _BalloonCloudLoadingIndicatorState();
}

class _BalloonCloudLoadingIndicatorState
    extends State<BalloonCloudLoadingIndicator>
    with TickerProviderStateMixin {
  static const String _cloudAsset = 'assets/clouds/cloud.png';

  // (fase, xRel, widthFactor, speed, opacity, grayAmount 0=blanco 1=gris)
  static const List<(double, double, double, double, double, double)> _backClouds = [
    (0.00, 0.12, 0.46, 0.80, 0.90, 0.35),
    (0.28, 0.62, 0.40, 0.95, 0.85, 0.55),
    (0.55, 0.35, 0.52, 0.70, 0.88, 0.25),
    (0.78, 0.82, 0.36, 1.05, 0.86, 0.45),
  ];

  static const List<(double, double, double, double, double, double)> _frontClouds = [
    (0.10, 0.22, 0.55, 1.20, 1.0, 0.0),
    (0.42, 0.70, 0.48, 1.05, 0.98, 0.15),
    (0.72, 0.08, 0.44, 1.30, 0.95, 0.0),
  ];

  late AnimationController _frameController;
  late AnimationController _cloudController;
  late Animation<int> _frameAnimation;
  final int _frameCount = 45;

  @override
  void initState() {
    super.initState();
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _frameAnimation =
        IntTween(begin: 1, end: _frameCount).animate(_frameController);

    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _frameController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  Widget _buildCloudImage({
    required double width,
    required double opacity,
    required double grayAmount,
  }) {
    if (opacity <= 0.02) return const SizedBox.shrink();

    final height = width * 0.55;
    final tint = Color.lerp(
      Colors.white,
      const Color(0xFFD1D5DB),
      grayAmount.clamp(0.0, 1.0),
    )!;

    return SizedBox(
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Image.asset(
          _cloudAsset,
          width: width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          // Tiñe sin ColorFiltered (evita parpadeos negros en algunos devices)
          color: tint,
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (_, _, _) => Icon(
            Icons.cloud,
            size: width * 0.5,
            color: tint,
          ),
        ),
      ),
    );
  }

  /// Fade en bordes para que el reinicio del loop no se note.
  double _edgeFade({
    required double y,
    required double cloudH,
    required double areaH,
  }) {
    const fadeZone = 0.18; // 18% superior/inferior
    final zone = areaH * fadeZone;
    final top = ((y + cloudH * 0.3) / zone).clamp(0.0, 1.0);
    final bottom = ((areaH - y - cloudH * 0.2) / zone).clamp(0.0, 1.0);
    return top * bottom;
  }

  List<Widget> _buildFallingClouds({
    required Size area,
    required double progress,
    required List<(double, double, double, double, double, double)> specs,
    required double bottomReserve,
  }) {
    // Viajan fuera de pantalla (arriba/abajo) para ocultar el wrap del loop
    final usableH = (area.height - bottomReserve).clamp(1.0, area.height);
    final cloudHApprox = area.width * 0.28;
    final travel = usableH + cloudHApprox * 2;

    return specs.map((c) {
      final phase = c.$1;
      final xRel = c.$2;
      final widthFactor = c.$3;
      final speed = c.$4;
      final baseOpacity = c.$5;
      final grayAmount = c.$6;

      final cloudW = area.width * widthFactor;
      final cloudH = cloudW * 0.55;
      // Empieza totalmente arriba (invisible) y termina totalmente abajo
      final y = ((progress * speed + phase) % 1.0) * travel - cloudH;
      final x = area.width * xRel - cloudW / 2;

      final fade = _edgeFade(y: y, cloudH: cloudH, areaH: usableH);
      final opacity = baseOpacity * fade;

      if (opacity <= 0.02 || y > usableH) {
        return const SizedBox.shrink();
      }

      return Positioned(
        left: x,
        top: y,
        child: _buildCloudImage(
          width: cloudW,
          opacity: opacity,
          grayAmount: grayAmount,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Reserva zona del texto "Cargando…" para que las nubes no pasen ahí
    final bottomReserve = widget.expand ? (bottomInset + 120) : 0.0;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(
          constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : size * 1.7,
          constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : size * 1.6,
        );

        return AnimatedBuilder(
          animation: Listenable.merge([_frameAnimation, _cloudController]),
          builder: (context, _) {
            final frame = _frameAnimation.value;
            final t = _cloudController.value;

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: _buildFallingClouds(
                      area: area,
                      progress: t,
                      specs: _backClouds,
                      bottomReserve: bottomReserve,
                    ),
                  ),
                ),
                Center(
                  child: Image.asset(
                    'assets/Loading_Frames/$frame.webp',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: _buildFallingClouds(
                      area: area,
                      progress: (t * 1.35) % 1.0,
                      specs: _frontClouds,
                      bottomReserve: bottomReserve,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (widget.expand) {
      return SizedBox.expand(child: content);
    }

    return SizedBox(
      width: size * 1.7,
      height: size * 1.6,
      child: content,
    );
  }
}

/// Pantalla completa de carga con globo + nubes bajando.
Future<void> showBalloonCloudLoadingPreview(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, anim, secondary) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: isDark ? const Color(0xFF0F1117) : const Color(0xFF6BA4D8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BalloonCloudLoadingIndicator(
                size: MediaQuery.sizeOf(context).shortestSide * 0.38,
                expand: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 36,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : const Color(0xFF4A90C8))
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Cargando…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Toca para cerrar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, secondary, child) {
      return FadeTransition(opacity: anim, child: child);
    },
  );
}
