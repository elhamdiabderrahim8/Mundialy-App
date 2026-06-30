
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Widget de test pour vérifier que la WebView protégée fonctionne.
/// Lance la page strm01.app avec le match ID passé.
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

  String get _streamUrl =>
      'https://strm01.app/?m=${widget.matchId}&lang=ar';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_chromeAgent)
      // Block ALL navigations that leave strm01.app
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _isLoading = true);
          debugPrint('[WebView] Page started: $url');
        },
        onPageFinished: (url) {
          setState(() => _isLoading = false);
          debugPrint('[WebView] Page finished: $url');

          // Inject CSS to hide ads, headers, footers, share buttons
          _controller.runJavaScript('''
            (function() {
              var style = document.createElement('style');
              style.innerHTML = `
                /* Hide ads & unwanted elements */
                [class*="ad"], [id*="ad"], [class*="banner"],
                [class*="popup"], [class*="overlay"],
                .navbar, nav, footer, header,
                [class*="social"], [class*="share"],
                [class*="download"], [class*="app-store"],
                iframe[src*="google"], ins[class*="adsbygoogle"] {
                  display: none !important;
                  visibility: hidden !important;
                  height: 0 !important;
                  overflow: hidden !important;
                }
                /* Make video fill screen */
                video, .video-js, .plyr, #player {
                  width: 100vw !important;
                  height: 100vh !important;
                }
                body { margin: 0; padding: 0; background: #000; }
              `;
              document.head.appendChild(style);
              console.log('Mundialy: CSS injected');
            })();
          ''');
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          final host = uri?.host ?? '';

          // Allow strm01.app and kora-plus.app (for m3u8 and frame.php)
          if (host.contains('strm01.app') ||
              host.contains('kora-plus.app') ||
              host.contains('kora-plus.mov') ||
              host.contains('kora-api') ||
              host.contains('cdn.kora') ||
              host.contains('w.soundcloud.com') ||
              host.contains('gstatic.com') ||
              host.contains('googleapis.com')) {
            debugPrint('[WebView] ALLOWED: $host');
            return NavigationDecision.navigate;
          }

          // Block everything else (ads, redirects, external sites)
          setState(() => _blockedRedirects++);
          debugPrint('[WebView] BLOCKED redirect to: ${request.url}');
          return NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          debugPrint('[WebView] Error: ${error.description} (${error.errorCode})');
        },
      ))
      ..loadRequest(Uri.parse(_streamUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.homeTeam} vs ${widget.awayTeam}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'En direct',
              style: TextStyle(
                color: Colors.green[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          if (_blockedRedirects > 0)
            Tooltip(
              message: '$_blockedRedirects redirections bloquées',
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.shield, color: Colors.green[400], size: 20),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFFD700)),
                    SizedBox(height: 16),
                    Text(
                      'Chargement du direct...',
                      style: TextStyle(color: Colors.white70),
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
