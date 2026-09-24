import re

with open('lib/services/scores365_service.dart', 'r') as f:
    content = f.read()

new_method = """
  static Future<List<LiveMatch>> fetchMatchesForMultipleCompetitions({
    required List<int> competitionIds,
    String? startDate,
    String? endDate,
  }) async {
    final idsStr = competitionIds.join(',');
    String endpoint = 'games/current/?$baseParams&competitions=$idsStr';
    if (startDate != null && endDate != null) {
      endpoint += '&startDate=$startDate&endDate=$endDate';
    }
    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];
    
    final games = data['games'] as List;
    return games.map((g) => _mapToLiveMatch(g)).toList();
  }
"""

content = re.sub(r'(static Future<List<LiveMatch>> fetchMatchesByCompetition)', new_method + r'\n  \1', content)

with open('lib/services/scores365_service.dart', 'w') as f:
    f.write(content)
