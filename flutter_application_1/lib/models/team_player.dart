import '../utils/country_flags.dart';

class TeamPlayer {
  final int id;
  final String name;
  final String position;
  final int? shirtNumber;
  final String? photoUrl;
  final String nationality;
  final String nationalityCode;
  final String ageLabel;
  final String? height;
  final String? weight;
  final bool injured;

  const TeamPlayer({
    required this.id,
    required this.name,
    required this.position,
    this.shirtNumber,
    this.photoUrl,
    required this.nationality,
    required this.nationalityCode,
    required this.ageLabel,
    this.height,
    this.weight,
    this.injured = false,
  });

  factory TeamPlayer.fromApi(
    Map<String, dynamic> json,
    String teamNationality,
  ) {
    final player = json['player'] ?? json;
    final nationality = player['nationality'] ?? teamNationality;

    // API-SPORTS renvoie souvent la position dans 'statistics[0].games.position'
    String pos = "";
    int? num;
    if (json['statistics'] != null && (json['statistics'] as List).isNotEmpty) {
      final stats = json['statistics'][0];
      pos = stats['games']?['position'] ?? "";
      num = stats['games']?['number'];
    }

    return TeamPlayer(
      id: player['id'] ?? 0,
      name: player['name'] ?? '',
      position: pos.isNotEmpty ? pos : (json['position'] ?? ''),
      shirtNumber: num ?? json['number'],
      photoUrl: player['photo'],
      nationality: nationality,
      nationalityCode: resolveCountryCode(nationality),
      ageLabel: player['age']?.toString() ?? '',
      height: player['height'],
      weight: player['weight'],
      injured: player['injured'] ?? false,
    );
  }
}

class TeamCoach {
  final int id;
  final String name;
  final String? photoUrl;
  final String nationality;
  final String nationalityCode;
  final String? age;

  const TeamCoach({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.nationality,
    required this.nationalityCode,
    this.age,
  });

  factory TeamCoach.fromApi(Map<String, dynamic> json) {
    return TeamCoach(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      photoUrl: json['photo'],
      nationality: json['nationality'] ?? '',
      nationalityCode: resolveCountryCode(json['nationality'] ?? ''),
      age: json['age']?.toString(),
    );
  }
}
