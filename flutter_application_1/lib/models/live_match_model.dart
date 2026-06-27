class LiveMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String homeLogo;
  final String awayLogo;
  final String time;
  final String targetStreamUrl;

  const LiveMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogo,
    required this.awayLogo,
    required this.time,
    required this.targetStreamUrl,
  });

  factory LiveMatch.fromJson(Map<String, dynamic> json) {
    return LiveMatch(
      id: _asString(json['id']),
      homeTeam: _asString(json['homeTeam']),
      awayTeam: _asString(json['awayTeam']),
      homeLogo: _asString(json['homeLogo']),
      awayLogo: _asString(json['awayLogo']),
      time: _asString(json['time']),
      targetStreamUrl: _asString(json['targetStreamUrl']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'homeLogo': homeLogo,
      'awayLogo': awayLogo,
      'time': time,
      'targetStreamUrl': targetStreamUrl,
    };
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';
}
