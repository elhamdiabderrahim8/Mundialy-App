class TopScorer {
  int rank;
  final int playerId;
  final String playerName;
  final String teamName;
  final String teamCode;
  final int goals;
  final int matches;
  final int assists;
  final int? jerseyNum;

  TopScorer({
    this.rank = 0,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.teamCode,
    required this.goals,
    required this.matches,
    required this.assists,
    this.jerseyNum,
  });

  // for 365Scores API
  factory TopScorer.fromJson(Map<String, dynamic> json) {
    return TopScorer(
      playerId: json['athleteId'] ?? json['id'] ?? 0,
      playerName: json['athleteName'] ?? json['name'] ?? '',
      teamName: json['competitorName'] ?? '',
      teamCode: json['competitorId']?.toString() ?? '',
      jerseyNum: json['jerseyNum'],
      goals: json['value']?.toInt() ?? 0,
      matches: json['games'] ?? 0,
      assists: json['assists'] ?? 0,
    );
  }

  // for local assets (2022)
  factory TopScorer.fromApi(Map<String, dynamic> json, int rank) {
    final pl = json['player'] ?? {};
    final stat = (json['statistics'] as List?)?.isNotEmpty == true
        ? json['statistics'][0]
        : {};
    final t = stat['team'] ?? {};
    final g = stat['goals'] ?? {};

    return TopScorer(
      rank: rank,
      playerId: pl['id'] ?? 0,
      playerName: pl['name'] ?? '',
      teamName: t['name'] ?? '',
      teamCode: t['id']?.toString() ?? '',
      goals: g['total'] ?? 0,
      matches: 0,
      assists: g['assists'] ?? 0,
    );
  }
}
