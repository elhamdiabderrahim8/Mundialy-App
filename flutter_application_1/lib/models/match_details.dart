class MatchDetails {
  const MatchDetails({
    required this.matchId,
    required this.overview,
    required this.summary,
    required this.stats,
    required this.homeLineup,
    required this.awayLineup,
  });

  final String matchId;
  final MatchOverview overview;
  final MatchSummary summary;
  final List<MatchStat> stats;
  final TeamLineup homeLineup;
  final TeamLineup awayLineup;

  factory MatchDetails.fromApi(Map<String, dynamic> json) {
    final fixture = json['fixture'] ?? {};
    final league = json['league'] ?? {};
    final teams = json['teams'] ?? {};
    final goals = json['goals'] ?? {};
    final score = json['score'] ?? {};
    
    return MatchDetails(
      matchId: fixture['id']?.toString() ?? '0',
      overview: MatchOverview(
        title: '${teams['home']?['name']} vs ${teams['away']?['name']}',
        homeTeam: teams['home']?['name'] ?? 'Home',
        homeCode: teams['home']?['id']?.toString() ?? 'H', // Use ID as code placeholder
        homeLogoUrl: teams['home']?['logo'],
        awayTeam: teams['away']?['name'] ?? 'Away',
        awayCode: teams['away']?['id']?.toString() ?? 'A',
        awayLogoUrl: teams['away']?['logo'],
        scoreHome: goals['home'] ?? 0,
        scoreAway: goals['away'] ?? 0,
        penaltyHome: score['penalty']?['home'],
        penaltyAway: score['penalty']?['away'],
        status: fixture['status']?['long'] ?? 'Unknown',
        minute: fixture['status']?['elapsed']?.toString() ?? '0',
      ),
      summary: MatchSummary(
        events: (json['events'] as List? ?? []).map((e) => MatchEvent.fromApi(e)).toList(),
        referee: MatchOfficial(name: fixture['referee'] ?? 'Arbitre', nationality: ''),
        venue: MatchVenue(
          stadium: fixture['venue']?['name'] ?? 'Stadium',
          capacity: '',
          city: fixture['venue']?['city'] ?? 'City',
        ),
        startTime: fixture['date'] ?? '',
      ),
      stats: (json['statistics'] as List? ?? []).map((s) => MatchStat.fromApi(s)).toList(),
      homeLineup: TeamLineup.fromApi(json['lineups'] is List && (json['lineups'] as List).isNotEmpty ? json['lineups'][0] : {}),
      awayLineup: TeamLineup.fromApi(json['lineups'] is List && (json['lineups'] as List).length > 1 ? json['lineups'][1] : {}),
    );
  }
}

class MatchOverview {
  const MatchOverview({
    required this.title,
    required this.homeTeam,
    required this.homeCode,
    this.homeLogoUrl,
    required this.awayTeam,
    required this.awayCode,
    this.awayLogoUrl,
    required this.scoreHome,
    required this.scoreAway,
    this.penaltyHome,
    this.penaltyAway,
    required this.status,
    required this.minute,
  });

  final String title;
  final String homeTeam;
  final String homeCode;
  final String? homeLogoUrl;
  final String awayTeam;
  final String awayCode;
  final String? awayLogoUrl;
  final int scoreHome;
  final int scoreAway;
  final int? penaltyHome;
  final int? penaltyAway;
  final String status;
  final String minute;
}

class MatchSummary {
  const MatchSummary({
    required this.events,
    required this.referee,
    required this.venue,
    required this.startTime,
  });

  final List<MatchEvent> events;
  final MatchOfficial referee;
  final MatchVenue venue;
  final String startTime;
}

class MatchEvent {
  const MatchEvent({
    required this.minute,
    required this.title,
    required this.description,
    required this.icon,
    this.teamName = '',
    this.teamCode = '',
    this.teamId,
    this.playerId,
    this.detail = '',
    this.playerIn,
    this.playerInId,
    this.playerOut,
    this.playerOutId,
    this.assistant,
    this.assistantId,
  });

  final String minute;
  final String title;
  final String description;
  final MatchEventIcon icon;
  final String teamName;
  final String teamCode;
  final int? teamId;
  final int? playerId;
  final String detail;
  final String? playerIn;
  final int? playerInId;
  final String? playerOut;
  final int? playerOutId;
  final String? assistant;
  final int? assistantId;

