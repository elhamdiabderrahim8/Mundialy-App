import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/iptv_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/kora_matches_section.dart';

const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);
const Color _kCardDark = Color(0xFF1D2D3B);

// ─────────────────────────────────────────────────────────────────────────────
// Métadonnées des onglets
// ─────────────────────────────────────────────────────────────────────────────
const _kTabIcons = [
  Icons.playlist_play_rounded,
  Icons.dns_rounded,
  Icons.tag_rounded,
  Icons.bolt_rounded,
];
const _kTabLabels = ['M3U URL', 'Xtream', 'ID', 'Code'];
const _kTabTitles = [
  'Playlist M3U',
  'Xtream Codes',
  'Playlist ID',
  'Code Rapide',
];
const _kTabSubtitles = [
  'Collez directement l\'URL de votre playlist',
  'Serveur IPTV, identifiant & mot de passe',
  'Entrez votre numéro de playlist (ex : 1205)',
  'Connexion via code de partage unique',
];
const _kTabBannerIcons = [
  Icons.link_rounded,
  Icons.shield_rounded,
  Icons.format_list_numbered_rounded,
  Icons.flash_on_rounded,
];

// ─────────────────────────────────────────────────────────────────────────────
class IptvLoginScreen extends StatefulWidget {
  final IptvService iptvService;
  final VoidCallback onLoginSuccess;

  const IptvLoginScreen({
    super.key,
    required this.iptvService,
    required this.onLoginSuccess,
  });

  @override
  State<IptvLoginScreen> createState() => _IptvLoginScreenState();
}

