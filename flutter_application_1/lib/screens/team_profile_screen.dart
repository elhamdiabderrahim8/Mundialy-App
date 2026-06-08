import 'package:flutter/material.dart';

import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/team_player.dart';
import '../models/team_profile.dart';
import '../services/api_service.dart';
import '../utils/country_flags.dart';
import '../widgets/nation_flag_badge.dart';
import 'match_details_screen.dart';
import 'player_profile_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.year = 2022,
  });

  final int teamId;
  final String teamName;
  final int year;

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  static const Color _gold = Color(0xFFE7C16A);

  TeamProfile? _profile;
  List<LiveMatch> _matches = [];
  GroupStanding? _teamStanding;
  StandingTeam? _standingRow;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      ApiService.fetchTeamProfile(
        teamId: widget.teamId,
        teamName: widget.teamName,
        year: widget.year,
      ),
      ApiService.fetchMatches(year: 2022),
      ApiService.fetchMatches(year: 2026),
      ApiService.fetchStandings(year: widget.year),
    ]);

    final List<LiveMatch> matches2022 = results[1] as List<LiveMatch>;
    final List<LiveMatch> matches2026 = results[2] as List<LiveMatch>;
    
    final List<LiveMatch> teamMatches = [...matches2022, ...matches2026]
        .where(
          (m) => m.homeTeamId == widget.teamId || m.awayTeamId == widget.teamId,
        )
        .toList();

    if (!mounted) return;

    final standings = results[3] as List<GroupStanding>;
    GroupStanding? teamStanding;
    StandingTeam? standingRow;

    for (final group in standings) {
      for (final team in group.teams) {
        if (team.teamId == widget.teamId) {
          teamStanding = group;
          standingRow = team;
          break;
        }
      }
      if (standingRow != null) break;
    }

    setState(() {
      _profile = results[0] as TeamProfile?;
      _matches = teamMatches;
      _teamStanding = teamStanding;
      _standingRow = standingRow;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1A24) : const Color(0xFFF7F2E8);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: _gold)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverviewCard(isDark),
                  const SizedBox(height: 16),
                  if (_profile?.coach != null) ...[
                    _buildCoachCard(isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_standingRow != null) ...[
                    _buildStandingCard(isDark),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionTitle('Matchs du tournoi'),
                  const SizedBox(height: 12),
                  _buildMatchesList(isDark),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Effectif'),
                  const SizedBox(height: 12),
                  _buildSquadCard(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 236,
      backgroundColor: isDark
          ? const Color(0xFF132231)
          : const Color(0xFFF2E5CA),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF173046), Color(0xFF0E1A24)]
                  : const [Color(0xFFF2E5CA), Color(0xFFF7F2E8)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                NationFlagBadge(
                  countryCode:
                      _profile?.code ?? resolveCountryCode(widget.teamName),
                  size: 100,
                  imageUrlOverride: _profile?.logoUrl,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.teamName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(bool isDark) {

    final cardColor = isDark
        ? const Color(0xFF182531)
        : Colors.white.withValues(alpha: 0.94);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD9E0E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Surnom',
                  value: widget.teamName,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  label: 'Confederation',
                  value: 'FIFA',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Code',
                  value: (_profile?.code.isNotEmpty == true)
                      ? _profile!.code
                      : resolveCountryCode(widget.teamName),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  label: 'Edition',
                  value: '${widget.year}',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(bool isDark) {
    final coach = _profile!.coach!;
    final cardColor = isDark
        ? const Color(0xFF182531)
        : Colors.white.withValues(alpha: 0.94);
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD9E0E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('SÉLECTIONNEUR'),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  coach.photoUrl ?? '',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: _gold.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: _gold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${coach.nationality} • ${coach.age ?? "?"} ans',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              NationFlagBadge(countryCode: coach.nationalityCode, size: 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandingCard(bool isDark) {
    final row = _standingRow!;
    final cardColor = isDark
        ? const Color(0xFF182531)
        : Colors.white.withValues(alpha: 0.94);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD9E0E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _teamStanding?.groupName ?? 'Classement',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF16324A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Rang ${row.rank}',
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Pts',
                  value: '${row.points}',
                  isDark: isDark,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Joues',
                  value: '${row.played}',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Diff',
                  value: '${row.goalsDiff}',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesList(bool isDark) {
    if (_matches.isEmpty) {
      return _buildEmptyCard(
        isDark: isDark,
        message: 'Aucun match trouvé pour cette équipe.',
      );
    }

    final matches2022 = _matches.where((m) => m.dateTime?.year == 2022).toList();
    final matches2026 = _matches.where((m) => m.dateTime?.year != 2022).toList();

    return Column(
      children: [
        if (matches2026.isNotEmpty) ...[
          _buildTournamentHeader('Coupe du Monde 2026', isDark),
          const SizedBox(height: 12),
          ...matches2026.map(
            (match) => _TeamMatchCard(
              match: match,
              teamId: widget.teamId,
              isDark: isDark,
            ),
          ),
        ],
        if (matches2026.isNotEmpty && matches2022.isNotEmpty) ...[
          const SizedBox(height: 10),
          Divider(color: _gold.withValues(alpha: 0.3), thickness: 1),
          const SizedBox(height: 20),
        ],
        if (matches2022.isNotEmpty) ...[
          _buildTournamentHeader('Coupe du Monde 2022', isDark),
          const SizedBox(height: 12),
          ...matches2022.map(
            (match) => _TeamMatchCard(
              match: match,
              teamId: widget.teamId,
              isDark: isDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTournamentHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE8DECA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: _gold, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF16324A),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadCard(bool isDark) {
    final players = _profile?.players ?? const <TeamPlayer>[];
    if (players.isEmpty) {
      return _buildEmptyCard(
        isDark: isDark,
        message: 'Effectif non disponible.',
      );
    }

    final grouped = <String, List<TeamPlayer>>{
      'Gardiens': [],
      'Defenseurs': [],
      'Milieux': [],
      'Attaquants': [],
    };

    for (final player in players) {
      final key = _positionGroup(player.position);
      if (grouped.containsKey(key)) {
        grouped[key]!.add(player);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF182531)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD9E0E6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries
            .where((entry) => entry.value.isNotEmpty)
            .expand<Widget>(
              (entry) => [
                Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...entry.value.map(
                  (player) => GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(
                            entity: player,
                            season: widget.year,
                          ),
                        ),
                      );
                    },
                    child: _PlayerRow(player: player, isDark: isDark),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            )
            .toList(),
      ),
    );
  }

  Widget _buildEmptyCard({required bool isDark, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF182531)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFD9E0E6),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF6D7F8C),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _gold,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }

  String _positionGroup(String position) {
    final value = position.toLowerCase();
    if (value.contains('goal')) return 'Gardiens';
    if (value.contains('def')) return 'Defenseurs';
    if (value.contains('mid')) return 'Milieux';
    if (value.contains('for') ||
        value.contains('att') ||
        value.contains('str')) {
      return 'Attaquants';
    }
    return 'Autres';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF7F2E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF6D7F8C),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF16324A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.isDark,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? _TeamProfileScreenState._gold.withValues(alpha: 0.16)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF7F2E8)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? _TeamProfileScreenState._gold
                  : (isDark ? Colors.white : const Color(0xFF16324A)),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF6D7F8C),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMatchCard extends StatelessWidget {
  const _TeamMatchCard({
    required this.match,
    required this.teamId,
    required this.isDark,
  });

  final LiveMatch match;
  final int teamId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF6D7F8C);
    final isHomeTeam = match.homeTeamId == teamId;
    final teamName = isHomeTeam ? match.homeTeam : match.awayTeam;
    final teamCode = isHomeTeam ? match.homeCode : match.awayCode;
    final teamScore = isHomeTeam ? match.scoreHome : match.scoreAway;
    final opponentScore = isHomeTeam ? match.scoreAway : match.scoreHome;
    final opponentName = isHomeTeam ? match.awayTeam : match.homeTeam;
    final opponentCode = isHomeTeam ? match.awayCode : match.homeCode;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: match)),
      ),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF182531)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFD9E0E6),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '${match.localTime} local',
                  style: const TextStyle(
                    color: _TeamProfileScreenState._gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    match.city,
                    style: TextStyle(color: secondaryText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (match.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94141),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                NationFlagBadge(countryCode: teamCode, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'vs $opponentName',
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${teamScore ?? '-'} - ${opponentScore ?? '-'}',
                      style: const TextStyle(
                        color: _TeamProfileScreenState._gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.phaseLabel,
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                NationFlagBadge(countryCode: opponentCode, size: 26),
                const SizedBox(width: 8),
                Text(
                  opponentName,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 14, color: secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.isDark});

  final TeamPlayer player;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF6D7F8C);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF7F2E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              player.photoUrl ?? '',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                color: _TeamProfileScreenState._gold.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.person,
                  color: _TeamProfileScreenState._gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    NationFlagBadge(
                      countryCode: player.nationalityCode,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${player.position} • ${player.ageLabel} ans',
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _TeamProfileScreenState._gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              player.shirtNumber?.toString() ?? '-',
              style: const TextStyle(
                color: _TeamProfileScreenState._gold,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
