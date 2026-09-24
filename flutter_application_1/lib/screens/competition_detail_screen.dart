// lib/screens/competition_detail_screen.dart
// Page de détail d'une compétition : Matchs | Classements | Buteurs | Tableau
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/top_scorer.dart';
import '../services/scores365_service.dart';
import '../theme/app_theme.dart';
import '../utils/country_flags.dart';
import '../utils/standing_status.dart';
import '../utils/team_navigation.dart';
import '../widgets/competition_badge.dart';
import '../widgets/custom_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/match_card.dart';
import '../widgets/nation_flag_badge.dart';
import '../widgets/player_avatar.dart';
import '../widgets/status_badge.dart';


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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Cartes : token du thème (surface / 0xFF162634) — plus de hex en dur.
    final cardColor =
        theme.cardTheme.color ?? (isDark ? AppColors.ink : AppColors.surface);
    final gold = theme.colorScheme.secondary; // or champagne (DS §1)

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
      // Fond : token du thème (background / ink) — plus de hex en dur.
      appBar: AppBar(
        // DS §4 : appbar transparente, texte primary / blanc.
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_competition != null)
                    Text(
                      _competition!.confederationLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (_competition?.isActive ?? false)
              StatusBadge(
                label: 'EN COURS',
                // Fallback = même util que les lignes de classement (valeur unique).
                color: theme.extension<MatchColors>()?.win ??
                    standingStatusColor(StandingQualification.qualified),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tabController,
            indicatorColor: gold,
            labelColor: gold,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    if (_loadingMatches) {
      // Guide §4 : skeleton loaders, jamais de spinner centré.
      return MatchListSkeleton(isDark: isDark);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Erreur de chargement des matchs',
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: spacing.md),
              Text(
                'Erreur de chargement',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: spacing.lg),
              CustomButton(
                label: 'Réessayer',
                onPressed: _loadMatches,
              ),
            ],
          ),
        ),
      );
    }
    if (_matches.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Aucun match disponible',
        subtitle: 'Les matchs apparaîtront ici dès qu\'ils sont programmés',
      );
    }

    // Grouper par date
    final grouped = <String, List<LiveMatch>>{};
    for (final m in _matches) {
      grouped.putIfAbsent(m.dateLabel, () => []).add(m);
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: theme.colorScheme.secondary,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
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
    final spacing = Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    if (_loadingStandings) {
      return MatchListSkeleton(isDark: isDark);
    }
    if (_standings.isEmpty) {
      return const EmptyState(
        icon: Icons.leaderboard_rounded,
        title: 'Classements non disponibles',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.md, spacing.lg, spacing.lg),
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
    final spacing = Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    if (_loadingScorers) {
      return MatchListSkeleton(isDark: isDark);
    }
    if (_scorers.isEmpty) {
      return const EmptyState(
        icon: Icons.sports_soccer_rounded,
        title: 'Buteurs non disponibles',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(spacing.md),
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
    final spacing = Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    if (_bracket == null) {
      if (!_loadingBracket) {
        // Chargement aussi au swipe (onTap ne couvre que le tap).
        Future.microtask(_loadBracket);
      }
      return MatchListSkeleton(isDark: isDark);
    }
    final brackets = _bracket!['brackets'] as List? ?? [];
    if (brackets.isEmpty) {
      return const EmptyState(
        icon: Icons.account_tree_rounded,
        title: 'Tableau non disponible',
      );
    }
    final stages = (brackets.first as Map)['stages'] as List? ?? [];
    if (stages.isEmpty) {
      return const EmptyState(
        icon: Icons.account_tree_rounded,
        title: 'Tableau non disponible',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(spacing.md),
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
// WIDGETS INTERNES (langage DS : tokens du thème, grille 8pt,
// Semantics sur les zones tactiles — guide UI/UX §4-5)
// ─────────────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.isDark});
  final String date;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final gold = theme.colorScheme.secondary;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.lg, spacing.lg, spacing.xs),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, size: 15, color: gold),
          SizedBox(width: spacing.xs),
          Text(
            date,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w800,
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
    final spacing = Theme.of(context).extension<AppSpacing>() ?? const AppSpacing();
    final status = match.isLive
        ? 'en direct, ${match.statusDisplay}'
        : match.statusDisplay;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.xs),
      child: Semantics(
        // Guide §5 : annonce vocale du match pour TalkBack / VoiceOver.
        label: '${match.homeTeam} contre ${match.awayTeam}, $status',
        button: true,
        child: MatchCard(
          match: match,
          year: match.dateTime?.year ?? 2026,
          // Même formule que l'accueil (home_screen).
          textColor: isDark ? Colors.white : Colors.black87,
        ),
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final radii = theme.extension<AppRadii>() ?? const AppRadii();
    final gold = theme.colorScheme.secondary;
    final textColor =
        isDark ? Colors.white : AppColors.primary;
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: textColor.withValues(alpha: 0.5),
      fontWeight: FontWeight.w700,
    );

    return Container(
      margin: EdgeInsets.only(bottom: spacing.xl),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(radii.lg),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header groupe
          Container(
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(radii.lg),
              ),
            ),
            child: Center(
              child: Text(
                group.groupName.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          // En-tête colonnes
          Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text('Pos', style: headerStyle),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text('Équipe', style: headerStyle),
                    ),
                    for (final h in ['MJ', 'GD', 'PTS'])
                      Expanded(
                        child: Text(
                          h,
                          textAlign: TextAlign.center,
                          style: headerStyle,
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
                SizedBox(height: spacing.lg),
                Row(
                  children: [
                    // Source unique : même util que les lignes (pas de hex dupliqué).
                    _LegendItem(
                        color: standingStatusColor(
                            StandingQualification.qualified),
                        label: 'Qualifié'),
                    SizedBox(width: spacing.lg),
                    _LegendItem(
                        color: standingStatusColor(
                            StandingQualification.eliminated),
                        label: 'Éliminé'),
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: spacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final gold = theme.colorScheme.secondary;
    final textColor = isDark ? Colors.white : AppColors.primary;
    final status = standingQualification(
      rank,
      isQualified: team.isQualified,
      toQualify: team.toQualify,
    );
    final statusColor = standingStatusColor(status);

    return Semantics(
      // Guide §5 : annonce vocale (le statut n'est pas que couleur).
      label:
          '${team.teamName}, ${rank}e, ${team.points} points, ${standingStatusLabel(status)}',
      button: true,
      child: InkWell(
        onTap: () => openTeamProfile(
          context,
          teamName: team.teamName,
          teamId: team.teamId,
          competitionId: competitionId,
        ),
        borderRadius: BorderRadius.circular(spacing.sm),
        child: Container(
          // Guide §5 : zone tactile ≥ 48dp.
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
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
                  padding: EdgeInsets.only(left: spacing.sm),
                  child: Text(
                    '$rank',
                    style: theme.textTheme.titleSmall?.copyWith(
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
                    SizedBox(width: spacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            team.teamName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            standingStatusLabel(status),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: textColor),
                ),
              ),
              Expanded(
                child: Text(
                  '${team.goalsDiff}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: textColor),
                ),
              ),
              Expanded(
                child: Text(
                  '${team.points}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final radii = theme.extension<AppRadii>() ?? const AppRadii();
    final gold = theme.colorScheme.secondary;
    final cardBg = theme.cardTheme.color;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      margin: EdgeInsets.only(bottom: spacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(radii.lg),
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
            padding: EdgeInsets.symmetric(
                horizontal: spacing.lg, vertical: spacing.sm + 2),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(radii.lg)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 16, color: gold),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    stageName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Text(
                'Phase directe (matchs dans l\'onglet Matchs)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: groups.map((g) {
                  final name = g['name']?.toString() ?? 'Groupe';
                  return Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: spacing.md, vertical: spacing.xs),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(radii.full),
                      border:
                          Border.all(color: gold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      name,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final radii = theme.extension<AppRadii>() ?? const AppRadii();
    final matchColors =
        theme.extension<MatchColors>() ?? const MatchColors.light();
    final gold = theme.colorScheme.secondary;
    final textColor = theme.colorScheme.onSurface;
    final rankColor = rank == 1
        ? gold
        : rank == 2
            ? matchColors.rankSilver
            : rank == 3
                ? matchColors.rankBronze
                : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      // Guide §5 : annonce vocale du buteur.
      label: '${scorer.playerName}, ${scorer.goals} buts',
      child: Container(
        margin: EdgeInsets.only(bottom: spacing.sm),
        padding: EdgeInsets.symmetric(
            horizontal: spacing.lg, vertical: spacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(radii.lg),
          border: rank == 1
              ? Border.all(color: gold.withValues(alpha: 0.4))
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
                style: (rank == 1
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(
                  color: rankColor,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: spacing.md),
            // Avatar partagé DS (photo + initiale en repli).
            PlayerAvatar(
              name: scorer.playerName,
              imageUrl: scorer.bestPhotoUrl,
              size: 40,
            ),
            SizedBox(width: spacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scorer.playerName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Row(
                    children: [
                      NationFlagBadge(
                        countryCode: resolveCountryCode(scorer.teamName),
                        size: 14,
                        teamName: scorer.teamName,
                      ),
                      SizedBox(width: spacing.xs),
                      Expanded(
                        child: Text(
                          scorer.assists > 0
                              ? '${scorer.teamName} • ${scorer.assists} passes'
                              : scorer.teamName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.6),
                          ),
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
              padding: EdgeInsets.symmetric(
                  horizontal: spacing.md, vertical: spacing.xs),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(radii.full),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_soccer_rounded, size: 14, color: gold),
                  SizedBox(width: spacing.xs - 4),
                  Text(
                    '${scorer.goals}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
