// lib/screens/competition_detail_screen.dart
// Page de détail d'une compétition : Matchs | Classements | Buteurs | Tableau
import 'package:flutter/material.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/top_scorer.dart';
import '../services/scores365_service.dart';
import '../utils/country_flags.dart';
import '../widgets/nation_flag_badge.dart';


class CompetitionDetailScreen extends StatefulWidget {
  final int competitionId;
  final String? overrideName; // si null, utilise le catalogue

  const CompetitionDetailScreen({
    super.key,
    required this.competitionId,
    this.overrideName,
  });

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Competition? _competition;

  List<LiveMatch> _matches = [];
  List<GroupStanding> _standings = [];
  List<TopScorer> _scorers = [];

  bool _loadingMatches = true;
  bool _loadingStandings = false;
  bool _loadingScorers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _competition = CompetitionsCatalog.findById(widget.competitionId);
    _initTabs();
    _loadMatches();
  }

  void _initTabs() {
    int tabCount = 1; // toujours "Matchs"
    if (_competition?.hasStandings ?? false) tabCount++;
    if (_competition?.hasStats ?? false) tabCount++;
    if (_competition?.hasBrackets ?? false) tabCount++;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  Future<void> _loadMatches() async {
    setState(() {
      _loadingMatches = true;
      _error = null;
    });
    try {
      // Plage large : 2 ans pour capturer archive + futures
      final now = DateTime.now();
      final start =
          '${(now.month).toString().padLeft(2, '0')}/01/${now.year - 1}';
      final end =
          '${(now.month).toString().padLeft(2, '0')}/30/${now.year + 1}';
      final matches = await Scores365Service.fetchMatchesByCompetition(
        competitionId: widget.competitionId,
        startDate: start,
        endDate: end,
        competitionName: _competition?.name ?? widget.overrideName,
      );
      if (mounted) {
        setState(() {
          _matches = matches
            ..sort((a, b) => (b.dateTime ?? DateTime(0))
                .compareTo(a.dateTime ?? DateTime(0)));
          _loadingMatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingMatches = false;
        });
      }
    }
  }

  Future<void> _loadStandings() async {
    if (_standings.isNotEmpty) return;
    setState(() => _loadingStandings = true);
    final data = await Scores365Service.fetchStandingsByCompetition(
        widget.competitionId);
    if (mounted) {
      setState(() {
        _standings = data;
        _loadingStandings = false;
      });
    }
  }

  Future<void> _loadScorers() async {
    if (_scorers.isNotEmpty) return;
    setState(() => _loadingScorers = true);
    final data = await Scores365Service.fetchTopScorersByCompetition(
        widget.competitionId);
    if (mounted) {
      setState(() {
        _scorers = data;
        _loadingScorers = false;
      });
    }
  }

  String get _title {
    if (_competition != null) return _competition!.name;
    if (widget.overrideName != null) return widget.overrideName!;
    return 'Competition';
  }

  String get _flagEmoji => _competition?.flagEmoji ?? '🏆';

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF4F6F8);
    final cardColor =
        isDark ? const Color(0xFF1A2A3A) : Colors.white;
    const gold = Color(0xFFFFD700);

    // Construire les tabs selon les capacités de la compétition
    final tabs = <Tab>[
      const Tab(text: 'Matchs'),
      if (_competition?.hasStandings ?? false)
        const Tab(text: 'Classements'),
      if (_competition?.hasStats ?? false)
        const Tab(text: 'Buteurs'),
      if (_competition?.hasBrackets ?? false)
        const Tab(text: 'Tableau'),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A242D) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(_flagEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_competition != null)
                    Text(
                      _competition!.confederationLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            if (_competition?.isActive ?? false)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'EN COURS',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tabController,
            indicatorColor: gold,
            labelColor: gold,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            onTap: (index) {
              // Charger les données lazy selon l'onglet
              if (index == 1 && (_competition?.hasStandings ?? false)) {
                _loadStandings();
              } else if (index == 2 && (_competition?.hasStats ?? false)) {
                _loadScorers();
              }
            },
            tabs: tabs,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchesTab(isDark, cardColor),
          if (_competition?.hasStandings ?? false)
            _buildStandingsTab(isDark),
          if (_competition?.hasStats ?? false)
            _buildScorersTab(isDark, cardColor),
          if (_competition?.hasBrackets ?? false)
            _buildBracketTab(isDark),
        ],
      ),
    );
  }

  // ── Onglet Matchs ──────────────────────────────────────────────────
  Widget _buildMatchesTab(bool isDark, Color cardColor) {
    if (_loadingMatches) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Erreur de chargement',
                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadMatches,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Aucun match disponible',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Les matchs apparaîtront ici dès qu\'ils sont programmés',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Grouper par date
    final grouped = <String, List<LiveMatch>>{};
    for (final m in _matches) {
      grouped.putIfAbsent(m.dateLabel, () => []).add(m);
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: const Color(0xFFFFD700),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: grouped.length,
        itemBuilder: (context, i) {
          final date = grouped.keys.elementAt(i);
          final dayMatches = grouped[date]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(date: date, isDark: isDark),
              ...dayMatches.map((m) => _CompetitionMatchCard(
                    match: m,
                    isDark: isDark,
                    cardColor: isDark
                        ? const Color(0xFF1A2A3A)
                        : Colors.white,
                  )),
            ],
          );
        },
      ),
    );
  }

  // ── Onglet Classements ────────────────────────────────────────────
  Widget _buildStandingsTab(bool isDark) {
    if (_loadingStandings) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_standings.isEmpty) {
      return Center(
        child: Text(
          'Classements non disponibles',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _standings.length,
      itemBuilder: (context, i) {
        final group = _standings[i];
        return _GroupStandingCard(group: group, isDark: isDark);
      },
    );
  }

  // ── Onglet Buteurs ────────────────────────────────────────────────
  Widget _buildScorersTab(bool isDark, Color cardColor) {
    if (_loadingScorers) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_scorers.isEmpty) {
      return Center(
        child: Text(
          'Buteurs non disponibles',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _scorers.length,
      itemBuilder: (context, i) {
        final scorer = _scorers[i];
        return _ScorerTile(
          rank: i + 1,
          scorer: scorer,
          isDark: isDark,
          cardColor: cardColor,
        );
      },
    );
  }

  // ── Onglet Tableau ────────────────────────────────────────────────
  Widget _buildBracketTab(bool isDark) {
    return Center(
      child: Text(
        'Tableau éliminatoire\nBientôt disponible',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54, fontSize: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.isDark});
  final String date;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        date,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CompetitionMatchCard extends StatelessWidget {
  const _CompetitionMatchCard({
    required this.match,
    required this.isDark,
    required this.cardColor,
  });
  final LiveMatch match;
  final bool isDark;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isFinished = match.isFinished;

    return GestureDetector(
      onTap: () {
        // Navigation vers MatchDetailScreen (à implémenter)
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isLive
              ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Équipe domicile
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NationFlagBadge(
                      countryCode: match.homeCode,
                      size: 32,
                      teamName: match.homeTeam,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.homeTeam,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Score / Heure
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    if (isLive || isFinished) ...[
                      Row(
                        children: [
                          Text(
                            '${match.scoreHome ?? '-'}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                            ),
                          ),
                          const Text(' – ',
                              style: TextStyle(fontSize: 18, color: Colors.grey)),
                          Text(
                            '${match.scoreAway ?? '-'}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLive
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isLive
                              ? (match.matchMinute ?? 'LIVE')
                              : 'FT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isLive ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        match.localTime,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NS',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Équipe extérieure
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    NationFlagBadge(
                      countryCode: match.awayCode,
                      size: 32,
                      teamName: match.awayTeam,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.awayTeam,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupStandingCard extends StatelessWidget {
  const _GroupStandingCard({required this.group, required this.isDark});
  final GroupStanding group;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    final cardBg = isDark ? const Color(0xFF1A2A3A) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header groupe
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.group, size: 16, color: gold),
                const SizedBox(width: 8),
                Text(
                  group.groupName,
                  style: const TextStyle(
                      color: gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          // En-tête colonnes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text('ÉQUIPE',
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontWeight: FontWeight.w700)),
                ),
                for (final h in ['J', 'G', 'N', 'P', 'BP', 'BC', 'Diff', 'Pts'])
                  SizedBox(
                    width: 28,
                    child: Text(h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // Lignes équipes
          ...group.teams.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final team = entry.value;
            final isQ = team.isQualified ?? false;
            return _StandingRow(
                rank: rank, team: team, isQ: isQ, isDark: isDark);
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow(
      {required this.rank,
      required this.team,
      required this.isQ,
      required this.isDark});
  final int rank;
  final StandingTeam team;
  final bool isQ;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A2A3A);
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        border: isQ
            ? const Border(
                left: BorderSide(color: Colors.green, width: 3))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$rank',
                style: TextStyle(
                    color: rank == 1 ? const Color(0xFFFFD700) : subColor,
                    fontWeight:
                        rank == 1 ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Row(
                children: [
                  NationFlagBadge(
                    countryCode: resolveCountryCode(team.teamName),
                    size: 24,
                    teamName: team.teamName,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      team.teamName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Colonnes : J / Diff / Pts
            for (final entry in [
              ('J', team.played),
              ('±', team.goalsDiff),
              ('Pts', team.points),
            ])
              SizedBox(
                width: entry.$1 == 'Pts' ? 34 : 28,
                child: Text(
                  '${entry.$2}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: entry.$1 == 'Pts' ? textColor : subColor,
                      fontWeight: entry.$1 == 'Pts'
                          ? FontWeight.w800
                          : FontWeight.w400),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScorerTile extends StatelessWidget {
  const _ScorerTile({
    required this.rank,
    required this.scorer,
    required this.isDark,
    required this.cardColor,
  });
  final int rank;
  final TopScorer scorer;
  final bool isDark;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A2A3A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? const Color(0xFFFFD700) : Colors.grey,
                fontWeight: FontWeight.w800,
                fontSize: rank == 1 ? 18 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          NationFlagBadge(
            countryCode: resolveCountryCode(scorer.teamName),
            size: 28,
            teamName: scorer.teamName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scorer.playerName,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: textColor),
                ),
                Text(
                  scorer.teamName,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Text('⚽', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '${scorer.goals}',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
