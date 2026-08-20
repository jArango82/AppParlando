import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/courses_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/grades_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'theme_provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0; // Inicio en la pagina principal (Home)
  late AnimationController _animationController;
  late Animation<double>
      _positionAnimation; // Controla la posición horizontal (índice)

  // Iconos
  final List<IconData> _icons = [
    Icons.home,
    Icons.school,
    Icons.description,
    Icons.format_list_bulleted,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    // Empezamos en la posición 0.0 (Home)
    _positionAnimation =
        Tween<double>(begin: 0.0, end: 0.0).animate(_animationController);

    // Verificar y mostrar notificación de contrato después de que la UI se cargue
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().checkAndShowContractNotification();
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    // Animamos desde la posición actual hasta la nueva
    _positionAnimation = Tween<double>(
      begin: _positionAnimation.value,
      end: index.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic, // Desplazamiento fluido
    ));

    _animationController.reset();
    _animationController.forward();

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildNavigationRail(
    BuildContext context,
    Color barColor,
    Color activeBtnColor,
    Color activeIconColor,
    Color inactiveIconColor,
  ) {
    final isDark = context.isDarkMode;
    return Container(
      width: 90,
      color: barColor,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo arriba
            Image.asset(
              'assets/logo_001.webp',
              width: 50,
              height: 50,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, color: Colors.white, size: 40),
            ),
            const Spacer(),
            // Iconos de navegación vertical
            Column(
              children: List.generate(_icons.length, (index) {
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected ? activeBtnColor : Colors.transparent,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.blue.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      isSelected
                          ? (index == 4 ? Icons.person : _icons[index])
                          : _icons[index],
                      color: isSelected ? activeIconColor : inactiveIconColor.withValues(alpha: 0.7),
                      size: 26,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double itemWidth = size.width / _icons.length;

    final isDark = context.isDarkMode;
    final barColor = isDark ? context.cardColor : Colors.blue;
    final activeBtnColor = isDark ? Colors.blue : Colors.white;
    final activeIconColor = isDark ? Colors.white : Colors.blue;
    final inactiveIconColor = isDark ? Colors.grey.shade500 : Colors.white;

    final bool isWide = context.isWideScreen;

    if (isWide) {
      return Scaffold(
        backgroundColor: context.bgScaffold,
        body: Row(
          children: [
            _buildNavigationRail(
              context,
              barColor,
              activeBtnColor,
              activeIconColor,
              inactiveIconColor,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: context.borderColor,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  HomePage(isActive: _selectedIndex == 0), // Página 0 - Inicio
                  const CoursesScreen(), // Página 1 - Cursos
                  const DiagnosticsScreen(), // Página 2 - Diagnósticos
                  const GradesScreen(), // Página 3 - Notas
                  // Forzamos reconstrucción al entrar al perfil para actualizar datos (badges)
                  ProfileScreen(
                      key: _selectedIndex == 4 ? ValueKey(DateTime.now()) : null),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bgScaffold, // Fondo dinámico

      body: Stack(
        children: [
          // CONTENIDO DE LA PÁGINA (Limpio)
          Positioned.fill(
            bottom: 80,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                HomePage(isActive: _selectedIndex == 0), // Página 0 - Inicio
                const CoursesScreen(), // Página 1 - Cursos
                const DiagnosticsScreen(), // Página 2 - Diagnósticos
                const GradesScreen(), // Página 3 - Notas
                // Forzamos reconstrucción al entrar al perfil para actualizar datos (badges)
                ProfileScreen(
                    key: _selectedIndex == 4 ? ValueKey(DateTime.now()) : null),
              ],
            ),
          ),

          // BARRA DE NAVEGACIÓN (Adaptada a Azul)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80 + bottomPadding,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topLeft,
              children: [
                // 1. Fondo CustomPaint (AHORA AZUL)
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(size.width, 80 + bottomPadding),
                      painter: SlidingNavBarPainter(
                        position: _positionAnimation.value,
                        itemCount: _icons.length,
                        color: barColor, // <--- LA BARRA ADAPTA SU COLOR
                      ),
                    );
                  },
                ),

                // 2. Botón Flotante (AHORA BLANCO con Icono AZUL)
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final double currentPos = _positionAnimation.value;
                    final double centerX =
                        (currentPos * itemWidth) + (itemWidth / 2);

                    const double topPos = -20;

                    return Positioned(
                      left: centerX - 28,
                      top: topPos,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: activeBtnColor, // <--- BOTÓN ADAPTA SU COLOR
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : Colors.blue.withValues(alpha: 0.3), // Sombra
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                                scale: animation, child: child);
                          },
                          child: Icon(
                            _selectedIndex == 4
                                ? Icons.person
                                : _icons[_selectedIndex],
                            key: ValueKey<int>(_selectedIndex),
                            color:
                                activeIconColor, // <--- ICONO ACTIVO ADAPTA SU COLOR
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 3. Iconos estáticos (AHORA BLANCOS TRANSPARENTES)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_icons.length, (index) {
                      return GestureDetector(
                        onTap: () => _onItemTapped(index),
                        child: Container(
                          color: Colors.transparent,
                          width: itemWidth,
                          height: 80,
                          alignment: Alignment.center,
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              double distance =
                                  (_positionAnimation.value - index).abs();
                              double opacity = (distance - 0.2).clamp(0.0, 1.0);

                              return Opacity(
                                opacity: opacity,
                                child: Icon(
                                  _icons[index],
                                  // Iconos inactivos dinámicos
                                  color: inactiveIconColor,
                                  size: 26,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SlidingNavBarPainter extends CustomPainter {
  final double position;
  final int itemCount;
  final Color color;

  SlidingNavBarPainter(
      {required this.position, required this.itemCount, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    final itemWidth = size.width / itemCount;
    final activeX = (itemWidth * position) + (itemWidth / 2);

    // Configuración de la curva
    const double radius = 35.0;

    path.moveTo(0, 0);

    // 1. Línea hasta la curva
    path.lineTo(activeX - radius * 1.8, 0);

    // 2. La Curva Deslizable (Notch)
    // Usamos una curva simple pero suave
    path.cubicTo(
      activeX - radius, 0, // Control 1: Inicio bajada
      activeX - radius, 45, // Control 2: Bajada vertical
      activeX, 45, // Destino: Centro Fondo
    );

    path.cubicTo(
        activeX + radius,
        45, // Control 3: Subida vertical
        activeX + radius,
        0, // Control 4: Fin subida
        activeX + radius * 1.8,
        0 // Destino: Vuelta a la recta
        );

    // Resto del rectángulo
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawShadow(path.shift(const Offset(0, -2)),
        Colors.black.withValues(alpha: 0.1), 4.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SlidingNavBarPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.color != color;
  }
}
