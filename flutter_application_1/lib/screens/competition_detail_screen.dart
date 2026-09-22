// lib/screens/competition_detail_screen.dart
// Page de détail d'une compétition : Matchs | Classements | Buteurs | Tableau
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/top_scorer.dart';
import '../services/scores365_service.dart';
import '../utils/country_flags.dart';
import '../utils/standing_status.dart';
import '../utils/team_navigation.dart';
import '../widgets/competition_badge.dart';
import '../widgets/match_card.dart';
import '../widgets/nation_flag_badge.dart';

// Or champagne de l'app (identité Mundialy — cf. home_screen _kGold).
const Color _kGold = Color(0xFFE7C16A);
const Color _kBgDark = Color(0xFF0D1B2A);
const Color _kCardDark = Color(0xFF1D2D3B);


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
  Map<String, dynamic>? _bracket;

  bool _loadingMatches = true;
  bool _loadingStandings = false;
  bool _loadingScorers = false;
  bool _loadingBracket = false;
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
      final matches = await Scores365Service.fetchAllMatchesForCompetition(
        competitionId: widget.competitionId,
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

  Future<void> _loadBracket() async {
    if (_bracket != null) return;
    setState(() => _loadingBracket = true);
    final data = await Scores365Service.fetchBracketsByCompetition(
        widget.competitionId);
    if (mounted) {
      setState(() {
        _bracket = data;
        _loadingBracket = false;
      });
    }
  }

  /// Ordre réel des onglets (les onglets sont conditionnels).
  List<String> get _tabKeys => [
        'matches',
        if (_competition?.hasStandings ?? false) 'standings',
        if (_competition?.hasStats ?? false) 'scorers',
        if (_competition?.hasBrackets ?? false) 'bracket',
      ];

  String get _title {
    if (_competition != null) return _competition!.name;
    if (widget.overrideName != null) return widget.overrideName!;
    return 'Competition';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _kBgDark : const Color(0xFFF4F6F8);
    final cardColor = isDark ? _kCardDark : Colors.white;
    const gold = _kGold;

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
            CompetitionBadge(competition: _competition, size: 38),
            const SizedBox(width: 10),
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
              // Charger les données lazy selon le VRAI onglet (ordre variable).
              final key = (index >= 0 && index < _tabKeys.length)
                  ? _tabKeys[index]
                  : '';
              if (key == 'standings') {
                _loadStandings();
              } else if (key == 'scorers') {
                _loadScorers();
              } else if (key == 'bracket') {
                _loadBracket();
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
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Erreur de chargement',
                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadMatches,
              icon: const Icon(Icons.refresh_rounded, color: _kGold),
              label: const Text('Réessayer',
                  style: TextStyle(color: _kGold)),
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
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGold.withValues(alpha: 0.1),
                border:
                    Border.all(color: _kGold.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 40, color: _kGold),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun match disponible',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
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
      color: _kGold,
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
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }
    if (_standings.isEmpty) {
      return _EmptyState(
        icon: Icons.leaderboard_rounded,
        label: 'Classements non disponibles',
        isDark: isDark,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _standings.length,
      itemBuilder: (context, i) {
        final group = _standings[i];
        return _GroupStandingCard(
          group: group,
          isDark: isDark,
          competitionId: widget.competitionId,
        );
      },
    );
  }

  // ── Onglet Buteurs ────────────────────────────────────────────────
  Widget _buildScorersTab(bool isDark, Color cardColor) {
    if (_loadingScorers) {
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }
    if (_scorers.isEmpty) {
      return _EmptyState(
        icon: Icons.sports_soccer_rounded,
        label: 'Buteurs non disponibles',
        isDark: isDark,
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
    if (_bracket == null) {
      if (!_loadingBracket) {
        // Chargement aussi au swipe (onTap ne couvre que le tap).
        Future.microtask(_loadBracket);
      }
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }
    final brackets = _bracket!['brackets'] as List? ?? [];
    if (brackets.isEmpty) {
      return _EmptyState(
        icon: Icons.account_tree_rounded,
        label: 'Tableau non disponible',
        isDark: isDark,
      );
    }
    final stages = (brackets.first as Map)['stages'] as List? ?? [];
    if (stages.isEmpty) {
      return _EmptyState(
        icon: Icons.account_tree_rounded,
        label: 'Tableau non disponible',
        isDark: isDark,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: stages.length,
      itemBuilder: (context, i) {
        final stage = stages[i] as Map? ?? {};
        final groups = stage['groups'] as List? ?? [];
        return _BracketStageCard(
          stageName: stage['name']?.toString() ?? 'Phase',
          groups: groups.whereType<Map>().toList(),
          isDark: isDark,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// WIDGETS INTERNES (même langage que l'accueil : or champagne,
// radius 16, Material rounded icons, ripple sur les zones tactiles)
// ─────────────────────────────────────────────────────────────────────

/// État vide générique : icône vectorielle dans pastille or (jamais d'emoji).
class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.label, required this.isDark});
  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold.withValues(alpha: 0.1),
              border: Border.all(color: _kGold.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 40, color: _kGold),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.isDark});
  final String date;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 15, color: _kGold),
          const SizedBox(width: 6),
          Text(
            date,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte strictement identique à l'accueil : délègue à [MatchCard].
class _CompetitionMatchCard extends StatelessWidget {
  const _CompetitionMatchCard({required this.match, required this.isDark});
  final LiveMatch match;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MatchCard(
        match: match,
        year: match.dateTime?.year ?? 2026,
        // Même formule que l'accueil (home_screen).
        textColor: isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}

/// Carte de classement — langage d'origine (avant septembre) :
/// carte translucide radius 20, header or centré en majuscules,
/// colonnes Pos/Équipe/MJ/GD/PTS, liseré de statut, points en or.
class _GroupStandingCard extends StatelessWidget {
  const _GroupStandingCard({
    required this.group,
    required this.isDark,
    required this.competitionId,
  });
  final GroupStanding group;
  final bool isDark;
  final int competitionId;

  @override
  Widget build(BuildContext context) {
    const gold = _kGold;
    final textColor =
        isDark ? Colors.white : const Color(0xFF16324A);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header groupe
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Center(
              child: Text(
                group.groupName.toUpperCase(),
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          // En-tête colonnes
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Pos',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Équipe',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (final h in ['MJ', 'GD', 'PTS'])
                      Expanded(
                        child: Text(
                          h,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Divider(
                    color: textColor.withValues(alpha: 0.12), height: 20),
                // Lignes équipes
                ...group.teams.asMap().entries.map((entry) {
                  final team = entry.value;
                  final rank =
                      team.rank > 0 ? team.rank : entry.key + 1;
                  return _StandingRow(
                    rank: rank,
                    team: team,
                    isDark: isDark,
                    competitionId: competitionId,
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _LegendItem(
                        color: const Color(0xFF2ECC71), label: 'Qualifié'),
                    const SizedBox(width: 16),
                    _LegendItem(
                        color: const Color(0xFFE74C3C), label: 'Éliminé'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.team,
    required this.isDark,
    required this.competitionId,
  });
  final int rank;
  final StandingTeam team;
  final bool isDark;
  final int competitionId;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? Colors.white : const Color(0xFF16324A);
    final status = standingQualification(
      rank,
      isQualified: team.isQualified,
      toQualify: team.toQualify,
    );
    final statusColor = standingStatusColor(status);

    return InkWell(
      onTap: () => openTeamProfile(
        context,
        teamName: team.teamName,
        teamId: team.teamId,
        competitionId: competitionId,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: statusColor.withValues(alpha: 0.55),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  NationFlagBadge(
                    countryCode: resolveCountryCode(team.teamName),
                    size: 24,
                    teamName: team.teamName,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.teamName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          standingStatusLabel(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                '${team.played}',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                '${team.goalsDiff}',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                '${team.points}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketStageCard extends StatelessWidget {
  const _BracketStageCard({
    required this.stageName,
    required this.groups,
    required this.isDark,
  });
  final String stageName;
  final List<Map> groups;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const gold = _kGold;
    final cardBg = isDark ? _kCardDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2A3A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_rounded,
                    size: 16, color: gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stageName,
                    style: const TextStyle(
                        color: gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Phase directe (matchs dans l\'onglet Matchs)',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: groups.map((g) {
                  final name = g['name']?.toString() ?? 'Groupe';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: gold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
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
    final rankColor = rank == 1
        ? _kGold
        : rank == 2
            ? const Color(0xFFE0E0E0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: rank == 1
            ? Border.all(color: _kGold.withValues(alpha: 0.4))
            : null,
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
                color: rankColor,
                fontWeight: FontWeight.w800,
                fontSize: rank == 1 ? 18 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // Avatar joueur (photo 365Scores, initiale en repli)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold.withValues(alpha: 0.12),
              border: Border.all(
                  color: _kGold.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.hardEdge,
            child: scorer.bestPhotoUrl != null
                ? CachedNetworkImage(
                    imageUrl: scorer.bestPhotoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        scorer.playerName.isNotEmpty
                            ? scorer.playerName
                                .substring(0, 1)
                                .toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      scorer.playerName.isNotEmpty
                          ? scorer.playerName
                              .substring(0, 1)
                              .toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
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
                Row(
                  children: [
                    NationFlagBadge(
                      countryCode:
                          resolveCountryCode(scorer.teamName),
                      size: 14,
                      teamName: scorer.teamName,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        scorer.assists > 0
                            ? '${scorer.teamName} • ${scorer.assists} passes'
                            : scorer.teamName,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : Colors.black54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_soccer_rounded,
                    size: 14, color: _kGold),
                const SizedBox(width: 4),
                Text(
                  '${scorer.goals}',
                  style: const TextStyle(
                    color: _kGold,
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
