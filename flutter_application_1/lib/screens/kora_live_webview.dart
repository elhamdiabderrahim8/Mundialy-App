
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/app_globals.dart';

const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);

/// Secure live match player:
/// - Shows the full strm01.app page (ads + channel list preserved)
/// - Hides only: "go home" button, footer, share buttons, unnecessary text
/// - Intercepts iframe src changes to detect the active stream edge/channel
/// - Uses Flutter's native AppBar + controls overlay
class KoraLiveWebViewTest extends StatefulWidget {
  final String matchId;
  final String homeTeam;
  final String awayTeam;

  const KoraLiveWebViewTest({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  State<KoraLiveWebViewTest> createState() => _KoraLiveWebViewTestState();
}

class _KoraLiveWebViewTestState extends State<KoraLiveWebViewTest> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _blockedRedirects = 0;

  static const String _chromeAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  String get _streamUrl => 'https://strm01.app/?m=${widget.matchId}&lang=ar';

  // CSS injected after page load:
  // - Hides: header nav, goHome button, footer, share buttons, promo blocks
  // - Keeps: video/iframe player, channel selector buttons, ads
  static const String _cssToInject = '''
    (function() {
      var s = document.createElement('style');
      s.innerHTML = `
        /* ── Hide navigation / home button ── */
        .site-header, .header, #header,
        a[onclick*="goHome"], button[onclick*="goHome"],
        .back-btn, .back-button, #backBtn,
        [onclick="goHome()"], [onclick="goHome(); return false;"] {
          display: none !important;
        }

        /* ── Hide footer ── */
        .footer, #footer, footer,
        .modal-footer, .site-footer,
        .copyright, .copy-right {
          display: none !important;
        }

        /* ── Hide share / social buttons ── */
        .share-btn, .share-buttons, .social-share,
        #shareTwitter, #shareFacebook, #shareWhatsApp,
        .btn-share, [id*="share"] {
          display: none !important;
        }

        /* ── Hide "join room", promo & benefits blocks ── */
        .benefits-grid, .benefit-card,
        .highlight-box, .cta-buttons,
        .modal, .modal-overlay,
        #chatModal, #shareModal, #tickerModal,
        [id*="room"], [id*="chat"],
        .match-info-section, .info-grid,
        .embed-section, .description-section {
          display: none !important;
        }

        /* ── Hide logo/site name (sport TV) ── */
        #siteLogo, .logo-text, #siteName,
        .site-logo, .brand-name {
          display: none !important;
        }

        /* ── Hide theme toggle ── */
        #themeToggle, .theme-toggle { display: none !important; }

        /* ── Tighten spacing for mobile ── */
        body { padding-top: 0 !important; margin-top: 0 !important; }
        .container { padding: 8px !important; }
        .match-card { border-radius: 12px !important; }

        /* ── Ensure iframe fills width ── */
        #player-container, .player-wrapper, #playerFrame,
        iframe[id*="player"], iframe[src*="frame.php"] {
          width: 100% !important;
          max-width: 100% !important;
          border-radius: 10px !important;
        }
      `;
      document.head.appendChild(s);

      /* ── Also directly hide the goHome logo div ── */
      var logo = document.getElementById('siteLogo');
      if (logo) logo.style.display = 'none';

      /* ── Override goHome to do nothing (prevents redirect) ── */
      window.goHome = function() {
        console.log('goHome intercepted by Mundialy');
      };
    })();
  ''';

  @override
  void initState() {
    super.initState();
    // ► Suspendre les notifications (buts, alertes) pendant la lecture live
    enterLiveWatchMode();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_chromeAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) {
          setState(() => _isLoading = false);
          // Inject CSS + JS overrides after page is fully loaded
          _controller.runJavaScript(_cssToInject);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          final host = uri?.host ?? '';

          // Allow: strm01.app, kora-plus (for frame.php iframes), cdn, analytics
          if (host.contains('strm01.app') ||
              host.contains('kora-plus.app') ||
              host.contains('kora-plus.mov') ||
              host.contains('kora-api') ||
              host.contains('cdn.kora') ||
              host.contains('gstatic.com') ||
              host.contains('googleapis.com') ||
              host.contains('googlesyndication.com') ||  // Google ads ✅ kept
              host.contains('doubleclick.net') ||         // Google ads ✅ kept
              host.contains('adservice.google')) {         // Google ads ✅ kept
            return NavigationDecision.navigate;
          }

          // Block external redirects (other sites, deep links, etc.)
          setState(() => _blockedRedirects++);
          debugPrint('[Mundialy WebView] Blocked: ${request.url}');
          return NavigationDecision.prevent;
        },
        onWebResourceError: (e) =>
            debugPrint('[Mundialy WebView] Error: ${e.description}'),
      ))
      ..loadRequest(Uri.parse(_streamUrl));
  }

  @override
  void dispose() {
    // ◄ Réactiver les notifications (avec délai de 5s pour éviter les spoilers)
    exitLiveWatchMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) _buildLoader(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: _kDarkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.homeTeam}  vs  ${widget.awayTeam}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const Text(
                  'EN DIRECT',
                  style: TextStyle(
                    color: Color(0xFFFF4444),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Shield shows blocked redirect count
          if (_blockedRedirects > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: '$_blockedRedirects redirection(s) bloquée(s)',
                child: Icon(Icons.shield_rounded,
                    color: Colors.green[400], size: 18),
              ),
            ),
          // Reload button
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: _kGold, size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _controller.reload();
            },
            tooltip: 'Recharger',
          ),
        ],
      );

  Widget _buildLoader() => Container(
        color: _kDarkBg,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: _kGold,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Chargement du direct...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
}
