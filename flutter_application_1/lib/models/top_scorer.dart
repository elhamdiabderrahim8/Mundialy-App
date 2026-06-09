class TopScorer {
  final int rank;
  final int playerId;
  final String playerName;
  final String playerPhoto;
  final int teamId;
  final String teamName;
  final String teamLogo;
  final int goals;
  final int assists;

  TopScorer({
    required this.rank,
    this.playerId = 0,
    required this.playerName,
    required this.playerPhoto,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.goals,
    required this.assists,
  });

  factory TopScorer.fromApi(Map<String, dynamic> json, int rank) {
    final player = json['player'] as Map<String, dynamic>? ?? {};
    final statistics =
        (json['statistics'] != null && (json['statistics'] as List).isNotEmpty)
        ? json['statistics'][0] as Map<String, dynamic>
        : <String, dynamic>{};

    // Format API-Sports / assets 2022
    final team = statistics['team'] as Map<String, dynamic>? ?? {};
    final goalsData = statistics['goals'] as Map<String, dynamic>? ?? {};

    // Format SofaScore 2026 (plat)
    final flatTeam = json['team'] as Map<String, dynamic>? ?? {};
    final flatStats = json['statistics'] is Map<String, dynamic>
        ? json['statistics'] as Map<String, dynamic>
        : <String, dynamic>{};

    final resolvedTeam = team.isNotEmpty ? team : flatTeam;
    final resolvedGoals = goalsData.isNotEmpty
        ? goalsData
        : {
            'total': json['goals'] ?? flatStats['goals'] ?? 0,
            'assists': json['assists'] ?? flatStats['assists'] ?? 0,
          };

    final playerId = player['id'] is int
        ? player['id'] as int
        : int.tryParse('${player['id']}') ?? 0;

    return TopScorer(
      rank: rank,
      playerId: playerId,
      playerName: player['name']?.toString() ?? 'Inconnu',
      playerPhoto: player['photo']?.toString() ?? '',
      teamId: resolvedTeam['id'] is int
          ? resolvedTeam['id'] as int
          : int.tryParse('${resolvedTeam['id']}') ?? 0,
      teamName: resolvedTeam['name']?.toString() ?? 'Équipe',
      teamLogo: resolvedTeam['logo']?.toString() ?? '',
      goals: resolvedGoals['total'] is int
          ? resolvedGoals['total'] as int
          : int.tryParse('${resolvedGoals['total']}') ?? 0,
      assists: resolvedGoals['assists'] is int
          ? resolvedGoals['assists'] as int
          : int.tryParse('${resolvedGoals['assists']}') ?? 0,
    );
  }
}
