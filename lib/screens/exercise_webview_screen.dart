import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/custom_loading_indicator.dart';

class ExerciseWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const ExerciseWebViewScreen({super.key, required this.title, required this.url});

  @override
  State<ExerciseWebViewScreen> createState() => _ExerciseWebViewScreenState();
}

class _ExerciseWebViewScreenState extends State<ExerciseWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _loginSubmitted = false;

  // Custom CSS to hide Moodle chrome and style the exercise
  static const String _customCss = '''
    /* Hide Moodle navigation, header, footer, breadcrumbs */
    #page-header,
    .navbar,
    nav.navbar,
    #nav-drawer,
    .breadcrumb-nav,
    .breadcrumb,
    footer,
    #page-footer,
    .btn-footer-popover,
    #course-header,
    .activity-header,
    .activity-navigation,
    .secondary-navigation,
    #page-wrapper > nav,
    .drawer-toggler,
    .moremenu,
    .userbuttons,
    #page-navbar,
    .activityinstance > .accesshide,
    .modchooser,
    .action-menu,
    .activity-actions,
    #region-main > .action-menu-trigger { 
      display: none !important; 
    }

    /* Hide Onetopic format tabs and course index */
    .onetopic-tab-bar,
    .onetopic_tabs_container,
    #onetopic_menu,
    .nav-tabs,
    .course-content > .nav,
    .course-content > .nav-tabs,
    .format-onetopic .nav-tabs,
    .format-onetopic .onetopic-tab-bar,
    .contentwithoutlink .onetopic,
    ul.nav.nav-tabs,
    .course-content ul.topics,
    #courseindex,
    [data-region="courseindex"],
    .courseindex,
    .drawer,
    .drawers .drawer,
    #theme_boost-drawers-courseindex,
    .activity-navigation {
      display: none !important;
    }

    /* Make content full width and clean */
    #page, 
    #page-content, 
    .pagelayout-standard #page.drawers,
    #region-main-box, 
    #region-main {
      margin: 0 !important;
      padding: 8px !important;
      max-width: 100% !important;
      width: 100% !important;
    }

    body {
      background: #FFFFFF !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    #page.drawers {
      padding-top: 0 !important;
    }

    /* Remove drawers margin */
    .drawers .main-inner {
      margin-left: 0 !important;
      margin-right: 0 !important;
    }

    /* H5P specific enhancements */
    .h5p-iframe-wrapper,
    .h5p-content {
      border-radius: 12px !important;
      overflow: hidden !important;
    }

    .h5p-actions {
      border-radius: 0 0 12px 12px !important;
    }

    /* Clean up any remaining Moodle UI */
    .activity-information,
    .completion-info {
      display: none !important;
    }
  ''';

  @override
  void initState() {
    super.initState();
    _setupAndLoad();
  }

  /// Escapa caracteres especiales para inyectar como string en JS.
  String _escapeJs(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  Future<void> _setupAndLoad() async {
    try {
      // 1. Obtener credenciales del usuario
      final credentials = await AuthService().getCredentials();

      if (credentials == null) {
        print('Debug: No hay credenciales guardadas');
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return;
      }

      final username = _escapeJs(credentials['username']!);
      final password = _escapeJs(credentials['password']!);
      final exerciseUrl = widget.url;

      print('Debug: Iniciando login en WebView para cargar ejercicio');

      // 2. Crear WebViewController
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              print('Debug: Page started: $url');
            },
            onPageFinished: (url) async {
              print('Debug: Page finished: $url');

              // Si estamos en la página de login y aún no hemos enviado el formulario
              if (url.contains('/login/') && !_loginSubmitted) {
                _loginSubmitted = true;
                print('Debug: Autocompletando formulario de login...');

                // Inyectar JS que rellena el formulario y lo envía
                await _controller?.runJavaScript('''
                  (function() {
                    var u = document.getElementById('username');
                    var p = document.getElementById('password');
                    var form = document.getElementById('login');
                    if (u && p && form) {
                      u.value = '$username';
                      p.value = '$password';
                      form.submit();
                    } else {
                      // Fallback: buscar por name
                      var inputs = document.querySelectorAll('input');
                      var userInput, passInput, formEl;
                      for (var i = 0; i < inputs.length; i++) {
                        if (inputs[i].name === 'username') userInput = inputs[i];
                        if (inputs[i].name === 'password') passInput = inputs[i];
                      }
                      formEl = document.querySelector('form#login') || document.querySelector('form');
                      if (userInput && passInput && formEl) {
                        userInput.value = '$username';
                        passInput.value = '$password';
                        formEl.submit();
                      }
                    }
                  })();
                ''');
                return;
              }

              // Si seguimos en login DESPUÉS de enviar el formulario → error de credenciales
              if (url.contains('/login/') && _loginSubmitted) {
                print('Debug: Login falló, mostrando error');
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                  });
                }
                return;
              }

              // Login exitoso: si no estamos en la URL del ejercicio, redirigir
              if (!url.contains(Uri.parse(exerciseUrl).path)) {
                print('Debug: Login exitoso, redirigiendo al ejercicio...');
                _controller?.loadRequest(Uri.parse(exerciseUrl));
                return;
              }

              // Ya estamos en el ejercicio, inyectar CSS y ocultar loading
              print('Debug: Ejercicio cargado, inyectando CSS...');
              await _controller?.runJavaScript('''
                (function() {
                  var style = document.createElement('style');
                  style.textContent = `$_customCss`;
                  document.head.appendChild(style);
                })();
              ''');

              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (error) {
              print('Debug: WebView error: ${error.description}');
            },
          ),
        );

      // 3. Primero intentamos cargar directo la URL del ejercicio.
      //    Si la sesión es valida, cargará sin problemas.
      //    Si no lo es, Moodle redirigirá a /login/ y el handler de arriba se encargará.
      controller.loadRequest(Uri.parse(exerciseUrl));

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      print('Debug: Setup error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: Stack(
        children: [
          // WebView
          if (_controller != null)
            WebViewWidget(controller: _controller!),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomLoadingIndicator(size: 50),
                    SizedBox(height: 16),
                    Text(
                      'Loading exercise...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error state
          if (_hasError)
            Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load exercise',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try logging out and back in.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isLoading = true;
                        });
                        _setupAndLoad();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
