import re

with open('lib/services/scores365_service.dart', 'r') as f:
    content = f.read()

restored = """  static Future<List<LiveMatch>> fetchFixtures(int year) async {
    String endpoint = 'games/?$baseParams&competitions=$wcCompetitionId';
    if (year == 2026) {
      endpoint += '&startDate=11/06/2026&endDate=19/07/2026';
    } else if (year == 2022) {
      endpoint += '&seasonNum=24';
    }
    
    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];

    final games = data['games'] as List;
    return games.map((g) => _mapToLiveMatch(g)).toList();
  }

  // ============================================================
  //  MÉTHODES GÉNÉRIQUES — Multi-compétitions
  // ============================================================

  /// Vérité de la compétition d'un match : l'API peut servir, pour une
  /// compétition demandée, des matchs d'une AUTRE compétition (ex: 167 CAN
  /// → matchs 588 qualifs tant que la saison CAN 2027 n'a pas démarré).
  /// On garde l'ID réel du match (repli : compétition demandée) pour un
  /// étiquetage et une navigation honnêtes.
  static LiveMatch _withTrueCompetitionInfo(
    LiveMatch m,
    dynamic g, {
    required int requestedId,
    String? requestedName,
  }) {
    final trueId = m.competitionId ?? requestedId;
    final apiName =
        (g is Map) ? g['competitionDisplayName']?.toString() ?? '' : '';
    String name;
    if (trueId == requestedId) {
      name = (requestedName != null && requestedName.isNotEmpty)
          ? requestedName
          : (CompetitionsCatalog.findById(trueId)?.displayName ??
              (apiName.isNotEmpty ? apiName : (m.competitionName ?? '')));
    } else {
      name = CompetitionsCatalog.findById(trueId)?.displayName ??
          (apiName.isNotEmpty ? apiName : (m.competitionName ?? ''));
      if (name.isEmpty && requestedName != null) name = requestedName!;
    }
    return m.copyWithCompetitionInfo(
      competitionId: trueId,
      competitionName: name,
    );
  }
"""

content = content.replace('  /// Fetch les matchs d\'une compétition quelconque sur une plage de dates.', restored + '\n  /// Fetch les matchs d\'une compétition quelconque sur une plage de dates.')

with open('lib/services/scores365_service.dart', 'w') as f:
    f.write(content)