class _IptvLoginScreenState extends State<IptvLoginScreen>
    with SingleTickerProviderStateMixin {
  // Onglet actif : 0=Xtream  1=M3U URL  2=Playlist ID  3=Code Rapide
  int _tab = 0;

  // Contrôleurs de texte
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _m3uCtrl = TextEditingController();
  final _plIdCtrl = TextEditingController(); // numéro ID
  final _plServerCtrl = TextEditingController(); // serveur pour l'ID
  final _codeCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uCtrl.dispose();
    _plIdCtrl.dispose();
    _plServerCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Logique de connexion ──────────────────────────────────────────────────
  Future<void> _connect() async {
    setState(() => _loading = true);
    bool success = false;

    switch (_tab) {
      // ── M3U URL
      case 0:
        final url = _m3uCtrl.text.trim();
        if (url.isEmpty) {
          _snack('Veuillez saisir une URL', error: false);
          setState(() => _loading = false);
          return;
        }
        success = await widget.iptvService.loginWithM3uUrl(url);

      // ── Xtream Codes
      case 1:
        final s = _serverCtrl.text.trim();
        final u = _userCtrl.text.trim();
        final p = _passCtrl.text.trim();
        if (s.isEmpty || u.isEmpty || p.isEmpty) {
          _snack('Veuillez remplir tous les champs', error: false);
          setState(() => _loading = false);
          return;
        }
        success = await widget.iptvService.login(s, u, p);

      // ── Playlist ID
      case 2:
        final id = _plIdCtrl.text.trim();
        final srv = _plServerCtrl.text.trim();
        if (id.isEmpty || srv.isEmpty) {
          _snack('Serveur et ID playlist requis', error: false);
          setState(() => _loading = false);
          return;
        }
        success = await widget.iptvService.loginWithPlaylistId(id, srv);

      // ── Code Rapide
      case 3:
        final code = _codeCtrl.text.trim();
        if (code.isEmpty) {
          _snack('Veuillez saisir votre code', error: false);
          setState(() => _loading = false);
          return;
        }
        success = await widget.iptvService.loginWithQuickCode(code);
    }

    setState(() => _loading = false);
    if (success) {
      widget.onLoginSuccess();
    } else {
      _snack(_errorMsg(), error: true);
    }
  }

  Future<void> _connectFreeSportsM3u() async {
    setState(() {
      _loading = true;
    });

    final success = await widget.iptvService.loginWithM3uUrl(
      IptvService.freeSportsM3uUrl,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      widget.onLoginSuccess();
    } else {
      _snack('Playlist Sports inaccessible pour le moment', error: true);
    }
  }

  String _errorMsg() => switch (_tab) {
    0 => 'URL invalide ou playlist inaccessible',
    1 => 'Connexion échouée — vérifiez vos identifiants',
    2 => 'ID introuvable — vérifiez le serveur et le numéro',
    3 => 'Code invalide — vérifiez et réessayez',
    _ => 'Erreur de connexion',
  };

  void _snack(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent.shade700 : _kCardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : const Color(0xFFF7F2E8);
    final cardBg = isDark ? _kCardDark : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white30 : Colors.black26;
    final fieldBg = isDark ? const Color(0xFF152231) : const Color(0xFFF0EBE0);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Halos d'ambiance
          _glow(
            top: -60,
            left: -40,
            size: 220,
            color: _kGold.withValues(alpha: 0.12),
          ),
          _glow(
            bottom: -40,
            right: -40,
            size: 160,
            color: _kGold.withValues(alpha: 0.08),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône animée
                  _buildHeroIcon(),
                  const SizedBox(height: 22),

                  // Titre
                  Text(
                    'LIVE TV',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: _kGold,
                      shadows: [
                        Shadow(
                          color: _kGold.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choisissez votre méthode de connexion',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.44),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Sélecteur d'onglets (4 modes)
                  _buildTabSelector(isDark: isDark, textColor: textColor),
                  const SizedBox(height: 16),

                  // Carte formulaire
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _kGold.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.45 : 0.08,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Bannière descriptive
                        _buildTabBanner(textColor: textColor),
                        const SizedBox(height: 6),
                        Divider(
                          color: _kGold.withValues(alpha: 0.1),
                          height: 24,
                        ),

                        // Champs animés
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.04, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: anim,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_tab),
                            child: _buildFormContent(
                              fieldBg: fieldBg,
                              hintColor: hintColor,
                              textColor: textColor,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bouton de connexion
                        _buildConnectBtn(),
                      ],
                    ),
                  ),

                  // ── Matchs en direct (Kora API) ──────────────────────────
                  const KoraMatchesSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Icône pulsante ────────────────────────────────────────────────────────
  Widget _buildHeroIcon() => AnimatedBuilder(
    animation: _pulseCtrl,
    builder: (_, _) => Transform.scale(
      scale: 1.0 + _pulseCtrl.value * 0.08,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kGold, _kGold.withValues(alpha: 0.6)],
          ),
          boxShadow: [
            BoxShadow(
              color: _kGold.withValues(alpha: 0.38),
              blurRadius: 26,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.live_tv_rounded, size: 44, color: _kDarkBg),
      ),
    ),
  );

  // ── Sélecteur 4 onglets ───────────────────────────────────────────────────
  Widget _buildTabSelector({required bool isDark, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? _kCardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (i) {
          final sel = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _kGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.38),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _kTabIcons[i],
                      size: 18,
                      color: sel ? _kDarkBg : textColor.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _kTabLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: sel
                            ? _kDarkBg
                            : textColor.withValues(alpha: 0.4),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Bannière descriptive ──────────────────────────────────────────────────
  Widget _buildTabBanner({required Color textColor}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Row(
        key: ValueKey(_tab),
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _kGold.withValues(alpha: 0.12),
            ),
            child: Icon(_kTabBannerIcons[_tab], color: _kGold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kTabTitles[_tab],
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _kTabSubtitles[_tab],
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Contenu par onglet ────────────────────────────────────────────────────
  Widget _buildFormContent({
    required Color fieldBg,
    required Color hintColor,
    required Color textColor,
    required bool isDark,
  }) => switch (_tab) {
    0 => _buildM3uForm(fieldBg, hintColor, textColor),
    1 => _buildXtreamForm(fieldBg, hintColor, textColor),
    2 => _buildPlaylistIdForm(fieldBg, hintColor, textColor),
    3 => _buildQuickCodeForm(fieldBg, hintColor, textColor),
    _ => const SizedBox.shrink(),
  };

  // ────────────────────────────────────────────────────────────────────────
  // ONGLET 0 — Xtream Codes
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildXtreamForm(Color fieldBg, Color hintColor, Color textColor) {
    return Column(
      children: [
        _field(
          ctrl: _serverCtrl,
          label: 'Serveur',
          hint: 'http://server.com:8080',
          icon: Icons.dns_rounded,
          fieldBg: fieldBg,
          hintColor: hintColor,
          textColor: textColor,
          keyboard: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _userCtrl,
          label: 'Utilisateur',
          hint: 'username',
          icon: Icons.person_rounded,
          fieldBg: fieldBg,
          hintColor: hintColor,
          textColor: textColor,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _passCtrl,
          label: 'Mot de passe',
          hint: '••••••••',
          icon: Icons.lock_rounded,
          fieldBg: fieldBg,
          hintColor: hintColor,
          textColor: textColor,
          obscure: _obscurePass,
          suffix: IconButton(
            icon: Icon(
              _obscurePass
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _kGold.withValues(alpha: 0.6),
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // ONGLET 1 — URL M3U directe
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildM3uForm(Color fieldBg, Color hintColor, Color textColor) {
    return Column(
      children: [
        _buildFreeSportsPreset(textColor),
        const SizedBox(height: 14),
        _field(
          ctrl: _m3uCtrl,
          label: 'URL Playlist',
          hint: 'http://example.com/playlist.m3u',
          icon: Icons.link_rounded,
          fieldBg: fieldBg,
          hintColor: hintColor,
          textColor: textColor,
          keyboard: TextInputType.url,
          suffix: _pasteBtn(_m3uCtrl),
        ),
        const SizedBox(height: 16),
        _infoBox(
          icon: Icons.info_outline_rounded,
          textColor: textColor,
          lines: [
            ('Formats acceptés : .m3u  ·  .m3u8', false),
            ('Protocoles HTTP et HTTPS supportés', false),
          ],
        ),
      ],
    );
  }

  Widget _buildFreeSportsPreset(Color textColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _loading ? null : _connectFreeSportsM3u,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _kGold.withValues(alpha: 0.1),
          border: Border.all(color: _kGold.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: _kGold.withValues(alpha: 0.16),
              ),
              child: const Icon(
                Icons.sports_soccer_rounded,
                color: _kGold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.iptvConnectM3u ?? 'Sports M3U',
                    style: const TextStyle(
                      color: _kGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)?.iptvConnectM3uSub ?? 'Connexion directe instantanée',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.48),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: _kGold, size: 18),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // ONGLET 2 — Playlist ID
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildPlaylistIdForm(Color fieldBg, Color hintColor, Color textColor) {
    return Column(
      children: [
        // Numéro d'ID — mise en valeur avec une police plus grande
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Numéro de playlist'),
            const SizedBox(height: 6),
            TextField(
              controller: _plIdCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '1205',
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Icon(Icons.tag_rounded, color: _kGold, size: 22),
                ),
                prefixIconConstraints: const BoxConstraints(),
                filled: true,
                fillColor: fieldBg,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _kGold.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Serveur IPTV
        _field(
          ctrl: _plServerCtrl,
          label: 'Serveur IPTV',
          hint: 'http://mon-serveur.com:8080',
          icon: Icons.dns_rounded,
          fieldBg: fieldBg,
          hintColor: hintColor,
          textColor: textColor,
          keyboard: TextInputType.url,
          suffix: _pasteBtn(_plServerCtrl),
        ),
        const SizedBox(height: 16),

        // Info box spéciale Playlist ID
        _infoBox(
          icon: Icons.lightbulb_outline_rounded,
          textColor: textColor,
          lines: [
            ('Comment trouver votre ID ?', true),
            (
              'Votre fournisseur IPTV vous attribue un numéro de playlist (ex : 182, 2014, 1205). Entrez ce numéro et le domaine de votre fournisseur.',
              false,
            ),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // ONGLET 3 — Code Rapide (base-64)
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildQuickCodeForm(Color fieldBg, Color hintColor, Color textColor) {
    return Column(
      children: [
        _field(
          ctrl: _codeCtrl,
          label: 'Code de partage',
          hint: 'Collez votre code ici…',
          icon: Icons.bolt_rounded,
          fieldBg: fieldBg,
          hintColor: hintColor,
          textColor: textColor,
          maxLines: 3,
          suffix: _pasteBtn(_codeCtrl),
        ),
        const SizedBox(height: 16),
        _infoBox(
          icon: Icons.help_outline_rounded,
          textColor: textColor,
          lines: [
            ('Comment obtenir un code ?', true),
            (
              'Connectez-vous via Xtream Codes puis appuyez sur "Partager Code" dans l\'écran des catégories.',
              false,
            ),
          ],
        ),
      ],
    );
  }

  // ── Bouton de connexion ───────────────────────────────────────────────────
  Widget _buildConnectBtn() => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _kGold,
        foregroundColor: _kDarkBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: _kGold.withValues(alpha: 0.4),
      ),
      onPressed: _loading ? null : _connect,
      child: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _kDarkBg,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_kTabBannerIcons[_tab], size: 20),
                const SizedBox(width: 10),
                const Text(
                  'CONNEXION',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
    ),
  );

  // ── Widgets partagés ──────────────────────────────────────────────────────
  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: _kGold.withValues(alpha: 0.72),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required Color fieldBg,
    required Color hintColor,
    required Color textColor,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          keyboardType: keyboard,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor, fontSize: 13),
            prefixIcon: Icon(icon, color: _kGold, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _kGold.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Bouton coller presse-papiers
  Widget _pasteBtn(TextEditingController ctrl) => IconButton(
    icon: Icon(
      Icons.content_paste_rounded,
      color: _kGold.withValues(alpha: 0.65),
      size: 20,
    ),
    onPressed: () async {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      if (d?.text != null) ctrl.text = d!.text!;
    },
  );

  /// Box d'info/aide contextuelle
  Widget _infoBox({
    required IconData icon,
    required Color textColor,
    required List<(String text, bool bold)> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: _kGold.withValues(alpha: 0.06),
        border: Border.all(color: _kGold.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: _kGold.withValues(alpha: 0.75), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map(
                    (e) => Padding(
                      padding: EdgeInsets.only(bottom: e == lines.last ? 0 : 3),
                      child: Text(
                        e.$1,
                        style: TextStyle(
                          color: e.$2
                              ? _kGold.withValues(alpha: 0.9)
                              : textColor.withValues(alpha: 0.48),
                          fontSize: e.$2 ? 12 : 11,
                          fontWeight: e.$2
                              ? FontWeight.w700
                              : FontWeight.normal,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Halo d'ambiance positionné
  Widget _glow({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
