class StandingTeam {
  final int teamId;
  final int rank;
  final String teamName;
  final String teamLogo;
  final int points;
  final int played;
  final int goalsDiff;
  final bool? isQualified;
  final bool? toQualify;

  StandingTeam({
    required this.teamId,
    required this.rank,
    required this.teamName,
    required this.teamLogo,
    required this.points,
    required this.played,
    required this.goalsDiff,
    this.isQualified,
    this.toQualify,
  });

  factory StandingTeam.fromApi(Map<String, dynamic> json) {
    return StandingTeam(
      teamId: json['team']?['id'] ?? 0,
      rank: json['rank'] ?? 0,
      teamName: json['team']?['name'] ?? 'Team',
      teamLogo: json['team']?['logo'] ?? '',
      points: json['points'] ?? 0,
      played: json['all']?['played'] ?? 0,
      goalsDiff: json['goalsDiff'] ?? 0,
      isQualified: json['isQualified'],
      toQualify: json['toQualify'],
    );
  }
}

class GroupStanding {
  final String groupName;
  final List<StandingTeam> teams;

  GroupStanding({required this.groupName, required this.teams});
}
