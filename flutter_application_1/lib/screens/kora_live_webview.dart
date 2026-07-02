
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/app_globals.dart';
import '../widgets/nation_flag_badge.dart';

// ─────────────────────────────────── Palette identique à l'app ───────────────
const Color _kGold        = Color(0xFFE7C16A);
const Color _kGoldLight   = Color(0xFFF5D98B);
const Color _kDarkBg      = Color(0xFF0E1A24);
const Color _kCardDark    = Color(0xFF152132);
const Color _kCardDarker  = Color(0xFF0C1620);
const Color _kLiveRed     = Color(0xFFFF4444);

/// Lecteur match en direct — UI identique à l'application Mundialy.
/// • Plein écran immersif (status bar cachée)
/// • Notifications suspendues pendant la lecture
/// • Redirection externe bloquée
class KoraLiveWebViewTest extends StatefulWidget {
  final String matchId;
  final String homeTeam;
  final String awayTeam;
  /// Code ISO‑2 optionnel pour afficher les drapeaux (ex. "FR", "DE")
  final String? homeCode;
  final String? awayCode;

  const KoraLiveWebViewTest({
    super.key,
    required this.matchId,
    required this.homeTeam,
    required this.awayTeam,
    this.homeCode,
    this.awayCode,
  });

  @override
  State<KoraLiveWebViewTest> createState() => _KoraLiveWebViewTestState();
}

