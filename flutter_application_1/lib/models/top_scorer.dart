class TopScorer {
  final int rank;
  final String playerName;
  final String playerPhoto;
  final int teamId;
  final String teamName;
  final String teamLogo;
  final int goals;
  final int assists;

  TopScorer({
    required this.rank,
    required this.playerName,
    required this.playerPhoto,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.goals,
    required this.assists,
  });

  factory TopScorer.fromApi(Map<String, dynamic> json, int rank) {
    final player = json['player'] ?? {};
    final statistics = (json['statistics'] != null && (json['statistics'] as List).isNotEmpty) 
        ? json['statistics'][0] 
        : {};
    
    final team = statistics['team'] ?? {};
    final goalsData = statistics['goals'] ?? {};

    return TopScorer(
      rank: rank,
      playerName: player['name'] ?? 'Inconnu',
      playerPhoto: player['photo'] ?? '',
      teamId: team['id'] ?? 0,
      teamName: team['name'] ?? 'Équipe',
      teamLogo: team['logo'] ?? '',
      goals: goalsData['total'] ?? 0,
      assists: goalsData['assists'] ?? 0,
    );
  }
}