  factory MatchEvent.fromApi(Map<String, dynamic> json) {
    final type = json['type']?.toString().toLowerCase() ?? '';
    final detail = json['detail']?.toString().toLowerCase() ?? '';
    
    MatchEventIcon icon = MatchEventIcon.goal;
    if (type == 'goal') icon = MatchEventIcon.goal;
    else if (type == 'subst') icon = MatchEventIcon.substitution;
    else if (type == 'card' && detail.contains('red')) icon = MatchEventIcon.redCard;
    else if (type == 'card') icon = MatchEventIcon.yellowCard;

    return MatchEvent(
      minute: "${json['time']?['elapsed'] ?? 0}'",
      title: json['type'] ?? 'Action',
      description: json['player']?['name'] ?? 'Joueur',
      icon: icon,
      detail: json['detail'] ?? '',
      teamId: json['team']?['id'],
      teamName: json['team']?['name'] ?? '',
    );
  }
}

enum MatchEventIcon {
  goal,
  substitution,
  varReview,
  offside,
  cancelledGoal,
  yellowCard,
  redCard,
  penaltyMissed,
}

class MatchOfficial {
  const MatchOfficial({
    required this.name,
    required this.nationality,
  });

  final String name;
  final String nationality;
}

class MatchVenue {
  const MatchVenue({
    required this.stadium,
    required this.capacity,
    required this.city,
  });

  final String stadium;
  final String capacity;
  final String city;
}

class MatchStat {
  const MatchStat({
    required this.label,
    required this.homeValue,
    required this.awayValue,
  });

  final String label;
  final double homeValue;
  final double awayValue;

  factory MatchStat.fromApi(Map<String, dynamic> json) {
    return MatchStat(
      label: json['type'] ?? '',
      homeValue: _p(json['home']),
      awayValue: _p(json['away']),
    );
  }
  static double _p(dynamic v) { if (v == null) return 0; if (v is String) return double.tryParse(v.replaceAll('%', '')) ?? 0; return (v as num).toDouble(); }
}

class PlayerSpot {
  const PlayerSpot({
    this.id = 0,
    required this.name,
    required this.role,
    required this.number,
    required this.x,
    required this.y,
    this.rating = '',
    this.isCaptain = false,
    this.goals = 0,
    this.assists = 0,
    this.yellowCards = 0,
    this.redCard = false,
    this.substituted = false,
  });

  final int id;
  final String name;
  final String role;
  final int number;
  final double x;
  final double y;
  final String rating;
  final bool isCaptain;
  final int goals;
  final int assists;
  final int yellowCards;
  final bool redCard;
  final bool substituted;

  factory PlayerSpot.fromApi(Map<String, dynamic> json) {
    final player = json['player'] ?? {};
    return PlayerSpot(
      id: player['id'] ?? 0,
      name: player['name'] ?? '',
      number: player['number'] ?? 0,
      role: player['pos'] ?? '',
      x: 0, y: 0, // Coordinates not directly in API-Sports lineups
    );
  }
}

class TeamLineup {
  const TeamLineup({
    required this.teamName,
    required this.teamCode,
    required this.formation,
    required this.coach,
    required this.players,
    required this.bench,
    required this.kitColor,
  });

  final String teamName;
  final String teamCode;
  final String formation;
  final String coach;
  final List<PlayerSpot> players;
  final List<String> bench;
  final int kitColor;

  factory TeamLineup.fromApi(Map<String, dynamic> json) {
    final team = json['team'] ?? {};
    final startXI = (json['startXI'] as List? ?? []).map((p) => PlayerSpot.fromApi(p)).toList();
    final substitutes = (json['substitutes'] as List? ?? []).map((p) => (p['player']?['name'] ?? '').toString()).toList();
    
    return TeamLineup(
      teamName: team['name'] ?? '',
      teamCode: team['id']?.toString() ?? '',
      formation: json['formation'] ?? '',
      coach: json['coach']?['name'] ?? '',
      players: startXI,
      bench: substitutes,
      kitColor: 0xFFFFFFFF,
    );
  }
}

class MatchInsight {
  const MatchInsight({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}
