import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

new_timer = """  void _startSilentScoreRefresh() {
    _silentRefreshTimer?.cancel();
    if (_selectedYear == 2022) return;
    
    // Polling optimisé toutes les 25 secondes
    _silentRefreshTimer = java_timer.Timer.periodic(
      const Duration(seconds: 25),
      (_) async {
        if (!mounted || _scorePollBusy) return;
        _scorePollBusy = true;
        try {
          final toFetch = CompetitionsCatalog.all.map((c) => c.id).toList();
          final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
            competitionIds: toFetch,
          );
          
          if (mounted && results.isNotEmpty) {
            setState(() {
              // Mettre à jour les matchs avec les nouvelles données live
              for (final newMatch in results) {
                final index = _allMatches.indexWhere((m) => m.id == newMatch.id);
                if (index != -1) {
                  _allMatches[index] = newMatch;
                }
              }
            });
            
            if (await FlutterOverlayWindow.isActive()) {
              // Mise à jour simplifiée de l'overlay avec le match actif
              final liveM = _allMatches.firstWhere((m) => m.isLive, orElse: () => _allMatches.first);
              FlutterOverlayWindow.shareData({
                'home': liveM.homeTeam,
                'away': liveM.awayTeam,
                'score': '${liveM.scoreHome ?? 0} - ${liveM.scoreAway ?? 0}',
              });
            }
          }
        } catch (e) {
          debugPrint('Silent poll error: $e');
        } finally {
          _scorePollBusy = false;
        }
      },
    );
  }"""

content = re.sub(
    r'  void _startSilentScoreRefresh\(\) \{.*?(?=  // ignore: unused_element\n  Future<void> _fetchLiveMode)',
    new_timer + '\n\n',
    content,
    flags=re.DOTALL
)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
