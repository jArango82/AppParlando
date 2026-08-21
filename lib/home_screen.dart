import 'package:flutter/material.dart';
import 'main_page.dart';
import 'services/auth_service.dart';
import 'widgets/custom_loading_indicator.dart';
import 'widgets/limpio_card.dart';
import 'theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _formOpacityAnimation;
  Animation<double>? _logoOffsetY; // Animación para mover el logo
  bool _initialized = false;

  // Controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
// ...

      vsync: this,
      duration: const Duration(seconds: 2), // Duración total de la secuencia
    );

    // El formulario aparece (fade in) un poco después de que el logo empieza a subir
    _formOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Calculamos la distancia exacta para que el logo empiece en el CENTRO
      final Size screenSize = MediaQuery.of(context).size;
      const double logoHeight = 350.0; // El tamaño del logo
      const double topSpace = 80.0; // El SizedBox que pusimos arriba

      // Posición final deseada (Y): topSpace (80.0)
      // Posición inicial deseada (Y): Centro de la pantalla
      final double startY = (screenSize.height - logoHeight) / 2;
      const double endY = topSpace;

      // Cuánto tenemos que bajarlo inicialmente (Offset positivo)
      final double distance = startY - endY;

      _logoOffsetY = Tween<double>(begin: distance, end: 0.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve:
              const Interval(0.0, 0.6, curve: Curves.easeInOut), // Sube primero
        ),
      );

      _animationController.forward();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa los campos')));
      return;
    }

    setState(() => _isLoading = true);

    final res = await AuthService().login(user, pass);

    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Error de autenticación'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Bienvenido a Parlando',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: LimpioTokens.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Inicia sesión para continuar aprendiendo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: LimpioTokens.muted,
          ),
        ),
        const SizedBox(height: 28),
        LimpioCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: LimpioTokens.ink),
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: const Icon(Icons.person_outline,
                      color: LimpioTokens.brand),
                  filled: true,
                  fillColor: LimpioTokens.scaffold,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: LimpioTokens.ink),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: LimpioTokens.brand),
                  filled: true,
                  fillColor: LimpioTokens.scaffold,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: LimpioTokens.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 28,
                          width: 28,
                          child: CustomLoadingIndicator(size: 28),
                        )
                      : const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Olvidé mi contraseña',
            style: TextStyle(
              color: LimpioTokens.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = context.isWideScreen;

    return Scaffold(
      backgroundColor: LimpioTokens.scaffold,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Logo
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _logoOffsetY?.value ?? 0),
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/logo_002.webp',
                              width: 320,
                              height: 320,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      // Right: Login Card / Form
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: FadeTransition(
                              opacity: _formOpacityAnimation,
                              child: _buildLoginForm(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 80),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _logoOffsetY?.value ?? 0),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/logo_002.webp',
                          width: 320,
                          height: 320,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: FadeTransition(
                          opacity: _formOpacityAnimation,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: _buildLoginForm(context),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
