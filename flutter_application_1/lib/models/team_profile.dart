import 'team_player.dart';

class TeamProfile {
  final int id;
  final String name;
  final String shortName;
  final String code;
  final String? logoUrl;
  final String venue;
  final String foundedLabel;
  final TeamCoach? coach;
  final List<TeamPlayer> players;

  const TeamProfile({
    required this.id,
    required this.name,
    required this.shortName,
    required this.code,
    this.logoUrl,
    required this.venue,
    required this.foundedLabel,
    this.coach,
    required this.players,
  });

  factory TeamProfile.fromApi(
    Map<String, dynamic> json,
    int teamId,
    String teamName,
  ) {
    final List playerList = json['response'] as List? ?? [];
    final coachData = json['coach'] ?? {};

    return TeamProfile(
      id: teamId,
      name: teamName,
      shortName: teamName,
      code: "",
      logoUrl: "https://media.api-sports.io/football/teams/$teamId.png",
      venue: "",
      foundedLabel: "",
      players: playerList.map((p) => TeamPlayer.fromApi(p, teamName)).toList(),
      coach: coachData.isNotEmpty ? TeamCoach.fromApi(coachData) : null,
    );
  }
}
