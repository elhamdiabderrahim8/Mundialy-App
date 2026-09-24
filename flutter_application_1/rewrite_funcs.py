import re

with open('lib/screens/matches_tab.dart', 'r') as f:
    content = f.read()

# I will replace from `Future<void> _fetchLiveUpdates` up to `String _formatDate`

new_funcs = """  Future<void> _fetchLiveUpdates() async {
    if (_loading || !_dataLoaded) return;
    try {
      final now = DateTime.now();
      final todayStr = _formatDate(now);
      if (_formatDate(_selectedDate) != todayStr) return; // Only update if today is selected

      final toFetch = CompetitionsCatalog.all;
      final allCompIds = toFetch.map((c) => c.id!).toList();
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
        startDate: todayStr,
        endDate: todayStr,
      );

      if (mounted) {
        setState(() {
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
      
      ApiService.updateOverlayIfActive(results);
    } catch (_) {}
  }

  Future<void> _loadAllMatches() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _loadedComps = 0;
      _jumpedToToday = false;
    });

    final start = _formatDate(_selectedDate);
    final end = _formatDate(_selectedDate);
    final toFetch = CompetitionsCatalog.all;

    try {
      final allCompIds = toFetch.map((c) => c.id!).toList();
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
        startDate: start,
        endDate: end,
      );
      
      if (mounted) {
        setState(() => _loadedComps = toFetch.length);
      }

      results.sort((a, b) =>
          (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)));

      if (mounted) {
        setState(() {
          _allMatches = results;
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

  String _formatDate"""

content = re.sub(r'  Future<void> _fetchLiveUpdates\(\) async \{.*?\n  String _formatDate', new_funcs, content, flags=re.DOTALL)

with open('lib/screens/matches_tab.dart', 'w') as f:
    f.write(content)
