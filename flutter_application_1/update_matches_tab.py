import re

with open('lib/screens/matches_tab.dart', 'r') as f:
    content = f.read()

# 1. Add Timer, selectedDate, and expanded map
repl1 = """
import 'dart:async';
import '../constants/app_colors.dart';
"""
content = content.replace("import '../constants/app_colors.dart';", repl1)

repl2 = """
  MatchFilterMode _filterMode = MatchFilterMode.byDate;
  DateTime _selectedDate = DateTime.now();
  Timer? _liveTimer;
  final Map<int, bool> _isCompetitionExpanded = {};
"""
content = re.sub(r'MatchFilterMode _filterMode = MatchFilterMode.byDate;', repl2, content)

# 2. Update initState and dispose
repl3 = """
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAllMatches();
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchLiveUpdates());
  }

  Future<void> _fetchLiveUpdates() async {
    if (_loading || !_dataLoaded) return;
    try {
      final now = DateTime.now();
      final todayStr = _formatDate(now);
      if (_formatDate(_selectedDate) != todayStr) return; // Only update if today is selected

      final toFetch = CompetitionsCatalog.all;
      final results = <LiveMatch>[];
      const batchSize = 5; // Faster batch
      
      for (var i = 0; i < toFetch.length; i += batchSize) {
        final batchEnd = i + batchSize > toFetch.length ? toFetch.length : i + batchSize;
        final batch = toFetch.sublist(i, batchEnd);
        final futures = batch.map((comp) =>
            Scores365Service.fetchMatchesByCompetition(
              competitionId: comp.id,
              startDate: todayStr,
              endDate: todayStr,
              competitionName: comp.name,
            ).catchError((_) => <LiveMatch>[]));
        final batchResults = await Future.wait(futures);
        for (final list in batchResults) {
          results.addAll(list);
        }
      }

      if (mounted) {
        setState(() {
          // Merge updates silently
          for (final newMatch in results) {
            final index = _allMatches.indexWhere((m) => m.id == newMatch.id);
            if (index != -1) {
              _allMatches[index] = newMatch;
            } else {
              _allMatches.add(newMatch);
            }
          }
        });
      }
    } catch (_) {}
  }
"""
content = re.sub(r'@override\s*void initState\(\) \{[\s\S]*?super\.initState\(\);\s*_scrollController\.addListener\(_onScroll\);\s*_loadAllMatches\(\);\s*\}', repl3, content)

repl4 = """
  @override
  void dispose() {
    _liveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
"""
content = re.sub(r'@override\s*void dispose\(\) \{[\s\S]*?_scrollController\.removeListener\(_onScroll\);', repl4, content)

# 3. Update _loadAllMatches to fetch only for _selectedDate
repl5 = """
    final start = _formatDate(_selectedDate);
    final end = _formatDate(_selectedDate);
    final toFetch = CompetitionsCatalog.all;
"""
content = re.sub(r"final start = _formatDate\(now\.subtract\(const Duration\(days: 30\)\)\);\s*final end = _formatDate\(now\.add\(const Duration\(days: 30\)\)\);\s*final toFetch = CompetitionsCatalog\.all;", repl5, content)

# 4. Update Filter Bar to include horizontal date picker
repl6 = """
  Widget _buildFilterBar(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1A242D) : Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
                                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                                  width: _filterMode == mode ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                _modeLabel(mode),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _filterMode == mode ? FontWeight.w700 : FontWeight.w400,
                                  color: _filterMode == mode ? _gold : (isDark ? Colors.white54 : Colors.grey),
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
            if (_filterMode == MatchFilterMode.byDate) _buildDatePicker(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Generate dates: 7 days before, 7 days after
    final dates = List.generate(15, (index) => today.subtract(Duration(days: 7 - index)));
    
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;
          
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() => _selectedDate = date);
                _loadAllMatches();
              }
            },
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _gold : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayLabelShort(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.black87 : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _dayLabelShort(DateTime day) {
    const weekdays = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return weekdays[day.weekday - 1];
  }
"""
content = re.sub(r'Widget _buildFilterBar\(bool isDark\) \{[\s\S]*?Widget _buildMatchList', repl6 + '\n\n  Widget _buildMatchList', content)

# 5. Make competitions collapsible by modifying _buildByDateView
repl7 = """
  Widget _buildByDateView(bool isDark) {
    final grouped = _groupedByDayAndComp;
    final days = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    return RefreshIndicator(
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
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final compEntry in compGroups.entries) ...[
                _CompetitionGroupHeader(
                  name: compEntry.key,
                  isDark: isDark,
                  competitionId: compEntry.value.first.competitionId,
                  matchCount: compEntry.value.length,
                  isExpanded: _isCompetitionExpanded[compEntry.value.first.competitionId ?? 0] ?? true,
                  onToggle: () {
                    final cid = compEntry.value.first.competitionId ?? 0;
                    setState(() {
                      _isCompetitionExpanded[cid] = !(_isCompetitionExpanded[cid] ?? true);
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: (_isCompetitionExpanded[compEntry.value.first.competitionId ?? 0] ?? true)
                      ? Column(
                          children: compEntry.value.map((m) => _MatchCard(
                            match: m,
                            isDark: isDark,
                            onTap: () => _openMatch(m),
                          )).toList(),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
"""
content = re.sub(r'Widget _buildByDateView\(bool isDark\) \{[\s\S]*?Widget _buildSimpleMatchList', repl7 + '\n\n  Widget _buildSimpleMatchList', content)

# 6. Update _CompetitionGroupHeader
repl8 = """
class _CompetitionGroupHeader extends StatelessWidget {
  const _CompetitionGroupHeader({
    required this.name,
    required this.isDark,
    this.competitionId,
    this.onTap,
    this.matchCount,
    this.isExpanded = true,
    this.onToggle,
  });
  final String name;
  final bool isDark;
  final int? competitionId;
  final VoidCallback? onTap;
  final int? matchCount;
  final bool isExpanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final comp = competitionId != null
        ? CompetitionsCatalog.findById(competitionId!)
        : null;

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
          AnimatedRotation(
            turns: isExpanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: '$name, ${matchCount ?? 0} matchs.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle, // Toggle instead of navigation
          child: child,
        ),
      ),
    );
  }
}
"""
content = re.sub(r'class _CompetitionGroupHeader extends StatelessWidget \{[\s\S]*?class _MatchCard extends StatelessWidget', repl8 + '\n\nclass _MatchCard extends StatelessWidget', content)

with open('lib/screens/matches_tab.dart', 'w') as f:
    f.write(content)

