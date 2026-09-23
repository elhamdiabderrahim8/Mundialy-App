// lib/screens/matches_tab.dart
// Tab 1 — Tous les matchs de toutes les compétitions nationales masculines
// Filtrage par : Matches (par date) | Compétition (par continents)
import 'package:flutter/material.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/live_match.dart';
import '../services/scores365_service.dart';
import '../widgets/competition_badge.dart';
import '../widgets/continent_competition_picker.dart';
import '../widgets/nation_flag_badge.dart';
import 'competition_detail_screen.dart';

enum MatchFilterMode { byDate, byCompetition }

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
      // Même batching que home_screen : évite le rate-limit 365Scores (WAF).
      final results = <LiveMatch>[];
      const batchSize = 3;
      for (var i = 0; i < toFetch.length; i += batchSize) {
        final batch = toFetch.sublist(
            i, i + batchSize > toFetch.length ? toFetch.length : i + batchSize);
        final futures = batch.map((comp) =>
            Scores365Service.fetchMatchesByCompetition(
              competitionId: comp.id,
              startDate: start,
              endDate: end,
              competitionName: comp.name,
            ).catchError((_) => <LiveMatch>[]));
        final batchResults = await Future.wait(futures);
        for (final list in batchResults) {
          results.addAll(list);
        }
        if (i + batchSize < toFetch.length) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      final all = results;
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
      case MatchFilterMode.byCompetition:
        if (_selectedCompetition == null) return [];
        return _allMatches
            .where((m) => m.competitionId == _selectedCompetition!.id)
            .toList();
    }
  }

  // Grouper les matchs par date puis par compétition (mode "Matches")
  Map<String, Map<String, List<LiveMatch>>> get _groupedByDateAndComp {
    final map = <String, Map<String, List<LiveMatch>>>{};
    for (final m in _filteredMatches) {
      final date = m.dateLabel;
      final comp = m.competitionName ?? 'Autres';
      map.putIfAbsent(date, () => {}).putIfAbsent(comp, () => []).add(m);
    }
    return map;
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
          if (_filterMode == MatchFilterMode.byCompetition &&
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
        return 'Matches';
      case MatchFilterMode.byCompetition:
        return 'Compétition';
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
      case MatchFilterMode.byCompetition:
        return _buildSimpleMatchList(isDark);
    }
  }

  // Mode "Matches" : groupé date → compétition
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
                  matchCount: compEntry.value.length,
                  onTap: compEntry.value.first.competitionId != null
                      ? () => _openCompetition(compEntry.value.first.competitionId!)
                      : null,
                ),
                ...compEntry.value.map((m) => _MatchCard(
                    match: m,
                    isDark: isDark,
                    showCompetitionLabel: false,
                    onTap: () => _openMatch(m))),
              ],
            ],
          );
        },
      ),
    );
  }

  // Mode simple (équipe ou compétition sélectionnée)
  // ── CORRIGÉ : un seul header compétition en haut (logo + nom + cliquable),
  // plus aucun nom de compétition répété sur les cartes.
  Widget _buildSimpleMatchList(bool isDark) {
    final matches = List<LiveMatch>.from(_filteredMatches)
      ..sort((a, b) => (a.dateTime ?? DateTime(0))
          .compareTo(b.dateTime ?? DateTime(0)));
    final comp = _selectedCompetition;
    final first = matches.isNotEmpty ? matches.first : null;
    final compId = comp?.id ?? first?.competitionId;
    final compName = comp?.name ??
        first?.competitionName ??
        'Compétition';

    return RefreshIndicator(
      onRefresh: _loadAllMatches,
      color: _gold,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: matches.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: _CompetitionGroupHeader(
                name: compName,
                isDark: isDark,
                competitionId: compId,
                matchCount: matches.length,
                onTap: compId != null
                    ? () => _openCompetition(compId)
                    : null,
              ),
            );
          }
          final m = matches[i - 1];
          return _MatchCard(
            match: m,
            isDark: isDark,
            // Jamais de label compétition sur la carte : il est dans le header.
            showCompetitionLabel: false,
            onTap: () => _openMatch(m),
          );
        },
      ),
    );
  }

  // ── Sélecteur de compétition : continents → compétitions ────────────
  //
  // Chaque continent (icône SVG de sa carte) se déplie dans la même page
  // pour afficher ses compétitions. Un tap sur une compétition ouvre sa
  // page (matchs, classements, tableau, buteurs).
  Widget _buildCompetitionPicker(bool isDark) {
    return Expanded(
      child: ContinentCompetitionPicker(
        isDark: isDark,
        onSelectCompetition: _openCompetition,
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
    this.matchCount,
  });
  final String name;
  final bool isDark;
  final int? competitionId;
  final VoidCallback? onTap;
  final int? matchCount;

  @override
  Widget build(BuildContext context) {
    final comp = competitionId != null
        ? CompetitionsCatalog.findById(competitionId!)
        : null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            CompetitionBadge(
              competition: comp,
              size: 26,
              iconSize: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A2A3A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (matchCount != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$matchCount',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
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
    // Conservé pour compatibilité d'appel, mais ignoré :
    // le nom de compétition ne s'affiche JAMAIS sur la carte,
    // il est uniquement dans le _CompetitionGroupHeader cliquable.
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
