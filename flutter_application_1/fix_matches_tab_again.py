import re

with open('lib/screens/matches_tab.dart', 'r') as f:
    content = f.read()

# I need to properly reconstruct _loadAllMatches and _fetchLiveUpdates
content = re.sub(
    r'Future<void> _fetchLiveUpdates\(\) async \{.*?\n\s*if \(mounted\) \{',
    r'''Future<void> _fetchLiveUpdates() async {
    if (_loading || !_dataLoaded) return;
    try {
      final now = DateTime.now();
      final todayStr = _formatDate(now);
      if (_formatDate(_selectedDate) != todayStr) return; // Only update if today is selected

      final toFetch = CompetitionsCatalog.all;
      final allCompIds = toFetch.map((c) => c.id).toList();
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
        startDate: todayStr,
        endDate: todayStr,
      );

      if (mounted) {''',
    content,
    flags=re.DOTALL
)

content = re.sub(
    r'Future<void> _loadAllMatches\(\) async \{.*?\n\s*final all = results;',
    r'''Future<void> _loadAllMatches() async {
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
      final allCompIds = toFetch.map((c) => c.id).toList();
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
        startDate: start,
        endDate: end,
      );
      
      if (mounted) {
        setState(() => _loadedComps = toFetch.length);
      }

      final all = results;''',
    content,
    flags=re.DOTALL
)

with open('lib/screens/matches_tab.dart', 'w') as f:
    f.write(content)
