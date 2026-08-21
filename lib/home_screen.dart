import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _usernameController.dispose();
    _passwordController.dispose();
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
        backgroundColor: LimpioTokens.danger,
      ));
    }
  }

  Future<void> _showPasswordRecoverySheet() async {
    final controller = TextEditingController(
      text: _usernameController.text.trim(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Theme(
          data: ThemeProvider.lightTheme,
          child: _PasswordRecoverySheet(
            initialController: controller,
            onSubmit: (value) => AuthService().requestPasswordRecovery(value),
          ),
        );
      },
    );

    controller.dispose();
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
                textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _handleLogin(),
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
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _showPasswordRecoverySheet,
            style: TextButton.styleFrom(
              foregroundColor: LimpioTokens.brand,
            ),
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // El login siempre se muestra en modo claro, aunque la app esté en oscuro.
    return Theme(
      data: ThemeProvider.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Builder(
          builder: (context) {
            final bool isWide = context.isWideScreen;

            return Scaffold(
              backgroundColor: LimpioTokens.scaffold,
              body: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 20.0),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(
                                            0, _logoOffsetY?.value ?? 0),
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
                              Expanded(
                                flex: 6,
                                child: Center(
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 400),
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
                                    offset:
                                        Offset(0, _logoOffsetY?.value ?? 0),
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
                                    constraints:
                                        const BoxConstraints(maxWidth: 400),
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
          },
        ),
      ),
    );
  }
}

class _PasswordRecoverySheet extends StatefulWidget {
  final TextEditingController initialController;
  final Future<Map<String, dynamic>> Function(String value) onSubmit;

  const _PasswordRecoverySheet({
    required this.initialController,
    required this.onSubmit,
  });

  @override
  State<_PasswordRecoverySheet> createState() => _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState extends State<_PasswordRecoverySheet> {
  late final TextEditingController _controller;
  bool _loading = false;
  bool _success = false;
  String? _error;
  String _submittedUser = '';
  String? _destinationEmail;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialController.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Ingresa tu usuario o número de documento');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await widget.onSubmit(value);

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _success = true;
        _submittedUser = value;
        _destinationEmail = res['to']?.toString();
      } else {
        _error = res['message']?.toString() ?? 'No se pudo enviar la solicitud';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: _success ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: LimpioTokens.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LimpioTokens.brandSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: LimpioTokens.brand,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Recuperar contraseña',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: LimpioTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa tu usuario o número de documento. Enviaremos la solicitud al correo de administración de Parlando para ayudarte a recuperar el acceso.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: LimpioTokens.muted,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LimpioTokens.scaffold,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LimpioTokens.line),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mail_outline_rounded,
                  color: LimpioTokens.brand, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La solicitud llega a parlandolingue@gmail.com. Un asesor te contactará con tus datos de acceso.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: LimpioTokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _submit(),
          autofocus: true,
          style: const TextStyle(color: LimpioTokens.ink),
          decoration: InputDecoration(
            labelText: 'Usuario o documento',
            hintText: 'Ej. juanma o 1234567890',
            prefixIcon: const Icon(Icons.badge_outlined,
                color: LimpioTokens.brand),
            filled: true,
            fillColor: LimpioTokens.scaffold,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              color: LimpioTokens.danger,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _loading ? 'Enviando solicitud...' : 'Solicitar restablecimiento',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: LimpioTokens.brand,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              color: LimpioTokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: LimpioTokens.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: LimpioTokens.success,
            size: 40,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '¡Solicitud enviada!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: LimpioTokens.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: LimpioTokens.muted,
            ),
            children: [
              const TextSpan(
                text:
                    'Se envió la solicitud de restablecimiento para ',
              ),
              TextSpan(
                text: _submittedUser,
                style: const TextStyle(
                  color: LimpioTokens.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_destinationEmail != null) ...[
                const TextSpan(text: ' a '),
                TextSpan(
                  text: _destinationEmail,
                  style: const TextStyle(
                    color: LimpioTokens.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: '.'),
              ] else
                const TextSpan(
                  text:
                      '. Revisa el correo de administración (y spam).',
                ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: LimpioTokens.brand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
