import re

with open('lib/services/scores365_service.dart', 'r') as f:
    content = f.read()

new_func = """  static Future<List<LiveMatch>> fetchLiveMatches() async {
    // 1. Fetch EVERYTHING for soccer
    String endpoint = 'games/current/?$baseParams&sportId=1';
    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];

    final games = data['games'] as List;
    final validIds = CompetitionsCatalog.all.map((c) => c.id).toSet();
    
    final Map<String, LiveMatch> uniqueMatches = {};

    for (final g in games) {
      final statusGroup = g['statusGroup'];
      // statusGroup 3 is live!
      if (statusGroup == 3) {
        final m = _mapToLiveMatch(g);
        final trueCompId = m.competitionId ?? 0;
        
        if (!validIds.contains(trueCompId)) continue;
        
        final catalogComp = CompetitionsCatalog.findById(trueCompId);
        final apiName = (g is Map) ? g['competitionDisplayName']?.toString() ?? '' : '';
        final resolvedName = catalogComp?.displayName ?? (apiName.isNotEmpty ? apiName : (m.competitionName ?? ''));
        
        final resolved = m.copyWithCompetitionInfo(
          competitionId: trueCompId,
          competitionName: resolvedName,
        );
        uniqueMatches[resolved.id] = resolved;
      }
    }
    return uniqueMatches.values.toList();
  }"""

content = re.sub(
    r'  static Future<List<LiveMatch>> fetchLiveMatches\(\) async \{.*?(?=  /// Fetch les matchs d\'une)',
    new_func + '\n\n',
    content,
    flags=re.DOTALL
)

with open('lib/services/scores365_service.dart', 'w') as f:
    f.write(content)