class _KoraLiveWebViewTestState extends State<KoraLiveWebViewTest>
    with TickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  int  _blockedRedirects = 0;

  // Animation pour le point LIVE pulsant
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // Animation pour le shimmer de chargement
  late final AnimationController _shimmerCtrl;

  static const String _chromeAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  String get _streamUrl => 'https://strm01.app/?m=${widget.matchId}&lang=ar';

  // ─── CSS injecté : masque tout sauf la vidéo + sélecteur de chaînes ────────
  static const String _cssToInject = r'''
    (function() {
      var s = document.createElement('style');
      s.innerHTML = `
        /* ── Navigation / home button ── */
        .site-header, .header, #header,
        a[onclick*="goHome"], button[onclick*="goHome"],
        .back-btn, .back-button, #backBtn,
        [onclick="goHome()"], [onclick="goHome(); return false;"] {
          display: none !important;
        }
        /* ── Footer / copyright ── */
        .footer, #footer, footer,
        .modal-footer, .site-footer,
        .copyright, .copy-right { display: none !important; }
        /* ── Partage / réseaux sociaux ── */
        .share-btn, .share-buttons, .social-share,
        #shareTwitter, #shareFacebook, #shareWhatsApp,
        .btn-share, [id*="share"] { display: none !important; }
        /* ── Blocs promo / join room ── */
        .benefits-grid, .benefit-card,
        .highlight-box, .cta-buttons,
        .modal, .modal-overlay,
        #chatModal, #shareModal, #tickerModal,
        [id*="room"], [id*="chat"],
        .match-info-section, .info-grid,
        .embed-section, .description-section { display: none !important; }
        /* ── Logo du site ── */
        #siteLogo, .logo-text, #siteName,
        .site-logo, .brand-name { display: none !important; }
        /* ── Bouton thème ── */
        #themeToggle, .theme-toggle { display: none !important; }
        /* ── Override Theme Variables to remove Purple ── */
        :root, [data-theme="light"], [data-theme="dark"] {
          --bg-gradient-start: #0E1A24 !important;
          --bg-gradient-end: #0E1A24 !important;
          --card-bg: #0E1A24 !important;
          --header-bg: #0E1A24 !important;
          --button-bg-start: #152132 !important;
          --button-bg-end: #152132 !important;
          --button-active-start: #E7C16A !important;
          --button-active-end: #E7C16A !important;
          --button-shadow: transparent !important;
          --input-bg: #152132 !important;
          --input-border: rgba(231, 193, 106, 0.2) !important;
          --spinner-color: #E7C16A !important;
          --error-color: #FF4444 !important;
          --link-color: #E7C16A !important;
          --text-primary: #ffffff !important;
        }

        /* ── Espacement & Fond ── */
        body, html, .container, .player-wrapper, .match-card, .chat-section {
          padding-top: 0 !important; margin-top: 0 !important;
          background: #0E1A24 !important;
          color: #ffffff !important;
        }
        .container { padding: 8px !important; }

        /* ── Iframe pleine largeur ── */
        #player-container, .player-wrapper, #playerFrame,
        iframe[id*="player"], iframe[src*="frame.php"] {
          width: 100% !important; max-width: 100% !important;
          border-radius: 0 !important;
          border: none !important;
        }

        /* ── Fix server buttons (.btn-server) ── */
        .server-buttons {
          background: #0E1A24 !important;
          border: none !important;
          padding: 8px !important;
        }
        .channel-btn, .stream-btn, .btn-server, [class*="channel"], [class*="stream"] {
          background: #152132 !important;
          border: 1px solid rgba(231, 193, 106, 0.4) !important;
          color: #E7C16A !important;
          border-radius: 8px !important;
          font-weight: 700 !important;
          box-shadow: none !important;
          background-image: none !important; /* Removes purple gradient */
        }
        .btn-server.active, .channel-btn.active {
          background: #E7C16A !important;
          color: #0E1A24 !important;
        }
        .channel-btn:hover, .stream-btn:hover, .btn-server:hover,
        [class*="channel"]:hover, [class*="stream"]:hover {
          background: rgba(231, 193, 106, 0.2) !important;
          border-color: #E7C16A !important;
        }
      `;
      document.head.appendChild(s);

      var logo = document.getElementById('siteLogo');
      if (logo) logo.style.display = 'none';

      window.goHome = function() {
        console.log('goHome intercepté par Mundialy');
      };
    })();
  ''';

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // ► Bloquer notifications + plein écran
    enterLiveWatchMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // ► Animation pulsante LIVE
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ► Shimmer chargement
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // ► Contrôleur WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_chromeAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) {
          setState(() => _isLoading = false);
          _controller.runJavaScript(_cssToInject);
        },
        onNavigationRequest: (request) {
          final host = Uri.tryParse(request.url)?.host ?? '';
          if (host.contains('strm01.app')     ||
              host.contains('kora-plus.app')  ||
              host.contains('kora-plus.mov')  ||
              host.contains('kora-api')       ||
              host.contains('cdn.kora')       ||
              host.contains('gstatic.com')    ||
              host.contains('googleapis.com') ||
              host.contains('googlesyndication.com') ||
              host.contains('doubleclick.net')       ||
              host.contains('adservice.google')) {
            return NavigationDecision.navigate;
          }
          setState(() => _blockedRedirects++);
          debugPrint('[Mundialy] Bloqué: ${request.url}');
          return NavigationDecision.prevent;
        },
        onWebResourceError: (e) =>
            debugPrint('[Mundialy WebView] Erreur: ${e.description}'),
      ))
      ..loadRequest(Uri.parse(_streamUrl));
  }

  @override
  void dispose() {
    exitLiveWatchMode();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ─── Build principal ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading) _buildLoader(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Barre supérieure custom ────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardDarker,
        border: Border(
          bottom: BorderSide(
            color: _kGold.withValues(alpha: 0.13),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // ── Bouton Retour ──
              _buildIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),

              // ── Équipe Home ──
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        widget.homeTeam,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NationFlagBadge(
                      countryCode: widget.homeCode ?? widget.homeTeam.substring(0, widget.homeTeam.length.clamp(0, 3)),
                      teamName: widget.homeTeam,
                      size: 26,
                    ),
                  ],
                ),
              ),

              // ── Badge LIVE central ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _buildLiveBadge(),
              ),

              // ── Équipe Away ──
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    NationFlagBadge(
                      countryCode: widget.awayCode ?? widget.awayTeam.substring(0, widget.awayTeam.length.clamp(0, 3)),
                      teamName: widget.awayTeam,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.awayTeam,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Actions droite ──
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_blockedRedirects > 0)
                    Tooltip(
                      message: '$_blockedRedirects redirection(s) bloquée(s)',
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.shield_rounded,
                            color: Colors.green[400], size: 18),
                      ),
                    ),
                  _buildIconBtn(
                    icon: Icons.refresh_rounded,
                    color: _kGold,
                    onTap: () {
                      setState(() => _isLoading = true);
                      _controller.reload();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Badge LIVE animé ───────────────────────────────────────────────────────
  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kLiveRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _kLiveRed.withValues(alpha: _pulseAnim.value),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _kLiveRed.withValues(alpha: _pulseAnim.value * 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _kLiveRed.withValues(alpha: _pulseAnim.value),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kLiveRed.withValues(alpha: 0.6),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'LIVE',
              style: TextStyle(
                color: _kLiveRed,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bouton icône générique ─────────────────────────────────────────────────
  Widget _buildIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // ─── Écran de chargement premium ───────────────────────────────────────────
  Widget _buildLoader() {
    return Container(
      color: _kDarkBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drapeaux + VS
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NationFlagBadge(
                  countryCode: widget.homeCode ?? widget.homeTeam.substring(0, widget.homeTeam.length.clamp(0, 3)),
                  teamName: widget.homeTeam,
                  size: 48,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_kGold, _kGoldLight, _kGold],
                        ).createShader(bounds),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                NationFlagBadge(
                  countryCode: widget.awayCode ?? widget.awayTeam.substring(0, widget.awayTeam.length.clamp(0, 3)),
                  teamName: widget.awayTeam,
                  size: 48,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Noms des équipes
            Text(
              '${widget.homeTeam}  ·  ${widget.awayTeam}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            // ── Barre de progression gold
            SizedBox(
              width: 180,
              child: AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (_, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: _kCardDark,
                      valueColor: ColorTween(
                        begin: _kGold.withValues(alpha: 0.4),
                        end: _kGoldLight,
                      ).animate(_shimmerCtrl),
                      minHeight: 3,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connexion au direct...',
              style: TextStyle(
                color: Color(0xFF8899AA),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
