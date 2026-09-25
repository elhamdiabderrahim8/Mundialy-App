import re

with open('lib/services/scores365_service.dart', 'r') as f:
    content = f.read()

new_func = """  static Future<List<LiveMatch>> fetchMatchesForMultipleCompetitions({
    required List<int> competitionIds,
    String? startDate,
    String? endDate,
  }) async {
    // 1. Déterminer si on demande la date d'aujourd'hui
    final now = DateTime.now();
    // On uniformise le format pour correspondre à celui envoyé par matches_tab.dart (dd/MM/yyyy)
    final todayStr1 = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final todayStr2 = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
    
    final isToday = (startDate == null && endDate == null) || 
                    (startDate == todayStr1) || (startDate == todayStr2);

    // 2. Si c'est aujourd'hui, utiliser 'allscores' pur (cache CDN ultra-rapide ~100ms, temps réel garanti)
    // Sinon, utiliser 'games/' avec les dates pour l'historique
    String endpoint = isToday 
        ? 'games/allscores/?$baseParams&sportId=1'
        : 'games/?$baseParams&sportId=1&startDate=$startDate&endDate=$endDate';

    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];
    
    final games = data['games'] as List;
    final validIds = competitionIds.toSet();
    
    // 3. Client-side filtering & deduplication
    final Map<String, LiveMatch> uniqueMatches = {};
    for (final g in games) {
      final m = _mapToLiveMatch(g);
      final trueCompId = m.competitionId ?? 0;
      
      // ONLY keep matches that belong to our National Catalog!
      if (!validIds.contains(trueCompId)) continue;
      
      final catalogComp = CompetitionsCatalog.findById(trueCompId);
      final apiName = (g is Map)
          ? g['competitionDisplayName']?.toString() ?? ''
          : '';
      final resolvedName = catalogComp?.displayName ??
          (apiName.isNotEmpty ? apiName : (m.competitionName ?? ''));
      
      final resolved = m.copyWithCompetitionInfo(
        competitionId: trueCompId,
        competitionName: resolvedName,
      );
      uniqueMatches[resolved.id] = resolved;
    }
    
    return uniqueMatches.values.toList();
  }"""

content = re.sub(
    r'  static Future<List<LiveMatch>> fetchMatchesForMultipleCompetitions\(\{.*?\n    return uniqueMatches\.values\.toList\(\);\n  \}',
    new_func,
    content,
    flags=re.DOTALL
)

with open('lib/services/scores365_service.dart', 'w') as f:
    f.write(content)
