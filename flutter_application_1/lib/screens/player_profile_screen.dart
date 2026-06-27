import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/team_player.dart';
import '../models/live_match.dart';
import '../models/match_details.dart';
import '../services/api_service.dart';
import '../widgets/nation_flag_badge.dart';
import '../widgets/loading_skeletons.dart';
import '../utils/country_flags.dart';
import '../models/top_scorer.dart';
import '../utils/player_resolver.dart';
import 'match_details_screen.dart';

const _kGold = Color(0xFFE7C16A);

class PlayerProfileScreen extends StatefulWidget {
  final dynamic entity; // TeamPlayer ou TeamCoach ou TopScorer
  final int season;

  const PlayerProfileScreen({
    super.key,
    required this.entity,
    this.season = 2026,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? _statsData;
  bool _statsLoading = true;
  TeamPlayer? _resolvedTeamPlayer;

  List<LiveMatch> _teamMatches = [];
  Map<String, MatchDetails> _matchDetails = {};
  bool _timelineLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final id = widget.entity is TopScorer ? (widget.entity as TopScorer).playerId : _asInt(widget.entity.id);
    if (id > 0) {
      try {
        final data = await ApiService.fetchPlayerStats(
          playerId: id,
          season: widget.season,
        );
        if (mounted) {
          setState(() {
            _statsData = data;
            _statsLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _statsData = null;
            _statsLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() => _statsLoading = false);
      }
    }

    _loadMatchTimeline();
  }

  Future<void> _loadMatchTimeline() async {
    try {
      final allMatches = await ApiService.fetchMatches(year: widget.season);
      
      String teamName = '';
      if (widget.entity is TeamPlayer) {
        teamName = (widget.entity as TeamPlayer).nationality ?? '';
      } else if (widget.entity is TopScorer) {
        teamName = (widget.entity as TopScorer).teamName;
      }
      if (teamName.isEmpty && _statsData != null) {
        final attr = _asMap(_statsData!['attributes']);
        teamName = attr['nationality']?.toString() ?? '';
      }

      if (teamName.isNotEmpty) {
        if (widget.entity is TopScorer) {
          try {
            final profile = await ApiService.fetchTeamProfile(teamId: 0, teamName: teamName);
            if (profile != null) {
              final playerName = (widget.entity as TopScorer).playerName;
              final found = profile.players.firstWhere(
                (p) => PlayerResolver.namesMatch(p.name, playerName),
                orElse: () => const TeamPlayer(id: 0, name: '', position: '', nationality: '', nationalityCode: '', ageLabel: ''),
              );
              if (found.id != 0 && mounted) {
                setState(() => _resolvedTeamPlayer = found);
              }
            }
          } catch (_) {}
        }
        final normTeam = teamName.toLowerCase().trim();
        final filtered = allMatches.where((m) => 
          m.homeTeam.toLowerCase().trim() == normTeam || 
          m.awayTeam.toLowerCase().trim() == normTeam
        ).toList();
        
        filtered.sort((a, b) => (b.dateTime ?? DateTime.now()).compareTo(a.dateTime ?? DateTime.now()));
        
        if (mounted) {
          setState(() {
            _teamMatches = filtered;
          });
        }

        for (final m in filtered) {
          if (m.isFinished || m.isLive) {
            final details = await ApiService.fetchMatchDetails(m);
            if (details != null && mounted) {
              setState(() {
                _matchDetails[m.id] = details;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading match timeline: $e');
    } finally {
      if (mounted) setState(() => _timelineLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1A24) : const Color(0xFFF7F2E8);
    final cardColor = isDark ? const Color(0xFF182531) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);

    // Extract data from new unified format
    final characteristics = _asMap(_statsData?['characteristics']);
    final attributes = _asMap(_statsData?['attributes']);

    String name = '';
    if (widget.entity is TopScorer) {
      name = (widget.entity as TopScorer).playerName;
    } else {
      name = widget.entity.name ?? '';
    }

    final String nationality =
        (attributes['nationality']?.toString().isNotEmpty == true)
        ? attributes['nationality'].toString()
        : (widget.entity is TeamPlayer ? widget.entity.nationality ?? '' : (widget.entity is TopScorer ? widget.entity.teamName : ''));
    final String nationalityCode = resolveCountryCode(nationality);

    // Characteristics
    final charData = _asMap(
      characteristics['playerCharacteristics'],
      fallback: characteristics,
    );
    final String preferredFoot = charData['preferredFoot']?.toString() ?? '';
    final int height = _asInt(charData['height']);
    final int weight = _asInt(charData['weight']);
    final String position =
        (charData['position']?.toString().isNotEmpty == true)
        ? charData['position'].toString()
        : (widget.entity is TeamPlayer
              ? (widget.entity as TeamPlayer).position ?? ''
              : (_resolvedTeamPlayer?.position ?? ''));
    final int shirtNumber = _asInt(charData['shirtNumber']) > 0
        ? _asInt(charData['shirtNumber'])
        : (widget.entity is TeamPlayer
              ? _asInt((widget.entity as TeamPlayer).shirtNumber)
              : _asInt(_resolvedTeamPlayer?.shirtNumber ?? 0));

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // --- HERO APP BAR ---
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0E1A24) : Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF1D2D3B), const Color(0xFF0E1A24)]
                            : [
                                const Color(0xFFEAF0F6),
                                const Color(0xFFF7F2E8),
                              ],
                      ),
                    ),
                  ),
                  if (shirtNumber > 0)
                    Positioned(
                      right: -10,
                      top: 10,
                      child: Text(
                        '$shirtNumber',
                        style: TextStyle(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          color: _kGold.withValues(alpha: 0.07),
                          height: 1,
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 50),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [_kGold, Color(0xFFC8973A)],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: isDark
                                    ? const Color(0xFF1D2D3B)
                                    : Colors.white,
                                child: _getPhotoUrl() != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: _getPhotoUrl()!,
                                          width: 110,
                                          height: 110,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) => _buildInitialsFallback(name),
                                        ),
                                      )
                                    : _buildInitialsFallback(name),
                              ),
                            ),
                            if (nationalityCode.isNotEmpty)
                              NationFlagBadge(
                                countryCode: nationalityCode,
                                size: 36,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (position.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kGold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _localizePosition(position),
                              style: const TextStyle(
                                color: _kGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- CONTENT ---
          SliverToBoxAdapter(
            child: _statsLoading
                ? const PlayerStatsSkeleton()
                : _buildOverviewTab(
                    isDark,
                    textColor,
                    cardColor,
                    height,
                    weight,
                    preferredFoot,
                    shirtNumber,
                    nationality,
                    position,
                  ),
          ),
          
          // --- MATCH TIMELINE ---
          if (_timelineLoading && _teamMatches.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator(color: _kGold)),
              ),
            ),
          if (_teamMatches.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 24, top: 16, bottom: 8),
                      child: Text(
                        'HISTORIQUE DU TOURNOI',
                        style: TextStyle(
                          color: _kGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    );
                  }
                  final m = _teamMatches[index - 1];
                  final details = _matchDetails[m.id];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchDetailsScreen(match: m),
                          ),
                        );
                      },
                      child: _PlayerMatchTimelineCard(
                        match: m,
                        details: details,
                        playerName: name,
                        playerId: widget.entity is TopScorer ? (widget.entity as TopScorer).playerId : _asInt(widget.entity.id),
                      ),
                    ),
                  );
                },
                childCount: _teamMatches.length + 1,
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    bool isDark,
    Color textColor,
    Color cardColor,
    int height,
    int weight,
    String preferredFoot,
    int shirtNumber,
    String nationality,
    String position,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(isDark, cardColor, textColor, [
            if (shirtNumber > 0)
              _InfoRow(
                icon: Icons.tag,
                label: 'Numéro',
                value: '#$shirtNumber',
                color: _kGold,
              ),
            if (position.isNotEmpty)
              _InfoRow(
                icon: Icons.sports_soccer_rounded,
                label: 'Poste',
                value: _localizePosition(position),
                color: Colors.teal,
              ),
            if (nationality.isNotEmpty)
              _InfoRow(
                icon: Icons.flag_rounded,
                label: 'Nationalité',
                value: nationality.toUpperCase(),
                color: const Color(0xFF4DA3FF),
              ),
            if (height > 0)
              _InfoRow(
                icon: Icons.height,
                label: 'Taille',
                value: '$height cm',
                color: Colors.teal,
              ),
            if (weight > 0)
              _InfoRow(
                icon: Icons.monitor_weight_outlined,
                label: 'Poids',
                value: '$weight kg',
                color: Colors.orange,
              ),
            if (preferredFoot.isNotEmpty)
              _InfoRow(
                icon: Icons.directions_walk_rounded,
                label: 'Pied préféré',
                value: preferredFoot == 'left'
                    ? 'Gauche'
                    : preferredFoot == 'right'
                    ? 'Droit'
                    : preferredFoot,
                color: Colors.purple,
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark,
    Color cardColor,
    Color textColor,
    List<Widget> rows,
  ) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          'Informations non disponibles',
          style: TextStyle(color: textColor.withValues(alpha: 0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children:
            rows
                .expand(
                  (row) => [
                    row,
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ],
                )
                .toList()
              ..removeLast(),
      ),
    );
  }

  String _localizePosition(String pos) {
    final map = {
      'G': 'GARDIEN',
      'GK': 'GARDIEN',
      'goalkeeper': 'GARDIEN',
      'D': 'DÉFENSEUR',
      'defender': 'DÉFENSEUR',
      'M': 'MILIEU',
      'midfielder': 'MILIEU',
      'F': 'ATTAQUANT',
      'forward': 'ATTAQUANT',
    };
    return map[pos] ?? pos.toUpperCase();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  String? _getPhotoUrl() {
    if (widget.entity is TeamPlayer) return (widget.entity as TeamPlayer).photoUrl;
    if (widget.entity is TeamCoach) return (widget.entity as TeamCoach).photoUrl;
    if (widget.entity is TopScorer) return (widget.entity as TopScorer).bestPhotoUrl;
    return null;
  }

  Widget _buildInitialsFallback(String name) {
    return Center(
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: _kGold.withValues(alpha: 0.8),
          fontSize: 36,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Map<String, dynamic> _asMap(
    dynamic value, {
    Map<String, dynamic> fallback = const {},
  }) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return fallback;
  }

  List<dynamic> _asList(dynamic value, {List<dynamic> fallback = const []}) {
    if (value is List) return value;
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  num _asNum(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerMatchTimelineCard extends StatelessWidget {
  final LiveMatch match;
  final MatchDetails? details;
  final String playerName;
  final int playerId;

  const _PlayerMatchTimelineCard({
    required this.match,
    required this.details,
    required this.playerName,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF182531) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);

    bool isStarter = false;
    bool subbedIn = false;
    bool subbedOut = false;
    String? subMinute;
    int goals = 0;
    int assists = 0;
    int yellowCards = 0;
    int redCards = 0;
    bool isBench = false;

    if (details != null) {
      PlayerSpot? targetSpot;
      bool targetIsStarter = false;

      final allStarters = [...details!.homeLineup.players, ...details!.awayLineup.players];
      final allBench = [...details!.homeLineup.bench, ...details!.awayLineup.bench];

      for (var p in allStarters) {
        if (p.id == playerId || PlayerResolver.namesMatch(p.name, playerName)) {
          targetSpot = p;
          targetIsStarter = true;
          break;
        }
      }
      if (targetSpot == null) {
        for (var p in allBench) {
          if (p.id == playerId || PlayerResolver.namesMatch(p.name, playerName)) {
            targetSpot = p;
            targetIsStarter = false;
            break;
          }
        }
      }

      if (targetSpot != null) {
        isStarter = targetIsStarter;
        isBench = !isStarter;

        for (var event in details!.summary.events) {
          final isSamePlayer = (event.playerId == playerId) || 
                               (event.scorerName.isNotEmpty && PlayerResolver.namesMatch(event.scorerName, playerName));
          
          if (isSamePlayer) {
            if (event.icon == MatchEventIcon.goal) goals++;
            if (event.icon == MatchEventIcon.yellowCard) yellowCards++;
            if (event.icon == MatchEventIcon.redCard) redCards++;
          }
          
          if (event.assistantId == playerId || 
             (event.assistant != null && event.assistant!.isNotEmpty && PlayerResolver.namesMatch(event.assistant, playerName))) {
            assists++;
          }

          if (event.icon == MatchEventIcon.substitution) {
            if (event.playerOutId == playerId || PlayerResolver.namesMatch(event.playerOut, playerName)) {
              subbedOut = true;
              subMinute = event.minute;
            }
            if (event.playerInId == playerId || PlayerResolver.namesMatch(event.playerIn, playerName)) {
              subbedIn = true;
              subMinute = event.minute;
            }
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Match UI Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          match.homeTeam,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      NationFlagBadge(countryCode: match.homeCode, teamName: match.homeTeam, size: 28, imageUrlOverride: match.homeLogoUrl),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: match.isFinished || match.isLive
                      ? Text(
                          '${match.scoreHome ?? 0} - ${match.scoreAway ?? 0}',
                          style: TextStyle(
                            color: match.isLive ? Colors.redAccent : textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : Text(
                          match.statusDisplay,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      NationFlagBadge(countryCode: match.awayCode, teamName: match.awayTeam, size: 28, imageUrlOverride: match.awayLogoUrl),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          match.awayTeam,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Mini Symbols Bandeau
          if (details != null && (isStarter || isBench))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9F9F9),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (isStarter && !subbedOut)
                    const _MiniSymbol(icon: Icons.check_circle, color: Colors.green, text: "90'"),
                  if (isStarter && subbedOut)
                    _MiniSymbol(icon: Icons.arrow_downward, color: Colors.redAccent, text: "${subMinute ?? '?'} (Sorti)"),
                  if (isBench && subbedIn)
                    _MiniSymbol(icon: Icons.arrow_upward, color: Colors.green, text: "${subMinute ?? '?'} (Entré)"),
                  if (isBench && !subbedIn)
                    const _MiniSymbol(icon: Icons.chair_alt, color: Colors.grey, text: "Banc"),
                  if (goals > 0)
                    _MiniSymbol(icon: Icons.sports_soccer, color: _kGold, text: "x$goals"),
                  if (assists > 0)
                    const _MiniSymbol(icon: Icons.help_outline, color: Colors.blueAccent, text: "", customText: "A"),
                  if (yellowCards > 0)
                    _MiniSymbol(icon: Icons.square, color: Colors.yellow, text: ""),
                  if (redCards > 0)
                    const _MiniSymbol(icon: Icons.square, color: Colors.red, text: ""),
                ],
              ),
            ),
            
          if (details == null && (match.isFinished || match.isLive))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2, color: _kGold.withValues(alpha: 0.5))),
            ),
        ],
      ),
    );
  }
}

class _MiniSymbol extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? customText;

  const _MiniSymbol({required this.icon, required this.color, required this.text, this.customText});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (customText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(customText!, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          )
        else
          Icon(icon, color: color, size: 16),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
        ]
      ],
    );
  }
}
