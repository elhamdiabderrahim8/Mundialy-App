class TopScorer {
  int rank;
  final int playerId;
  final String playerName;
  final String teamName;
  final String teamCode;
  final int goals;
  final int matches;
  final int assists;
  final int yellowCards;
  final int redCards;
  final int? jerseyNum;
  final String? photoUrl;

  TopScorer({
    this.rank = 0,
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.teamCode,
    required this.goals,
    required this.matches,
    required this.assists,
    this.yellowCards = 0,
    this.redCards = 0,
    this.jerseyNum,
    this.photoUrl,
  });

  /// Build the best photo URL for this scorer
  String? get bestPhotoUrl {
    if (photoUrl != null && photoUrl!.isNotEmpty) return photoUrl;
    if (playerId > 0) {
      return 'https://imagecache.365scores.com/image/upload/f_auto,q_auto,c_fill,w_300,h_300/v1/Athletes/$playerId';
    }
    return null;
  }

  // for 365Scores API
  factory TopScorer.fromJson(Map<String, dynamic> json) {
    final id = json['athleteId'] ?? json['id'] ?? 0;
    return TopScorer(
      playerId: id,
      playerName: json['athleteName'] ?? json['name'] ?? '',
      teamName: json['competitorName'] ?? '',
      teamCode: json['competitorId']?.toString() ?? '',
      jerseyNum: json['jerseyNum'],
      goals: json['value']?.toInt() ?? 0,
      matches: json['games'] ?? 0,
      assists: json['assists'] ?? 0,
      photoUrl: 'https://imagecache.365scores.com/image/upload/f_auto,q_auto,c_fill,w_300,h_300/v1/Athletes/$id',
    );
  }

  // for local assets (2022) & multi-format support
  factory TopScorer.fromApi(Map<String, dynamic> json, int rank) {
    final pl = json['player'] ?? {};
    final statsList = json['statistics'] as List?;

    if (statsList != null && statsList.isNotEmpty) {
      // Format API-Sports (nested)
      final stat = statsList[0];
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
        photoUrl: pl['photo'],
      );
    } else {
      // Format SofaScore/Direct (flat)
      final t = json['team'] ?? {};
      return TopScorer(
        rank: rank,
        playerId: pl['id'] ?? 0,
        playerName: pl['name'] ?? '',
        teamName: t['name'] ?? '',
        teamCode: t['id']?.toString() ?? '',
        goals: json['goals'] ?? 0,
        matches: json['played'] ?? 0,
        assists: json['assists'] ?? 0,
        yellowCards: json['yellowCards'] ?? 0,
        redCards: json['redCards'] ?? 0,
      );
    }
  }
}
