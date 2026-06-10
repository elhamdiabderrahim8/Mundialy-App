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

    // --- Position ---
    // SofaScore sends single letters (G, D, M, F)
    // API-SPORTS sends full words via statistics[0].games.position
    String pos = '';
    int? num;
    if (json['statistics'] != null && (json['statistics'] as List).isNotEmpty) {
      final stats = json['statistics'][0];
      pos = stats['games']?['position'] ?? '';
      num = stats['games']?['number'];
    }
    if (pos.isEmpty) {
      pos = player['position'] ?? json['position'] ?? '';
    }

    // --- Shirt number ---
    // SofaScore uses 'shirtNumber', API-SPORTS uses 'number'
    num ??= player['shirtNumber'] ?? json['shirtNumber'] ?? json['number'];

    // --- Age ---
    // SofaScore provides dateOfBirthTimestamp (unix seconds)
    String ageLabel = '';
    if (player['age'] != null) {
      ageLabel = player['age'].toString();
    } else {
      final dob =
          player['dateOfBirthTimestamp'] ?? json['dateOfBirthTimestamp'];
      if (dob != null && dob is int) {
        final birthDate = DateTime.fromMillisecondsSinceEpoch(dob * 1000);
        final now = DateTime.now();
        int age = now.year - birthDate.year;
        if (now.month < birthDate.month ||
            (now.month == birthDate.month && now.day < birthDate.day)) {
          age--;
        }
        ageLabel = '$age ans';
      }
    }

    // --- Height ---
    final rawHeight = player['height'] ?? json['height'];
    String? height;
    if (rawHeight != null) {
      height = rawHeight is int ? '$rawHeight cm' : rawHeight.toString();
    }

    return TeamPlayer(
      id: player['id'] ?? 0,
      name: player['name'] ?? '',
      position: pos,
      shirtNumber: num,
      photoUrl: player['photo'],
      nationality: nationality,
      nationalityCode: resolveCountryCode(nationality),
      ageLabel: ageLabel,
      height: height,
      weight: player['weight']?.toString(),
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
