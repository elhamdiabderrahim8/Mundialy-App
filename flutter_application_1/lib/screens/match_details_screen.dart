import 'package:flutter/material.dart';

import '../models/live_match.dart';
import '../models/match_details.dart';
import '../models/team_player.dart';
import '../services/api_service.dart';
import '../services/world_cup_repository.dart';
import '../utils/country_flags.dart';
import '../utils/mock_match_details_data.dart';
import '../widgets/nation_flag_badge.dart';
import 'player_profile_screen.dart';
import 'team_profile_screen.dart';

const Color kGold = Color(0xFFE7C16A);

const Map<String, List<Offset>> _formationCoordinates = {
  '4-3-3': [
    Offset(0.5, 0.90), // GK
    Offset(0.15, 0.70), Offset(0.38, 0.75), Offset(0.62, 0.75), Offset(0.85, 0.70), // DEF
    Offset(0.25, 0.45), Offset(0.5, 0.50), Offset(0.75, 0.45), // MID
    Offset(0.20, 0.20), Offset(0.5, 0.15), Offset(0.80, 0.20), // ATT
  ],
  '5-3-2': [
    Offset(0.5, 0.90), // GK
    Offset(0.1, 0.70), Offset(0.3, 0.75), Offset(0.5, 0.75), Offset(0.7, 0.75), Offset(0.9, 0.70), // DEF
    Offset(0.25, 0.45), Offset(0.5, 0.45), Offset(0.75, 0.45), // MID
    Offset(0.33, 0.20), Offset(0.66, 0.20), // ATT
  ],
  '4-4-2': [
    Offset(0.5, 0.90), // GK
    Offset(0.15, 0.70), Offset(0.38, 0.75), Offset(0.62, 0.75), Offset(0.85, 0.70), // DEF
    Offset(0.15, 0.45), Offset(0.38, 0.45), Offset(0.62, 0.45), Offset(0.85, 0.45), // MID
    Offset(0.35, 0.20), Offset(0.65, 0.20), // ATT
  ],
  '4-2-3-1': [
    Offset(0.5, 0.90), // GK
    Offset(0.15, 0.70), Offset(0.38, 0.75), Offset(0.62, 0.75), Offset(0.85, 0.70), // DEF
    Offset(0.35, 0.55), Offset(0.65, 0.55), // MID Low
    Offset(0.20, 0.35), Offset(0.5, 0.35), Offset(0.80, 0.35), // MID High
    Offset(0.5, 0.15), // ATT
  ],
  '3-4-3': [
    Offset(0.5, 0.90), // GK
    Offset(0.25, 0.75), Offset(0.5, 0.75), Offset(0.75, 0.75), // DEF
    Offset(0.1, 0.45), Offset(0.38, 0.45), Offset(0.62, 0.45), Offset(0.9, 0.45), // MID
    Offset(0.20, 0.20), Offset(0.5, 0.15), Offset(0.80, 0.20), // ATT
  ],
};

class MatchDetailsScreen extends StatefulWidget {
  const MatchDetailsScreen({super.key, required this.match});

