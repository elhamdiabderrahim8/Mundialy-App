import re

with open('lib/screens/matches_tab.dart', 'r') as f:
    content = f.read()

# Replace _loadAllMatches fetch loop
repl1 = """
      final allCompIds = toFetch.map((c) => c.id).toList();
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
        startDate: start,
        endDate: end,
      );
      
      if (mounted) {
        setState(() => _loadedComps = toFetch.length);
      }
"""
content = re.sub(
    r'      final results = <LiveMatch>\[\];[\s\S]*?if \(mounted\) \{\n\s*setState\(\(\) => _loadedComps = batchEnd\);\n\s*\}[\s\S]*?\}\n',
    repl1,
    content
)

# Replace _fetchLiveUpdates fetch loop
repl2 = """
      final allCompIds = toFetch.map((c) => c.id).toList();
      final results = await Scores365Service.fetchMatchesForMultipleCompetitions(
        competitionIds: allCompIds,
        startDate: todayStr,
        endDate: todayStr,
      );
"""
content = re.sub(
    r'      final results = <LiveMatch>\[\];\n\s*const batchSize = 5; // Faster batch[\s\S]*?\}\n\s*\}',
    repl2,
    content
)

with open('lib/screens/matches_tab.dart', 'w') as f:
    f.write(content)
