import 'package:flutter/material.dart';

import '../models/live_match_model.dart';
import '../models/live_stream_source_model.dart';
import '../services/live_match_stream_mapper.dart';
import 'simple_live_player_screen.dart';

class MatchesListTab extends StatelessWidget {
  const MatchesListTab({super.key});

  static const List<LiveMatch> mockFixtures = [
    LiveMatch(
      id: 'france-italy-2026',
      homeTeam: 'France',
      awayTeam: 'Italy',
      homeLogo: 'https://flagcdn.com/w160/fr.png',
      awayLogo: 'https://flagcdn.com/w160/it.png',
      time: 'LIVE 23\'',
      targetStreamUrl: '',
    ),
    LiveMatch(
      id: 'spain-germany-2026',
      homeTeam: 'Spain',
      awayTeam: 'Germany',
      homeLogo: 'https://flagcdn.com/w160/es.png',
      awayLogo: 'https://flagcdn.com/w160/de.png',
      time: 'LIVE 67\'',
      targetStreamUrl: '',
    ),
    LiveMatch(
      id: 'turkey-portugal-2026',
      homeTeam: 'Turkey',
      awayTeam: 'Portugal',
      homeLogo: 'https://flagcdn.com/w160/tr.png',
      awayLogo: 'https://flagcdn.com/w160/pt.png',
      time: 'LIVE 12\'',
      targetStreamUrl: '',
    ),
    LiveMatch(
      id: 'tunisia-iraq-2026',
      homeTeam: 'Tunisia',
      awayTeam: 'Iraq',
      homeLogo: 'https://flagcdn.com/w160/tn.png',
      awayLogo: 'https://flagcdn.com/w160/iq.png',
      time: 'LIVE 89\'',
      targetStreamUrl: '',
    ),
  ];

  static const List<LiveStreamSource> mockStreamSources = [
    LiveStreamSource(
      matchId: 'france-italy-2026',
      providerName: 'TF1 / France 24 (Public)',
      targetStreamUrl: 'https://static.france24.com/live/F24_FR_HI_HLS/live_web.m3u8',
    ),
    LiveStreamSource(
      matchId: 'spain-germany-2026',
      providerName: 'ZDF (Allemagne)',
      targetStreamUrl: 'https://zdf-hls-15.akamaized.net/hls/live/2016498/de/veryhigh/master.m3u8',
    ),
    LiveStreamSource(
      matchId: 'turkey-portugal-2026',
      providerName: 'TRT 1 (Turquie)',
      targetStreamUrl: 'https://tv-trt1.medya.trt.com.tr/master.m3u8',
    ),
    LiveStreamSource(
      matchId: 'tunisia-iraq-2026',
      providerName: 'Chaîne Publique (Moyen-Orient)',
      targetStreamUrl: 'https://live-hls-web-aja.getaj.net/AJA/index.m3u8',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0E1A24)
        : const Color(0xFFF7F2E8);
    final textColor = isDark ? Colors.white : const Color(0xFF17212B);
    final matches = LiveMatchStreamMapper.bindStreamsToMatches(
      fixtures: mockFixtures,
      streams: mockStreamSources,
    );

    return ColoredBox(
      color: background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            sliver: SliverToBoxAdapter(
              child: _LiveHeader(textColor: textColor),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            sliver: SliverList.separated(
              itemCount: matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final match = matches[index];
                return _LiveMatchCard(
                  match: match,
                  isDark: isDark,
                  onTap: match.targetStreamUrl.isEmpty
                      ? null
                      : () => _openPlayer(context, match),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openPlayer(BuildContext context, LiveMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SimpleLivePlayerScreen(
          streamUrl: match.targetStreamUrl,
          title: '${match.homeTeam} vs ${match.awayTeam}',
        ),
      ),
    );
  }
}

class _LiveHeader extends StatelessWidget {
  final Color textColor;

  const _LiveHeader({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.28),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingDot(),
                  SizedBox(width: 7),
                  Text(
                    'LIVE NOW',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Live Football Matches',
          style: TextStyle(
            color: textColor,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a match and Mundialy will prepare the stream in the native player.',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.64),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  final LiveMatch match;
  final bool isDark;
  final VoidCallback? onTap;

  const _LiveMatchCard({
    required this.match,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1D2D3B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF17212B);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: _TeamBlock(
                  name: match.homeTeam,
                  logoUrl: match.homeLogo,
                  alignment: CrossAxisAlignment.start,
                  textAlign: TextAlign.left,
                  textColor: textColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _MatchCenter(
                  time: match.time,
                  hasStream: match.targetStreamUrl.isNotEmpty,
                ),
              ),
              Expanded(
                child: _TeamBlock(
                  name: match.awayTeam,
                  logoUrl: match.awayLogo,
                  alignment: CrossAxisAlignment.end,
                  textAlign: TextAlign.right,
                  textColor: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String name;
  final String logoUrl;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;
  final Color textColor;

  const _TeamBlock({
    required this.name,
    required this.logoUrl,
    required this.alignment,
    required this.textAlign,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TeamLogo(url: logoUrl),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: textAlign,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String url;

  const _TeamLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.shield_rounded, color: Color(0xFFE7C16A)),
      ),
    );
  }
}

class _MatchCenter extends StatelessWidget {
  final String time;
  final bool hasStream;

  const _MatchCenter({required this.time, required this.hasStream});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Icon(
            hasStream
                ? Icons.play_circle_fill_rounded
                : Icons.lock_clock_rounded,
            color: hasStream ? const Color(0xFFE7C16A) : Colors.grey,
            size: 34,
          ),
          const SizedBox(height: 6),
          Text(
            hasStream ? 'WATCH' : 'SOON',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.54)
                  : Colors.black.withValues(alpha: 0.48),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.35,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
