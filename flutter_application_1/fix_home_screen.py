import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Replace _loadAllMatches inside home_screen.dart
new_load_all_matches = """  Future<void> _loadAllMatches() async {
    if (_isLoadingAllMatches || _allMatchesLoaded) return;
    setState(() {
      _isLoadingAllMatches = true;
    });

    final toFetch = CompetitionsCatalog.all;

    try {
      final allCompIds = toFetch.map((c) => c.id).toList();
      
      // Utilisation du endpoint optimisé CDN (ultra-rapide) !
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
      );

      var all = results;
      all.sort((a, b) =>
          (b.dateTime ?? DateTime(0)).compareTo(a.dateTime ?? DateTime(0)));

      if (mounted) {
        debugPrint("DEBUG: Fetched ${all.length} matches across all competitions.");
        setState(() {
          _allMatches = all;
          _isLoadingAllMatches = false;
          _allMatchesLoaded = true;
        });
        // Dès que la liste Matchs est prête, on démarre le polling scores
        _startSilentScoreRefresh();
      }
    } catch (e) {
      debugPrint("DEBUG: Error in _loadAllMatches: $e");
      if (mounted) {
        setState(() {
          _isLoadingAllMatches = false;
        });
      }
    }
  }"""

# Find the start and end of _loadAllMatches in home_screen.dart
content = re.sub(
    r'  Future<void> _loadAllMatches\(\) async \{.*?(?=  @override\n  void initState\(\) \{)',
    new_load_all_matches + '\n\n',
    content,
    flags=re.DOTALL
)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
