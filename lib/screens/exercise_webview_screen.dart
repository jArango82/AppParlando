import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';

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

  Future<void> _setupAndLoad() async {
    try {
      // 1. Get the MoodleSession cookie
      final sessionCookie = await AuthService().getWebSessionCookie();

      if (sessionCookie == null) {
        print('Debug: No session cookie available');
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // 2. Inject the cookie into WebView's CookieManager
      final cookieManager = WebViewCookieManager();
      
      await cookieManager.setCookie(
        WebViewCookie(
          name: 'MoodleSession',
          value: sessionCookie,
          domain: 'campus.parlandolingue.edu.co',
          path: '/',
        ),
      );

      print('Debug: Cookie injected, loading exercise URL');

      // 3. Create WebViewController and load exercise URL directly
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

              // Check if we got redirected to login (cookie expired)
              if (url.contains('/login/')) {
                print('Debug: Session expired, refreshing cookie...');
                final newCookie = await AuthService().refreshWebSessionCookie();
                if (newCookie != null) {
                  await cookieManager.setCookie(
                    WebViewCookie(
                      name: 'MoodleSession',
                      value: newCookie,
                      domain: 'campus.parlandolingue.edu.co',
                      path: '/',
                    ),
                  );
                  // Reload the exercise
                  _controller?.loadRequest(Uri.parse(widget.url));
                }
                return;
              }

              // Inject custom CSS to hide Moodle UI and style the exercise
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
        )
        ..loadRequest(Uri.parse(widget.url));

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
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.blue,
                      ),
                    ),
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
