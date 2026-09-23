// lib/screens/matches_tab.dart
// Tab 1 — Tous les matchs de toutes les compétitions nationales masculines
// Filtrage par : Matches (par date) | Compétition (par continents)
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/live_match.dart';
import '../services/scores365_service.dart';
import '../utils/app_routes.dart';
import '../widgets/competition_badge.dart';
import '../widgets/continent_competition_picker.dart';
import '../widgets/loading_skeletons.dart';
import '../widgets/match_card.dart';
import '../widgets/nation_flag_badge.dart';
import 'competition_detail_screen.dart';
import 'match_details_screen.dart';

enum MatchFilterMode { byDate, byCompetition }

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  MatchFilterMode _filterMode = MatchFilterMode.byDate;

  List<LiveMatch> _allMatches = [];
  bool _loading = false;
  String? _error;

  Competition? _selectedCompetition;
  int? _selectedCompetitionId;
  String _selectedCompetitionName = 'Compétition';
  bool _dataLoaded = false;

  int _loadedComps = 0;
  int _totalComps = 0;

  final ScrollController _scrollController = ScrollController();
  final Map<DateTime, GlobalKey> _dayKeys = {};
  bool _jumpedToToday = false;
  bool _showTodayFab = false;

  static const Color _gold = AppColors.secondary;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAllMatches();
  }

  void _onScroll() {
    if (!mounted) return;
    final show = _scrollController.hasClients && _scrollController.offset > 120;
    if (show != _showTodayFab) {
      setState(() => _showTodayFab = show);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMatches() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _loadedComps = 0;
      _jumpedToToday = false;
    });

    final now = DateTime.now();
    final start = _formatDate(now.subtract(const Duration(days: 30)));
    final end = _formatDate(now.add(const Duration(days: 30)));
    final toFetch = CompetitionsCatalog.all;

    try {
      final results = <LiveMatch>[];
      const batchSize = 3;
      final totalBatches = (toFetch.length + batchSize - 1) ~/ batchSize;
      setState(() => _totalComps = toFetch.length);

      for (var i = 0; i < toFetch.length; i += batchSize) {
        final batchEnd =
            i + batchSize > toFetch.length ? toFetch.length : i + batchSize;
        final batch = toFetch.sublist(i, batchEnd);
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
        if (mounted) {
          setState(() => _loadedComps = batchEnd);
        }
        final batchIndex = i ~/ batchSize + 1;
        if (batchIndex < totalBatches) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      final all = results;
      all.sort((a, b) =>
          (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)));

      if (mounted) {
        setState(() {
          _allMatches = all;
          _loading = false;
          _dataLoaded = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_jumpedToToday && mounted) _jumpToToday();
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

  DateTime _dayKey(LiveMatch m) {
    final dt = m.dateTime;
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    final parsed = _parseDateLabel(m.dateLabel);
    if (parsed != null) return parsed;
    return DateTime(0);
  }

  DateTime? _parseDateLabel(String label) {
    final parts = label.split('/');
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        // Format API attendu : MM/dd/yyyy ou dd/MM/yyyy
        if (a > 12) return DateTime(c, a, b);
        if (b > 12) return DateTime(c, b, a);
        return DateTime(c, a, b);
      }
    }
    return null;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return "AUJOURD'HUI";
    if (diff == 1) return 'DEMAIN';
    if (diff == -1) return 'HIER';
    const weekdays = [
      'LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM',
    ];
    const months = [
      'JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUN',
      'JUL', 'AOÛT', 'SEP', 'OCT', 'NOV', 'DÉC',
    ];
    final wd = weekdays[day.weekday - 1];
    final mo = months[day.month - 1];
    return '$wd ${day.day} $mo';
  }

  void _jumpToToday() {
    if (!mounted || !_scrollController.hasClients) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final key = _dayKeys[today];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    _jumpedToToday = true;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // Position absolue du header dans la fenêtre, puis on convertit en offset scroll.
    final global = box.localToGlobal(Offset.zero).dy;
    final statusBar = MediaQuery.of(context).padding.top;
    final listTop = 0.0; // le ListView commence sous le filtre (déjà en haut)
    final desiredGlobal = statusBar + listTop + 8;
    final delta = global - desiredGlobal;
    final next = (_scrollController.position.pixels + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(next);
  }

  List<LiveMatch> get _filteredMatches {
    switch (_filterMode) {
      case MatchFilterMode.byDate:
        return _allMatches;
      case MatchFilterMode.byCompetition:
        final id = _selectedCompetition?.id ?? _selectedCompetitionId;
        if (id == null) return [];
        return _allMatches.where((m) => m.competitionId == id).toList();
    }
  }

  Map<DateTime, Map<String, List<LiveMatch>>> get _groupedByDayAndComp {
    final map = <DateTime, Map<String, List<LiveMatch>>>{};
    final matches = List<LiveMatch>.from(_filteredMatches)
      ..sort((a, b) =>
          (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)));
    for (final m in matches) {
      final day = _dayKey(m);
      final comp = m.competitionName ?? 'Autres';
      map.putIfAbsent(day, () => {}).putIfAbsent(comp, () => []).add(m);
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
          if (_loading && !_dataLoaded)
            _buildLoadProgress(isDark)
          else if (_filterMode == MatchFilterMode.byCompetition &&
              _selectedCompetition == null &&
              _selectedCompetitionId == null)
            _buildCompetitionPicker(isDark)
          else
            Expanded(child: _buildMatchList(isDark)),
        ],
      ),
    );
  }

  Widget _buildLoadProgress(bool isDark) {
    final total = _totalComps == 0 ? 1 : _totalComps;
    final value = (_loadedComps / total).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _gold,
                    value: value,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chargement… $_loadedComps/$_totalComps compétitions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MatchListSkeleton(isDark: isDark, itemCount: 5),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1A242D) : Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              for (final mode in MatchFilterMode.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Semantics(
                      button: true,
                      selected: _filterMode == mode,
                      label: _modeLabel(mode),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() {
                          _filterMode = mode;
                          if (mode == MatchFilterMode.byDate) {
                            _selectedCompetition = null;
                            _selectedCompetitionId = null;
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _filterMode == mode
                                ? _gold.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _filterMode == mode
                                  ? _gold
                                  : (isDark
                                      ? Colors.white24
                                      : Colors.grey.shade300),
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
                  ),
                ),
            ],
          ),
        ),
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

  Widget _buildMatchList(bool isDark) {
    if (_loading && _allMatches.isEmpty) {
      return MatchListSkeleton(isDark: isDark);
    }
    if (_error != null && _allMatches.isEmpty) {
      return _buildErrorState(isDark);
    }
    if (_filteredMatches.isEmpty && _dataLoaded) {
      return _buildEmptyState(isDark);
    }

    switch (_filterMode) {
      case MatchFilterMode.byDate:
        return _buildByDateView(isDark);
      case MatchFilterMode.byCompetition:
        return _buildSimpleMatchList(isDark);
    }
  }

  Widget _buildErrorState(bool isDark) {
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
          const SizedBox(height: 4),
          Text(
            'Vérifiez votre réseau puis réessayez',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadAllMatches,
            icon: const Icon(Icons.refresh, color: _gold),
            label: const Text('Réessayer', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final byComp = _filterMode == MatchFilterMode.byCompetition;
    final title = byComp
        ? 'Aucun match pour cette compétition'
        : 'Aucun match sur cette période';
    final subtitle = byComp
        ? 'Essaie une autre compétition ou reviens au mode Matches.'
        : 'Pas de rencontre programmée ±30 jours autour d’aujourd’hui.';
    final hasOtherData = byComp;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 52,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (hasOtherData) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedCompetition = null;
                  _selectedCompetitionId = null;
                }),
                icon: const Icon(Icons.arrow_back, color: _gold, size: 18),
                label: const Text(
                  'Choisir une autre compétition',
                  style: TextStyle(color: _gold),
                ),
              ),
            ],
            if (!byComp && _allMatches.isEmpty) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadAllMatches,
                icon: const Icon(Icons.refresh, color: _gold),
                label: const Text('Rafraîchir', style: TextStyle(color: _gold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildByDateView(bool isDark) {
    final grouped = _groupedByDayAndComp;
    final days = grouped.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    // Index du jour "aujourd'hui" pour le bouton flottant
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = days.indexOf(today);
    final showTodayFab = _dataLoaded && _showTodayFab && todayIndex >= 0;

    return Stack(
      children: [
        RefreshIndicator(
          color: _gold,
          onRefresh: _loadAllMatches,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: days.length,
            itemBuilder: (context, di) {
              final day = days[di];
              final compGroups = grouped[day]!;
              final isToday = day == today;
              _dayKeys.putIfAbsent(day, () => GlobalKey());
              return KeyedSubtree(
                key: _dayKeys[day],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateSectionHeader(
                      date: _dayLabel(day),
                      isDark: isDark,
                      isToday: isToday,
                    ),
                    for (final compEntry in compGroups.entries) ...[
                      _CompetitionGroupHeader(
                        name: compEntry.key,
                        isDark: isDark,
                        competitionId: compEntry.value.first.competitionId,
                        matchCount: compEntry.value.length,
                        onTap: compEntry.value.first.competitionId != null
                            ? () => _openCompetition(
                                compEntry.value.first.competitionId!)
                            : null,
                      ),
                      ...compEntry.value.map((m) => _MatchCard(
                            match: m,
                            isDark: isDark,
                            onTap: () => _openMatch(m),
                          )),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (showTodayFab)
          Positioned(
            right: 16,
            bottom: 16,
            child: Semantics(
              button: true,
              label: "Revenir à aujourd'hui",
              child: FloatingActionButton.small(
                heroTag: 'matches_tab_today',
                backgroundColor: isDark ? const Color(0xFF1A2A3D) : Colors.white,
                foregroundColor: isDark ? Colors.white : AppColors.ink,
                elevation: 3,
                onPressed: () {
                  _jumpedToToday = false;
                  _jumpToToday();
                },
                child: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSimpleMatchList(bool isDark) {
    final matches = List<LiveMatch>.from(_filteredMatches)
      ..sort((a, b) => (a.dateTime ?? DateTime(0))
          .compareTo(b.dateTime ?? DateTime(0)));
    final compId = _selectedCompetition?.id ?? _selectedCompetitionId;
    final compName = _selectedCompetition?.name ?? _selectedCompetitionName;

    return RefreshIndicator(
      color: _gold,
      onRefresh: _loadAllMatches,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: matches.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _CompetitionGroupHeader(
                      name: compName,
                      isDark: isDark,
                      competitionId: compId,
                      matchCount: matches.length,
                      onTap: compId != null
                          ? () => _openCompetition(compId)
                          : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Changer de compétition',
                    onPressed: () => setState(() {
                      _selectedCompetition = null;
                      _selectedCompetitionId = null;
                    }),
                    icon: Icon(
                      Icons.unfold_more_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            );
          }
          if (i == matches.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedCompetition = null;
                    _selectedCompetitionId = null;
                  }),
                  icon: const Icon(Icons.swap_vert, size: 18, color: _gold),
                  label: const Text(
                    'Changer de compétition',
                    style: TextStyle(color: _gold),
                  ),
                ),
              ),
            );
          }
          final m = matches[i - 1];
          return _MatchCard(
            match: m,
            isDark: isDark,
            onTap: () => _openMatch(m),
          );
        },
      ),
    );
  }

  Widget _buildCompetitionPicker(bool isDark) {
    return Expanded(
      child: Column(
        children: [
          if (_error != null && _allMatches.isEmpty)
            Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 18, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Matchs non chargés — le filtre peut être incomplet',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadAllMatches,
                      child: const Text('Réessayer',
                          style: TextStyle(color: _gold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ContinentCompetitionPicker(
              isDark: isDark,
              onSelectCompetition: _selectCompetition,
            ),
          ),
        ],
      ),
    );
  }

  /// Le picker filtre localement (mode Compétition) au lieu de naviguer.
  void _selectCompetition(int competitionId) {
    final comp = CompetitionsCatalog.findById(competitionId);
    setState(() {
      _filterMode = MatchFilterMode.byCompetition;
      _selectedCompetition = comp;
      _selectedCompetitionId = competitionId;
      _selectedCompetitionName = comp?.name ?? 'Compétition';
    });
  }

  void _openCompetition(int competitionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompetitionDetailScreen(competitionId: competitionId),
      ),
    );
  }

  void _openMatch(LiveMatch match) {
    Navigator.of(context).push(
      PremiumPageRoute(page: MatchDetailsScreen(match: match)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────────────────────

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({
    required this.date,
    required this.isDark,
    this.isToday = false,
  });
  final String date;
  final bool isDark;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        date,
        style: TextStyle(
          color: isToday
              ? const Color(0xFFE7C16A)
              : (isDark ? Colors.white54 : Colors.black45),
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
    final canTap = onTap != null;

    final child = Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE7C16A).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$matchCount',
                style: const TextStyle(
                  color: Color(0xFFE7C16A),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          if (canTap)
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
        ],
      ),
    );

    if (!canTap) return child;

    return Semantics(
      button: true,
      label: '$name, ${matchCount ?? 0} matchs. Ouvrir la compétition',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: child,
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
  });
  final LiveMatch match;
  final bool isDark;
  final VoidCallback onTap;

  String get _semanticLabel {
    final status = match.isLive
        ? 'en direct ${match.statusDisplay}'
        : match.isFinished
            ? 'terminé ${match.scoreHome ?? 0} à ${match.scoreAway ?? 0}'
            : 'à ${match.localTime}';
    return '${match.homeTeam} contre ${match.awayTeam}, $status';
  }

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isFinished = match.isFinished;
    final cardBg = isDark ? const Color(0xFF1A2A3A) : Colors.white;

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
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
                  SizedBox(
                    width: 96,
                    child: _buildScoreOrTime(isLive, isFinished, isDark),
                  ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreOrTime(bool isLive, bool isFinished, bool isDark) {
    if (isLive || isFinished) {
      final penalties = (match.penaltyHome != null && match.penaltyAway != null)
          ? ' (${match.penaltyHome}-${match.penaltyAway} tab)'
          : '';
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
          if (penalties.isNotEmpty)
            Text(
              penalties,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isLive
                  ? Colors.red.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLive) ...[
                  const PulsingLiveDot(),
                  const SizedBox(width: 4),
                ],
                Text(
                  isLive ? (match.statusDisplay) : 'FT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isLive ? Colors.red : Colors.grey,
                  ),
                ),
              ],
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
            color: Color(0xFFE7C16A),
          ),
        ),
        Text(
          match.phaseLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