  final LiveMatch match;

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  MatchDetails? _details;
  bool _isLoading = true;
  int _selectedView = 0;
  int _selectedTeamIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  Future<void> _loadMatchDetails() async {
    setState(() => _isLoading = true);

    try {
      final details = await ApiService.fetchMatchDetails(widget.match);

      if (!mounted) return;
      setState(() {
        _details = details;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('💥 Erreur chargement détails : $e');
      if (!mounted) return;
      setState(() {
        _details = getMockMatchDetails(widget.match);
        _isLoading = false;
      });
    }
  }

  TeamLineup? get _selectedLineup => _details == null
      ? null
      : (_selectedTeamIndex == 0 ? _details!.homeLineup : _details!.awayLineup);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0E1A24) : Colors.white;
    final Color cardColor = isDark ? const Color(0xFF182531) : Colors.grey.shade100;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: kGold)),
      );
    }

    if (_details == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Text(
            'Details indisponibles',
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, textColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildScoreCard(cardColor, textColor),
                    const SizedBox(height: 14),
                    _buildSwitchButtons(cardColor, textColor),
                    const SizedBox(height: 14),
                    if (_selectedView == 0) ...[
                      _buildSummarySection(cardColor, textColor),
                    ] else if (_selectedView == 1) ...[
                      _buildStatsSection(cardColor, textColor),
                    ] else ...[
                      _buildTeamToggle(cardColor, textColor),
                      const SizedBox(height: 12),
                      if (_selectedLineup != null) _buildLineupSection(_selectedLineup!, cardColor, textColor, isDark),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textColor) {
    final details = _details!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new, color: textColor.withValues(alpha: 0.7)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  details.overview.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${details.overview.status} • ${details.overview.minute}',
                  style: const TextStyle(color: kGold, fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.match.streamUrl != null && widget.match.isLive)
            IconButton(
              onPressed: () => _openLiveStream(context, widget.match.streamUrl!),
              icon: const Icon(Icons.live_tv_rounded, color: kGold, size: 24),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildScoreCard(Color cardColor, Color textColor) {
    final overview = _details!.overview;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text('Score'.toUpperCase(),
            style: TextStyle(color: textColor.withValues(alpha: 0.38), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _TeamMiniCard(
                  name: overview.homeTeam,
                  code: overview.homeCode,
                  logoUrl: overview.homeLogoUrl,
                  teamId: widget.match.homeTeamId,
                  year: widget.match.dateTime?.year ?? 2022,
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${overview.scoreHome} - ${overview.scoreAway}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    if (overview.penaltyHome != null || overview.penaltyAway != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'PENS: ${overview.penaltyHome ?? 0} - ${overview.penaltyAway ?? 0}',
                          style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: _TeamMiniCard(
                  name: overview.awayTeam,
                  code: overview.awayCode,
                  logoUrl: overview.awayLogoUrl,
                  teamId: widget.match.awayTeamId,
                  year: widget.match.dateTime?.year ?? 2022,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchButtons(Color cardColor, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: _SwitchButton(
            label: 'Resume',
            selected: _selectedView == 0,
            onTap: () => setState(() => _selectedView = 0),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SwitchButton(
            label: 'Statistiques',
            selected: _selectedView == 1,
            onTap: () => setState(() => _selectedView = 1),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SwitchButton(
            label: 'Composition',
            selected: _selectedView == 2,
            onTap: () => setState(() => _selectedView = 2),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryCard(cardColor, textColor),
        if (_details!.overview.penaltyHome != null || _details!.overview.penaltyAway != null) ...[
          const SizedBox(height: 14),
          _buildShootoutSection(cardColor, textColor),
        ],
        const SizedBox(height: 14),
        _buildInfoCard(cardColor, textColor),
      ],
    );
  }

  Widget _buildShootoutSection(Color cardColor, Color textColor) {
    final events = _details!.summary.events.where((e) => e.title.toLowerCase().contains('penalty') && (int.tryParse(e.minute.replaceAll("'", "")) ?? 0) > 120).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text('SÉANCE DE TIRS AU BUT', style: TextStyle(color: kGold, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildShootoutColumn(_details!.overview.homeTeam, _details!.overview.homeCode, events.where((e) => e.teamName == _details!.overview.homeTeam).toList(), textColor),
              _buildShootoutColumn(_details!.overview.awayTeam, _details!.overview.awayCode, events.where((e) => e.teamName == _details!.overview.awayTeam).toList(), textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShootoutColumn(String name, String code, List<MatchEvent> events, Color textColor) {
    return Column(
      children: [
        _DiamondFlag(countryCode: code, size: 40),
        const SizedBox(height: 12),
        Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 16),
        ...events.map((e) {
          final isGoal = !e.detail.toLowerCase().contains('missed');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isGoal ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: isGoal ? Colors.green : Colors.red, width: 2),
            ),
            child: Icon(
              isGoal ? Icons.check : Icons.close,
              color: isGoal ? Colors.green : Colors.red,
              size: 18,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(Color cardColor, Color textColor) {
    final events = _details!.summary.events;
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(22)),
        child: Center(child: Text('Aucun evenement repertorie', style: TextStyle(color: textColor.withValues(alpha: 0.54)))),
      );
    }

    // Grouper les événements par période
    final List<Widget> children = [];
    int? currentPeriod; // 1: 1H, 2: 2H, 3: ET, 4: PENS

    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final minStr = e.minute.replaceAll("'", "");
      final minute = int.tryParse(minStr) ?? 0;

      int period;
      if (e.title.toLowerCase().contains('penalty') && minute > 120) {
        period = 4;
      } else if (minute > 90) {
        period = 3;
      } else if (minute > 45) {
        period = 2;
      } else {
        period = 1;
      }

      if (currentPeriod != period) {
        currentPeriod = period;
        children.add(_buildPeriodSeparator(period, textColor));
      }

      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _EventTile(event: e, year: widget.match.dateTime?.year ?? 2022, cardColor: cardColor, textColor: textColor),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text('ÉVÉNEMENTS DU MATCH',
            style: TextStyle(color: textColor.withValues(alpha: 0.38), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
        ...children,
      ],
    );
  }

  Widget _buildPeriodSeparator(int period, Color textColor) {
    String label = switch (period) {
      1 => 'PREMIÈRE MI-TEMPS',
      2 => 'DEUXIÈME MI-TEMPS',
      3 => 'PROLONGATIONS',
      _ => 'TIRS AU BUT',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: textColor.withValues(alpha: 0.1), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.24), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
          Expanded(child: Divider(color: textColor.withValues(alpha: 0.1), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Color cardColor, Color textColor) {
    final venue = _details!.summary.venue;
    final referee = _details!.summary.referee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations du match',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Arbitre',
            value: '${referee.name}${referee.nationality.isNotEmpty ? " • ${referee.nationality}" : ""}',
            textColor: textColor,
          ),
          _InfoRow(label: 'Stade', value: venue.stadium, textColor: textColor),
          _InfoRow(label: 'Ville', value: venue.city, textColor: textColor),
          _InfoRow(label: 'Heure de debut', value: _details!.summary.startTime, textColor: textColor),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques du match',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ..._details!.stats.map(
            (stat) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _StatBar(stat: stat, textColor: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamToggle(Color cardColor, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: _SwitchButton(
            label: _details!.homeLineup.teamName,
            selected: _selectedTeamIndex == 0,
            onTap: () => setState(() => _selectedTeamIndex = 0),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SwitchButton(
            label: _details!.awayLineup.teamName,
            selected: _selectedTeamIndex == 1,
            onTap: () => setState(() => _selectedTeamIndex = 1),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLineupSection(TeamLineup lineup, Color cardColor, Color textColor, bool isDark) {
    const double fieldHeight = 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: textColor.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lineup.teamName,
                          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lineup.formation,
                          style: const TextStyle(color: kGold, fontWeight: FontWeight.w600, letterSpacing: 1.2, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('COACH', style: TextStyle(color: textColor.withValues(alpha: 0.38), fontSize: 9, fontWeight: FontWeight.bold)),
                          Text(
                            lineup.coach,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: fieldHeight,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF132231) : Colors.green.shade900.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: textColor.withValues(alpha: 0.05)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                          Center(
                            child: Opacity(
                              opacity: 0.08,
                              child: Image.network(
                                'https://upload.wikimedia.org/wikipedia/fr/thumb/b/b4/FIFA_World_Cup_2022_Logo.svg/1200px-FIFA_World_Cup_2022_Logo.svg.png',
                                width: 250,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.emoji_events, size: 180, color: kGold),
                              ),
                            ),
                          ),
                          ...List.generate(lineup.players.length, (index) {
                            final player = lineup.players[index];
                            final coords = _formationCoordinates[lineup.formation] ?? _formationCoordinates['4-3-3']!;
                            final Offset relativePos = index < coords.length ? coords[index] : Offset(player.x, player.y);

                            const double widgetWidth = 80;
                            final double posX = (relativePos.dx * constraints.maxWidth) - (widgetWidth / 2);
                            final double posY = (relativePos.dy * fieldHeight) - 30;

                            return Positioned(
                              left: posX,
                              top: posY,
                              width: widgetWidth,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PlayerProfileScreen(
                                      entity: TeamPlayer(
                                        id: player.id,
                                        name: player.name,
                                        position: player.role,
                                        shirtNumber: player.number,
                                        photoUrl: "https://api.sofascore.app/api/v1/player/${player.id}/image",
                                        nationality: lineup.teamName,
                                        nationalityCode: lineup.teamCode,
                                        ageLabel: '',
                                      ),
                                      season: widget.match.dateTime?.year ?? 2022,
                                    )
                                  ));
                                },
                                child: _PlayerJersey(
                                  player: player,
                                  kitColor: Color(lineup.kitColor),
                                  textColor: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'BANC DE TOUCHE',
            style: TextStyle(color: textColor.withValues(alpha: 0.38), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: lineup.bench.length,
            itemBuilder: (context, index) {
              final player = lineup.bench[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: textColor.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(lineup.kitColor).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(lineup.kitColor).withValues(alpha: 0.3), width: 2),
                      ),
                      child: Icon(Icons.person, size: 24, color: Color(lineup.kitColor)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      player,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openLiveStream(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.play_circle_fill, color: kGold, size: 50),
            const Padding(padding: EdgeInsets.all(20), child: Text('IPTV LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: kGold))),
          ],
        ),
      ),
    );
  }
}

class _PlayerJersey extends StatelessWidget {
  const _PlayerJersey({required this.player, required this.kitColor, required this.textColor});

  final PlayerSpot player;
  final Color kitColor;
  final Color textColor;

  Color _getRatingColor(String rating) {
    final val = double.tryParse(rating) ?? 0.0;
    if (val >= 7.5) return Colors.greenAccent;
    if (val >= 6.5) return Colors.orangeAccent;
    if (val > 0) return Colors.redAccent;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: const Size(38, 38), // On agrandit un peu
              painter: _JerseyPainter(color: kitColor),
            ),
            // PHOTO DU JOUEUR (SofaScore CDN)
            if (player.id > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  'https://api.sofascore.app/api/v1/player/${player.id}/image',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    '${player.number}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kitColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              )
            else
              Text(
                '${player.number}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kitColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                ),
              ),
            // Affichage de la NOTE
            if (player.rating.isNotEmpty)
              Positioned(
                top: -8,
                right: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getRatingColor(player.rating),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black26, width: 0.5),
                  ),
                  child: Text(
                    player.rating,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 78),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            player.name,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _JerseyPainter extends CustomPainter {
  const _JerseyPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.lineTo(size.width * 0.95, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(size.width * 0.2, size.height);
    path.lineTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.05, size.height * 0.4);
    path.close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeamMiniCard extends StatelessWidget {
  const _TeamMiniCard({
    required this.name,
    required this.code,
    this.logoUrl,
    this.teamId,
    this.year = 2022,
  });

  final String name;
  final String code;
  final String? logoUrl;
  final int? teamId;
  final int year;

  @override
  Widget build(BuildContext context) {
    // Si on a un teamId (SofaScore), on construit l'URL de l'image SofaScore
    final String? finalLogoUrl = teamId != null
        ? 'https://api.sofascore.app/api/v1/team/$teamId/image'
        : logoUrl;

    return InkWell(
      onTap: teamId == null ? null : () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TeamProfileScreen(teamId: teamId!, teamName: name, year: year)
        ));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DiamondFlag(countryCode: code, size: 74, imageUrlOverride: finalLogoUrl),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondFlag extends StatelessWidget {
  const _DiamondFlag({
    required this.countryCode,
    required this.size,
    this.imageUrlOverride,
  });

  final String countryCode;
  final double size;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    return NationFlagBadge(
      countryCode: countryCode,
      size: size,
      imageUrlOverride: imageUrlOverride,
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cardColor,
    required this.textColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color cardColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kGold.withValues(alpha: 0.18) : cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kGold : textColor.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? kGold : textColor.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.year, required this.cardColor, required this.textColor});

  final MatchEvent event;
  final int year;
  final Color cardColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final accent = _eventAccent(event.icon);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            event.minute,
            style: const TextStyle(color: kGold, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _EventIconBadge(event: event),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    if (event.teamCode.isNotEmpty)
                      GestureDetector(
                        onTap: event.teamId == null ? null : () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TeamProfileScreen(
                              teamId: event.teamId!,
                              teamName: event.teamName,
                              year: year,
                            )
                          ));
                        },
                        child: _DiamondFlag(countryCode: event.teamCode, size: 24),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: event.playerId == null ? null : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlayerProfileScreen(
                        entity: TeamPlayer(
                          id: event.playerId!,
                          name: event.description,
                          position: '',
                          shirtNumber: 0,
                          photoUrl: null,
                          nationality: event.teamName,
                          nationalityCode: event.teamCode,
                          ageLabel: '',
                        ),
                        season: year,
                      )
                    ));
                  },
                  child: Text(
                    event.description,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15, decoration: event.playerId != null ? TextDecoration.underline : null),
                  ),
                ),
                if (event.assistant != null && event.assistant!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: event.assistantId == null ? null : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(
                            entity: TeamPlayer(
                              id: event.assistantId!,
                              name: event.assistant!,
                              position: '',
                              shirtNumber: 0,
                              photoUrl: null,
                              nationality: event.teamName,
                              nationalityCode: event.teamCode,
                              ageLabel: '',
                            ),
                            season: year,
                          )
                        ));
                      },
                      child: Text(
                        'Passe décisive: ${event.assistant!}',
                        style: TextStyle(color: textColor.withValues(alpha: 0.54), fontSize: 12, decoration: event.assistantId != null ? TextDecoration.underline : null),
                      ),
                    ),
                  ),
                if (event.playerIn != null || event.playerOut != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        if (event.playerIn != null)
                          GestureDetector(
                            onTap: event.playerInId == null ? null : () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PlayerProfileScreen(
                                  entity: TeamPlayer(
                                    id: event.playerInId!,
                                    name: event.playerIn!,
                                    position: '',
                                    shirtNumber: 0,
                                    photoUrl: null,
                                    nationality: event.teamName,
                                    nationalityCode: event.teamCode,
                                    ageLabel: '',
                                  ),
                                  season: year,
                                )
                              ));
                            },
                            child: _EventPill(
                              label: 'ENTRE: ${event.playerIn!}',
                              color: const Color(0xFF1E6C47),
                              icon: Icons.login,
                            ),
                          ),
                        if (event.playerOut != null)
                          const SizedBox(height: 4),
                        if (event.playerOut != null)
                          GestureDetector(
                            onTap: event.playerOutId == null ? null : () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PlayerProfileScreen(
                                  entity: TeamPlayer(
                                    id: event.playerOutId!,
                                    name: event.playerOut!,
                                    position: '',
                                    shirtNumber: 0,
                                    photoUrl: null,
                                    nationality: event.teamName,
                                    nationalityCode: event.teamCode,
                                    ageLabel: '',
                                  ),
                                  season: year,
                                )
                              ));
                            },
                            child: _EventPill(
                              label: 'SORT: ${event.playerOut!}',
                              color: const Color(0xFF7A3A2A),
                              icon: Icons.logout,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (event.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDetailBgColor(event),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _translateDetail(event.detail).toUpperCase(),
                        style: TextStyle(
                          color: _getDetailTextColor(event),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _translateDetail(String detail) {
    final d = detail.toLowerCase();
    if (d.contains('missed penalty') || d.contains('penalty missed')) return 'Penalty manqué';
    if (d.contains('penalty goal') || (d.contains('penalty') && !d.contains('missed'))) return 'Penalty marqué';
    if (d.contains('hit the post')) return 'Poteau';
    if (d.contains('saved')) return 'Arrêt du gardien';
    if (d.contains('goal cancelled')) return 'But annulé (VAR)';
    return detail;
  }

  Color _getDetailBgColor(MatchEvent event) {
    final d = event.detail.toLowerCase();
    if (event.icon == MatchEventIcon.penaltyMissed || d.contains('missed penalty') || d.contains('penalty missed')) {
      return Colors.red.withValues(alpha: 0.15);
    }
    if (d.contains('penalty')) return Colors.green.withValues(alpha: 0.15);
    if (d.contains('cancelled')) return Colors.white10;
    return Colors.white.withValues(alpha: 0.05);
  }

  Color _getDetailTextColor(MatchEvent event) {
    final d = event.detail.toLowerCase();
    if (event.icon == MatchEventIcon.penaltyMissed || d.contains('missed penalty') || d.contains('penalty missed')) {
      return Colors.redAccent;
    }
    if (d.contains('penalty')) return Colors.greenAccent;
    return Colors.white70;
  }
}

class _EventPill extends StatelessWidget {
  const _EventPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 12, color: Colors.white70),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.textColor});

  final String label;
  final String value;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.7))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.stat, required this.textColor});

  final MatchStat stat;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final total = stat.homeValue + stat.awayValue;
    final homeRatio = total == 0 ? 0.5 : stat.homeValue / total;
    final awayRatio = total == 0 ? 0.5 : stat.awayValue / total;
    final homeFlex = ((homeRatio * 100).round()).clamp(1, 99);
    final awayFlex = ((awayRatio * 100).round()).clamp(1, 99);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${stat.homeValue.toInt()}${stat.label == 'Possession' ? '%' : ''}',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                stat.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor.withValues(alpha: 0.54), fontSize: 11, letterSpacing: 1.2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${stat.awayValue.toInt()}${stat.label == 'Possession' ? '%' : ''}',
                textAlign: TextAlign.end,
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: homeFlex,
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      color: kGold,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                    ),
                  ),
                ),
                Container(width: 2, height: 6, color: Colors.black26),
                Expanded(
                  flex: awayFlex,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), linePaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), linePaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.15, linePaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.70, size.height * 0.18), linePaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.82, size.width * 0.70, size.height * 0.18),
      linePaint,
    );
    canvas.drawRect(Rect.fromLTWH(size.width * 0.35, 0, size.width * 0.30, size.height * 0.06), linePaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.94, size.width * 0.30, size.height * 0.06),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EventIconBadge extends StatelessWidget {
  const _EventIconBadge({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _eventAccent(event.icon);
    final isCard = event.icon == MatchEventIcon.yellowCard || event.icon == MatchEventIcon.redCard;
    final isVar = event.icon == MatchEventIcon.varReview;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      alignment: Alignment.center,
      child: isVar
          ? Text(
              'VAR',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10),
            )
          : isCard
              ? _CardBadge(color: color)
              : event.icon == MatchEventIcon.penaltyMissed
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.sports_soccer, color: color, size: 18),
                        const Icon(Icons.close, color: Colors.white70, size: 12),
                      ],
                    )
                  : Icon(_iconForEvent(event.icon), color: color, size: 18),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.03,
      child: Container(
        width: 10,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
          border: Border.all(color: Colors.black26, width: 0.5),
        ),
      ),
    );
  }
}

