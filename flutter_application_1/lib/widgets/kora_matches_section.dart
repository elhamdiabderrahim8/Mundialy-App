import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/kora_api_service.dart';
import '../screens/kora_live_webview.dart';
import '../utils/country_flags.dart';
import 'nation_flag_badge.dart';

const Color _kGold = Color(0xFFE7C16A);
const Color _kCardDark = Color(0xFF1D2D3B);

/// Section "Matchs en direct" depuis l'API Kora.
/// À placer directement dans iptv_login_screen.dart sous le formulaire.
class KoraMatchesSection extends StatefulWidget {
  const KoraMatchesSection({super.key});

  @override
  State<KoraMatchesSection> createState() => _KoraMatchesSectionState();
}

class _KoraMatchesSectionState extends State<KoraMatchesSection> {
  List<KoraMatch> _matches = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh every 45 seconds for live score updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final matches = await KoraApiService.fetchTodayMatches();
      if (mounted) {
        setState(() {
          _matches = matches;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger les matchs';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        // ── Section Header ──────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: _kGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "MATCHS D'AUJOURD'HUI",
              style: TextStyle(
                color: _kGold,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            if (!_loading)
              GestureDetector(
                onTap: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Icon(Icons.refresh_rounded,
                    color: _kGold, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Content ─────────────────────────────────────────────────────────
        if (_loading)
          _buildShimmer()
        else if (_error != null)
          _buildError()
        else if (_matches.isEmpty)
          _buildEmpty()
        else
          ..._buildGroups(isDark),
      ],
    );
  }

  // ── Group matches by status ────────────────────────────────────────────────
  List<Widget> _buildGroups(bool isDark) {
    final live = _matches.where((m) => m.isLive).toList();
    final upcoming = _matches.where((m) => m.isUpcoming).toList();
    final finished = _matches.where((m) => m.isFinished).toList();

    final widgets = <Widget>[];

    if (live.isNotEmpty) {
      widgets.add(_buildGroupLabel('🔴  EN DIRECT', const Color(0xFFFF4444)));
      widgets.addAll(live.map((m) => _buildMatchCard(m, isDark)));
    }
    if (upcoming.isNotEmpty) {
      widgets.add(_buildGroupLabel('⏳  À VENIR', Colors.blueGrey));
      widgets.addAll(upcoming.map((m) => _buildMatchCard(m, isDark)));
    }
    if (finished.isNotEmpty) {
      widgets.add(_buildGroupLabel('✅  TERMINÉS', Colors.grey));
      widgets.addAll(finished.map((m) => _buildMatchCard(m, isDark)));
    }

    return widgets;
  }

  Widget _buildGroupLabel(String label, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
      );

  // ── Match Card ─────────────────────────────────────────────────────────────
  Widget _buildMatchCard(KoraMatch match, bool isDark) {
    final canWatch = match.isLive;

    return GestureDetector(
      onTap: canWatch
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => KoraLiveWebViewTest(
                  matchId: match.id,
                  homeTeam: match.homeTeam,
                  awayTeam: match.awayTeam,
                  homeCode: resolveCountryCode(match.homeTeam),
                  awayCode: resolveCountryCode(match.awayTeam),
                ),
              ))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? _kCardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: match.isLive
                ? const Color(0xFFFF4444).withValues(alpha: 0.4)
                : _kGold.withValues(alpha: 0.12),
            width: match.isLive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── League logo ──
            _leagueLogo(match.leagueLogoUrl, 20),
            const SizedBox(width: 10),

            // ── Home team ──
            Expanded(
              child: Row(
                children: [
                  _teamFlag(match.homeTeam, match.homeLogoUrl, 36),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      match.homeTeam,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Score / Time ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (match.isLive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFF4444).withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFFFF4444),
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatScore(match),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ] else if (match.isFinished) ...[
                    Text(
                      _formatScore(match),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      'FT',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ] else ...[
                    Text(
                      match.time,
                      style: const TextStyle(
                        color: _kGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Away team ──
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      match.awayTeam,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _teamFlag(match.awayTeam, match.awayLogoUrl, 36),
                ],
              ),
            ),

            // ── Watch button (LIVE only) ──
            if (canWatch) ...[
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatScore(KoraMatch m) {
    if (m.homeScore.isEmpty || m.awayScore.isEmpty) return '- : -';
    return '${m.homeScore} : ${m.awayScore}';
  }

  /// League logo: small rounded image
  Widget _leagueLogo(String url, double size) {
    if (url.isEmpty) {
      return Icon(Icons.emoji_events_rounded,
          size: size, color: _kGold.withValues(alpha: 0.6));
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorWidget: (ctx, url, err) => Icon(Icons.emoji_events_rounded,
          size: size, color: _kGold.withValues(alpha: 0.5)),
    );
  }

  /// Team flag: diamond shape matching app style (NationFlagBadge)
  Widget _teamFlag(String teamName, String logoUrl, double size) {
    return NationFlagBadge(
      countryCode: '',
      size: size,
      teamName: teamName,
      imageUrlOverride: logoUrl,
    );
  }

  // ── Loading shimmer ──────────────────────────────────────────────────────────
  Widget _buildShimmer() => Column(
        children: List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 64,
            decoration: BoxDecoration(
              color: _kCardDark,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );

  Widget _buildError() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Text(_error ?? '', style: const TextStyle(color: Colors.red)),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child:
                  const Text('Réessayer', style: TextStyle(color: _kGold)),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Aucun match aujourd\'hui',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
}
