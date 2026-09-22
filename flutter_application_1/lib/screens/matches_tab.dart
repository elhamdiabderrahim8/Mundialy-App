// lib/screens/matches_tab.dart
// Tab 1 — Tous les matchs de toutes les compétitions nationales masculines
// Filtrage par : Date | Équipe | Compétition
import 'package:flutter/material.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/live_match.dart';
import '../services/scores365_service.dart';
import '../widgets/competition_badge.dart';
import '../widgets/nation_flag_badge.dart';
import 'competition_detail_screen.dart';

enum MatchFilterMode { byDate, byTeam, byCompetition }

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  MatchFilterMode _filterMode = MatchFilterMode.byDate;

  // Données
  List<LiveMatch> _allMatches = [];
  bool _loading = false;
  String? _error;

  // Filtre équipe
  String? _selectedTeamName;
  int? _selectedTeamId;

  // Filtre compétition
  Competition? _selectedCompetition;

  // Cache pour ne pas recharger à chaque changement de filtre
  bool _dataLoaded = false;

  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _loadAllMatches();
  }

  // Charger les matchs des compétitions actives + récentes (15 jours autour d'aujourd'hui)
  Future<void> _loadAllMatches() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    final start = _formatDate(now.subtract(const Duration(days: 30)));
    final end   = _formatDate(now.add(const Duration(days: 30)));

    // Compétitions à charger en priorité : actives d'abord + archivées récentes
    final toFetch = CompetitionsCatalog.all;

    try {
      final results = await Future.wait(
        toFetch.map((comp) => Scores365Service.fetchMatchesByCompetition(
              competitionId: comp.id,
              startDate: start,
              endDate: end,
              competitionName: comp.name,
            ).catchError((_) => <LiveMatch>[])),
        eagerError: false,
      );

      final all = results.expand((list) => list).toList();
      all.sort((a, b) =>
          (b.dateTime ?? DateTime(0)).compareTo(a.dateTime ?? DateTime(0)));

      if (mounted) {
        setState(() {
          _allMatches = all;
          _loading = false;
          _dataLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  // ── Filtres ──────────────────────────────────────────────────────

  List<LiveMatch> get _filteredMatches {
    switch (_filterMode) {
      case MatchFilterMode.byDate:
        return _allMatches;
      case MatchFilterMode.byTeam:
        if (_selectedTeamId == null) return [];
        return _allMatches.where((m) =>
            m.homeTeamId == _selectedTeamId ||
            m.awayTeamId == _selectedTeamId).toList();
      case MatchFilterMode.byCompetition:
        if (_selectedCompetition == null) return [];
        return _allMatches
            .where((m) => m.competitionId == _selectedCompetition!.id)
            .toList();
    }
  }

  // Grouper les matchs par date puis par compétition (pour mode "Par Date")
  Map<String, Map<String, List<LiveMatch>>> get _groupedByDateAndComp {
    final map = <String, Map<String, List<LiveMatch>>>{};
    for (final m in _filteredMatches) {
      final date = m.dateLabel;
      final comp = m.competitionName ?? 'Autres';
      map.putIfAbsent(date, () => {}).putIfAbsent(comp, () => []).add(m);
    }
    return map;
  }

  // Liste unique de toutes les équipes pour le sélecteur
  List<({int id, String name, String code})> get _allTeams {
    final seen = <int, ({int id, String name, String code})>{};
    for (final m in _allMatches) {
      if (m.homeTeamId != null) {
        seen[m.homeTeamId!] =
            (id: m.homeTeamId!, name: m.homeTeam, code: m.homeCode);
      }
      if (m.awayTeamId != null) {
        seen[m.awayTeamId!] =
            (id: m.awayTeamId!, name: m.awayTeam, code: m.awayCode);
      }
    }
    final list = seen.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF4F6F8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildFilterBar(isDark),
          if (_filterMode == MatchFilterMode.byTeam && _selectedTeamId == null)
            _buildTeamPicker(isDark)
          else if (_filterMode == MatchFilterMode.byCompetition &&
              _selectedCompetition == null)
            _buildCompetitionPicker(isDark)
          else
            Expanded(child: _buildMatchList(isDark)),
        ],
      ),
    );
  }

  // ── Barre de filtre ──────────────────────────────────────────────
  Widget _buildFilterBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1A242D) : Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          for (final mode in MatchFilterMode.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _filterMode = mode;
                  _selectedTeamName = null;
                  _selectedTeamId = null;
                  _selectedCompetition = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _filterMode == mode
                        ? _gold.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filterMode == mode
                          ? _gold
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: _filterMode == mode ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _modeLabel(mode),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _filterMode == mode
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _filterMode == mode
                          ? _gold
                          : (isDark ? Colors.white54 : Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _modeLabel(MatchFilterMode mode) {
    switch (mode) {
      case MatchFilterMode.byDate:
        return 'Par Date';
      case MatchFilterMode.byTeam:
        return 'Par Équipe';
      case MatchFilterMode.byCompetition:
        return 'Par Compétition';
    }
  }

  // ── Liste de matchs ──────────────────────────────────────────────
  Widget _buildMatchList(bool isDark) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _gold));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Connexion impossible',
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadAllMatches,
              icon: const Icon(Icons.refresh, color: _gold),
              label: const Text('Réessayer',
                  style: TextStyle(color: _gold)),
            ),
          ],
        ),
      );
    }

    if (_filteredMatches.isEmpty && _dataLoaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
              'Aucun match sur cette période',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'La prochaine trêve FIFA est en octobre 2026',
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13),
            ),
          ],
        ),
      );
    }

    switch (_filterMode) {
      case MatchFilterMode.byDate:
        return _buildByDateView(isDark);
      case MatchFilterMode.byTeam:
        return _buildSimpleMatchList(isDark);
      case MatchFilterMode.byCompetition:
        return _buildSimpleMatchList(isDark);
    }
  }

  // Mode "Par Date" : groupé date → compétition
  Widget _buildByDateView(bool isDark) {
    final grouped = _groupedByDateAndComp;
    final dates = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadAllMatches,
      color: _gold,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: dates.length,
        itemBuilder: (context, di) {
          final date = dates[di];
          final compGroups = grouped[date]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateSectionHeader(date: date, isDark: isDark),
              for (final compEntry in compGroups.entries) ...[
                _CompetitionGroupHeader(
                  name: compEntry.key,
                  isDark: isDark,
                  competitionId: compEntry.value.first.competitionId,
                  onTap: compEntry.value.first.competitionId != null
                      ? () => _openCompetition(compEntry.value.first.competitionId!)
                      : null,
                ),
                ...compEntry.value.map((m) => _MatchCard(
                    match: m,
                    isDark: isDark,
                    onTap: () => _openMatch(m))),
              ],
            ],
          );
        },
      ),
    );
  }

  // Mode simple (équipe ou compétition sélectionnée)
  Widget _buildSimpleMatchList(bool isDark) {
    final matches = _filteredMatches;
    return RefreshIndicator(
      onRefresh: _loadAllMatches,
      color: _gold,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: matches.length,
        itemBuilder: (context, i) => _MatchCard(
          match: matches[i],
          isDark: isDark,
          showCompetitionLabel: true,
          onTap: () => _openMatch(matches[i]),
        ),
      ),
    );
  }

  // ── Sélecteur d'équipe ────────────────────────────────────────────
  Widget _buildTeamPicker(bool isDark) {
    final teams = _allTeams;
    if (_loading) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator(color: _gold)));
    }
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Sélectionner une équipe',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: teams.length,
              itemBuilder: (context, i) {
                final t = teams[i];
                return ListTile(
                  leading: NationFlagBadge(
                      countryCode: t.code, size: 36, teamName: t.name),
                  title: Text(
                    t.name,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () => setState(() {
                    _selectedTeamId = t.id;
                    _selectedTeamName = t.name;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Sélecteur de compétition ─────────────────────────────────────
  Widget _buildCompetitionPicker(bool isDark) {
    final grouped = CompetitionsCatalog.groupedByConfederation;
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: grouped.length,
        itemBuilder: (context, i) {
          final conf = grouped.keys.elementAt(i);
          final comps = grouped[conf]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  conf,
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ...comps.map((comp) => ListTile(
                    leading: CompetitionBadge(
                      competition: comp,
                      size: 36,
                    ),
                    title: Text(
                      comp.name,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    subtitle: comp.isActive
                        ? const Text('EN COURS',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w700))
                        : null,
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey),
                    onTap: () {
                      // Ouvre directement la page compétition
                      _openCompetition(comp.id);
                    },
                  )),
              const Divider(height: 1, thickness: 0.5),
            ],
          );
        },
      ),
    );
  }

  // ── Navigation ───────────────────────────────────────────────────
  void _openCompetition(int competitionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CompetitionDetailScreen(competitionId: competitionId),
      ),
    );
  }

  void _openMatch(LiveMatch match) {
    // TODO: MatchDetailScreen (phase 2)
    // Pour l'instant, naviguer vers la compétition du match
    if (match.competitionId != null) {
      _openCompetition(match.competitionId!);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────────────────────

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.date, required this.isDark});
  final String date;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        date.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CompetitionGroupHeader extends StatelessWidget {
  const _CompetitionGroupHeader({
    required this.name,
    required this.isDark,
    this.competitionId,
    this.onTap,
  });
  final String name;
  final bool isDark;
  final int? competitionId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final comp = competitionId != null
        ? CompetitionsCatalog.findById(competitionId!)
        : null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Row(
          children: [
            CompetitionBadge(
              competition: comp,
              size: 22,
              iconSize: 12,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.isDark,
    required this.onTap,
    this.showCompetitionLabel = false,
  });
  final LiveMatch match;
  final bool isDark;
  final VoidCallback onTap;
  final bool showCompetitionLabel;

  static const Color _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isFinished = match.isFinished;
    final cardBg = isDark ? const Color(0xFF1A2A3A) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: isLive
              ? Border.all(
                  color: Colors.red.withValues(alpha: 0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              if (showCompetitionLabel && match.competitionName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    match.competitionName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Row(
                children: [
                  // Équipe domicile
                  Expanded(
                    child: Row(
                      children: [
                        NationFlagBadge(
                          countryCode: match.homeCode,
                          size: 30,
                          teamName: match.homeTeam,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.homeTeam,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A2A3A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bloc score/heure (centre)
                  Container(
                    width: 90,
                    alignment: Alignment.center,
                    child: _buildScoreOrTime(isLive, isFinished),
                  ),
                  // Équipe extérieure
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            match.awayTeam,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A2A3A),
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        NationFlagBadge(
                          countryCode: match.awayCode,
                          size: 30,
                          teamName: match.awayTeam,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreOrTime(bool isLive, bool isFinished) {
    if (isLive || isFinished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${match.scoreHome ?? '-'}  –  ${match.scoreAway ?? '-'}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A2A3A),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isLive
                  ? Colors.red.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isLive ? (match.matchMinute ?? 'LIVE') : 'FT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isLive ? Colors.red : Colors.grey,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          match.localTime,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _gold,
          ),
        ),
        Text(
          match.phaseLabel.length > 12
              ? '${match.phaseLabel.substring(0, 10)}…'
              : match.phaseLabel,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