IconData _iconForEvent(MatchEventIcon icon) {
  return switch (icon) {
    MatchEventIcon.goal => Icons.sports_soccer,
    MatchEventIcon.substitution => Icons.swap_horiz,
    MatchEventIcon.varReview => Icons.videocam_outlined,
    MatchEventIcon.offside => Icons.rule,
    MatchEventIcon.cancelledGoal => Icons.block,
    MatchEventIcon.yellowCard => Icons.square,
    MatchEventIcon.redCard => Icons.square,
    MatchEventIcon.penaltyMissed => Icons.sports_soccer,
  };
}

Color _eventAccent(MatchEventIcon icon) {
  return switch (icon) {
    MatchEventIcon.goal => const Color(0xFF1FAE68),
    MatchEventIcon.substitution => const Color(0xFFE38B2C),
    MatchEventIcon.varReview => const Color(0xFF4EA3FF),
    MatchEventIcon.offside => const Color(0xFF7E8BA0),
    MatchEventIcon.cancelledGoal => const Color(0xFF6E7A89),
    MatchEventIcon.yellowCard => const Color(0xFFE9BE32),
    MatchEventIcon.redCard => const Color(0xFFE05151),
    MatchEventIcon.penaltyMissed => const Color(0xFFE05151),
  };
}

void _openLiveStream(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.play_circle_fill, color: kGold, size: 50),
          const Padding(padding: EdgeInsets.all(20), child: Text('IPTV LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: kGold))),
        ],
      ),
    ),
  );
}
