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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Theme(
          data: ThemeProvider.lightTheme,
          child: _PasswordRecoverySheet(
            initialUsername: _usernameController.text.trim(),
            onCompletedUsername: (username) {
              if (username.isNotEmpty) {
                _usernameController.text = username;
              }
            },
          ),
        );
      },
    );
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
  final String initialUsername;
  final ValueChanged<String>? onCompletedUsername;

  const _PasswordRecoverySheet({
    required this.initialUsername,
    this.onCompletedUsername,
  });

  @override
  State<_PasswordRecoverySheet> createState() => _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState extends State<_PasswordRecoverySheet> {
  final _auth = AuthService();
  final _usernameCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  int _step = 1; // 1 datos, 2 código, 3 clave, 4 éxito
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _resetId;
  String? _emailMasked;
  String? _verifiedCode;
  String? _resolvedUsername;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.text = widget.initialUsername;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _documentCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpCtrls.map((c) => c.text).join();

  Future<void> _sendCode() async {
    final username = _usernameCtrl.text.trim();
    final document = _documentCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (username.isEmpty || document.isEmpty || email.isEmpty) {
      setState(() => _error = 'Completa usuario, documento y correo');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Ingresa un correo válido');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _auth.sendPasswordResetCode(
      username: username,
      documentNumber: document,
      email: email,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _resetId = res['reset_id']?.toString();
        _emailMasked =
            res['email_masked']?.toString() ?? email;
        _step = 2;
        _error = null;
      } else {
        _error = res['message']?.toString() ?? 'No se pudo enviar el código';
      }
    });

    if (_step == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.first.requestFocus();
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpCode;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Ingresa el código de 6 dígitos');
      return;
    }
    if (_resetId == null) {
      setState(() => _error = 'Solicita un nuevo código');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _auth.verifyPasswordResetCode(
      resetId: _resetId!,
      code: code,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _verifiedCode = code;
        _step = 3;
        _error = null;
      } else {
        _error = res['message']?.toString() ?? 'Código incorrecto';
      }
    });
  }

  Future<void> _resetPassword() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final minLen = AuthService.passwordResetMinLength;

    if (password.length < minLen) {
      setState(() =>
          _error = 'La contraseña debe tener al menos $minLen caracteres');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    if (_resetId == null || _verifiedCode == null) {
      setState(() => _error = 'Solicita un nuevo código');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _auth.resetPasswordWithCode(
      resetId: _resetId!,
      code: _verifiedCode!,
      password: password,
      passwordConfirm: confirm,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _resolvedUsername =
            res['username']?.toString() ?? _usernameCtrl.text.trim();
        _step = 4;
        _error = null;
        widget.onCompletedUsername?.call(_resolvedUsername!);
      } else {
        _error = res['message']?.toString() ?? 'No se pudo guardar';
      }
    });
  }

  void _onOtpChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _otpCtrls[index].clear();
      setState(() {});
      return;
    }

    if (digits.length > 1) {
      // Pegado de varios dígitos
      final chars = digits.split('');
      for (var i = 0; i < 6; i++) {
        _otpCtrls[i].text = i < chars.length ? chars[i] : '';
      }
      final focusIdx = chars.length >= 6 ? 5 : chars.length;
      _otpFocus[focusIdx.clamp(0, 5)].requestFocus();
      setState(() {});
      return;
    }

    _otpCtrls[index].text = digits;
    _otpCtrls[index].selection =
        TextSelection.collapsed(offset: _otpCtrls[index].text.length);
    if (index < 5) {
      _otpFocus[index + 1].requestFocus();
    }
    setState(() {});
  }

  KeyEventResult _onOtpKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpCtrls[index].text.isEmpty &&
        index > 0) {
      _otpFocus[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
              child: SingleChildScrollView(
                child: _buildStepContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 2:
        return _buildCodeStep();
      case 3:
        return _buildPasswordStep();
      case 4:
        return _buildSuccess();
      default:
        return _buildIdentityStep();
    }
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: LimpioTokens.line,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildStepsIndicator(int active) {
    const labels = ['Datos', 'Código', 'Clave'];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: (i ~/ 2) + 1 < active
                    ? LimpioTokens.brand
                    : LimpioTokens.line,
              ),
            );
          }
          final step = (i ~/ 2) + 1;
          final done = step < active;
          final current = step == active;
          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done || current
                      ? LimpioTokens.brand
                      : LimpioTokens.scaffold,
                  border: Border.all(
                    color: done || current
                        ? LimpioTokens.brand
                        : LimpioTokens.line,
                  ),
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : Text(
                        '$step',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: current ? Colors.white : LimpioTokens.muted,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[step - 1],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      current ? FontWeight.w800 : FontWeight.w600,
                  color: current || done
                      ? LimpioTokens.brand
                      : LimpioTokens.muted,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHero({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LimpioTokens.brandSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: LimpioTokens.brand, size: 26),
        ),
        const SizedBox(height: 14),
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: LimpioTokens.brand,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: LimpioTokens.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: LimpioTokens.muted,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: LimpioTokens.brand),
      suffixIcon: suffix,
      filled: true,
      fillColor: LimpioTokens.scaffold,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildError() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        _error!,
        style: const TextStyle(
          color: LimpioTokens.danger,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData icon = Icons.arrow_forward_rounded,
  }) {
    return FilledButton.icon(
      onPressed: _loading ? null : onPressed,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(
        _loading ? 'Procesando...' : label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: LimpioTokens.brand,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: 16),
        _buildHero(
          icon: Icons.shield_outlined,
          eyebrow: 'Seguridad de cuenta',
          title: 'Recuperar contraseña',
          subtitle:
              'Confirma tu identidad y te enviaremos un código de verificación.',
        ),
        const SizedBox(height: 16),
        _buildStepsIndicator(1),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameCtrl,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: LimpioTokens.ink),
          decoration: _fieldDecoration(
            label: 'Usuario',
            hint: 'Tu usuario de Campus',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _documentCtrl,
          enabled: !_loading,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: LimpioTokens.ink),
          decoration: _fieldDecoration(
            label: 'Número de documento',
            hint: 'Documento de identidad',
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _sendCode(),
          style: const TextStyle(color: LimpioTokens.ink),
          decoration: _fieldDecoration(
            label: 'Correo para el código',
            hint: 'tunombre@correo.com',
            icon: Icons.mail_outline_rounded,
          ),
        ),
        _buildError(),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Continuar',
          onPressed: _sendCode,
        ),
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

  Widget _buildCodeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: 16),
        _buildHero(
          icon: Icons.key_rounded,
          eyebrow: 'Verificación',
          title: 'Ingresa el código',
          subtitle:
              'Revisa tu correo e introduce los 6 dígitos que te enviamos.',
        ),
        const SizedBox(height: 16),
        _buildStepsIndicator(2),
        const SizedBox(height: 14),
        if (_emailMasked != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: LimpioTokens.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    color: LimpioTokens.brand, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _emailMasked!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: LimpioTokens.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < 6; i++) ...[
              if (i == 3) const SizedBox(width: 10),
              Expanded(
                child: Focus(
                  onKeyEvent: (_, event) => _onOtpKey(i, event),
                  child: TextField(
                    controller: _otpCtrls[i],
                    focusNode: _otpFocus[i],
                    enabled: !_loading,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: LimpioTokens.ink,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: LimpioTokens.scaffold,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _otpCtrls[i].text.isNotEmpty
                              ? LimpioTokens.brand
                              : LimpioTokens.line,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _otpCtrls[i].text.isNotEmpty
                              ? LimpioTokens.brand
                              : LimpioTokens.line,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: LimpioTokens.brand,
                          width: 1.6,
                        ),
                      ),
                    ),
                    onChanged: (v) => _onOtpChanged(i, v),
                  ),
                ),
              ),
              if (i != 2 && i != 5) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: LimpioTokens.muted),
            SizedBox(width: 6),
            Text(
              'El código caduca en 10 minutos',
              style: TextStyle(
                fontSize: 12,
                color: LimpioTokens.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        _buildError(),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Verificar código',
          icon: Icons.verified_rounded,
          onPressed: _verifyCode,
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _step = 1;
                    _error = null;
                  }),
          child: const Text(
            'Volver',
            style: TextStyle(
              color: LimpioTokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    final minLen = AuthService.passwordResetMinLength;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const SizedBox(height: 16),
        _buildHero(
          icon: Icons.lock_rounded,
          eyebrow: 'Nueva clave',
          title: 'Crea tu contraseña',
          subtitle:
              'Mínimo $minLen caracteres. Servirá para entrar al Campus.',
        ),
        const SizedBox(height: 16),
        _buildStepsIndicator(3),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          enabled: !_loading,
          obscureText: _obscurePass,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: LimpioTokens.ink),
          decoration: _fieldDecoration(
            label: 'Nueva contraseña',
            hint: 'Mínimo $minLen caracteres',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: LimpioTokens.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmCtrl,
          enabled: !_loading,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _resetPassword(),
          style: const TextStyle(color: LimpioTokens.ink),
          decoration: _fieldDecoration(
            label: 'Confirmar contraseña',
            hint: 'Repite la contraseña',
            icon: Icons.verified_user_outlined,
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: LimpioTokens.muted,
              ),
            ),
          ),
        ),
        _buildError(),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          label: 'Guardar e iniciar',
          icon: Icons.check_rounded,
          onPressed: _resetPassword,
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _step = 2;
                    _error = null;
                  }),
          child: const Text(
            'Volver',
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
        const _AnimatedSuccessCheck(),
        const SizedBox(height: 18),
        const Text(
          '¡Listo!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: LimpioTokens.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _resolvedUsername == null
              ? 'Tu contraseña fue actualizada. Ya puedes iniciar sesión.'
              : 'Tu contraseña fue actualizada. Ya puedes iniciar sesión como $_resolvedUsername.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: LimpioTokens.muted,
          ),
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

class _AnimatedSuccessCheck extends StatefulWidget {
  const _AnimatedSuccessCheck();

  @override
  State<_AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<_AnimatedSuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
    ]).animate(_controller);

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _ring = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 1.55)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.55, end: 1.7)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final ringOpacity =
            (1.0 - _controller.value).clamp(0.0, 1.0) * 0.35;
        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _ring.value,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: LimpioTokens.success
                          .withValues(alpha: ringOpacity),
                      width: 3,
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: LimpioTokens.success.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: LimpioTokens.success,
          size: 44,
        ),
      ),
    );
  }
}
