import '../models/live_match.dart';
import '../models/match_details.dart';

MatchDetails getMockMatchDetails(LiveMatch match) {
  final seed = match.id.hashCode;

  // Données spécifiques pour les matchs connus de 2022 si l'API fait défaut
  List<MatchEvent> events = [
    MatchEvent(
      minute: "12'",
      title: 'But',
      description: 'Ouverture du score.',
      icon: MatchEventIcon.goal,
    ),
  ];

  if (match.homeTeam == 'Qatar' && match.awayTeam == 'Ecuador') {
    events = [
      MatchEvent(
        minute: "16'",
        title: 'But',
        description: 'Enner Valencia (Penalty)',
        icon: MatchEventIcon.goal,
      ),
      MatchEvent(
        minute: "31'",
        title: 'But',
        description: 'Enner Valencia',
        icon: MatchEventIcon.goal,
      ),
    ];
  } else if (match.homeTeam == 'Argentina' && match.awayTeam == 'France') {
    events = [
      MatchEvent(
        minute: "23'",
        title: 'But',
        description: 'Lionel Messi (Penalty)',
        icon: MatchEventIcon.goal,
      ),
      MatchEvent(
        minute: "36'",
        title: 'But',
        description: 'Angel Di Maria',
        icon: MatchEventIcon.goal,
      ),
      MatchEvent(
        minute: "80'",
        title: 'But',
        description: 'Kylian Mbappé (Penalty)',
        icon: MatchEventIcon.goal,
      ),
      MatchEvent(
        minute: "81'",
        title: 'But',
        description: 'Kylian Mbappé',
        icon: MatchEventIcon.goal,
      ),
      MatchEvent(
        minute: "108'",
        title: 'But',
        description: 'Lionel Messi',
        icon: MatchEventIcon.goal,
      ),
      MatchEvent(
        minute: "118'",
        title: 'But',
        description: 'Kylian Mbappé (Penalty)',
        icon: MatchEventIcon.goal,
      ),
    ];
  }

  return MatchDetails(
    matchId: match.id,
    overview: MatchOverview(
      title: '${match.homeTeam} v ${match.awayTeam}',
      homeTeam: match.homeTeam,
      homeCode: match.homeCode,
      awayTeam: match.awayTeam,
      awayCode: match.awayCode,
      scoreHome: match.scoreHome ?? 0,
      scoreAway: match.scoreAway ?? 0,
      penaltyHome: match.penaltyHome,
      penaltyAway: match.penaltyAway,
      status: 'Terminé',
      minute: "90'",
    ),
    summary: MatchSummary(
      startTime: match.localTime,
      referee: const MatchOfficial(
        name: 'Szymon Marciniak',
        nationality: 'Pologne',
      ),
      venue: MatchVenue(
        stadium: match.city == 'Lusail'
            ? 'Lusail Stadium'
            : '${match.city} Stadium',
        capacity: '88,966 places',
        city: match.city,
      ),
      events: events,
    ),
    stats: [
      MatchStat(label: 'Possession', homeValue: 46.0, awayValue: 54.0),
      MatchStat(label: 'Tirs', homeValue: 12.0, awayValue: 10.0),
      MatchStat(label: 'Tirs cadrés', homeValue: 5.0, awayValue: 3.0),
      MatchStat(label: 'Fautes', homeValue: 15.0, awayValue: 18.0),
    ],
    homeLineup: TeamLineup(
      teamName: match.homeTeam,
      teamCode: match.homeCode,
      formation: '4-3-3',
      coach: 'Entraîneur A',
      kitColor: _getKitColor(match.homeCode),
      bench: [
        PlayerSpot(name: 'Joueur 12', role: 'SUB', number: 12, x: 0, y: 0),
        PlayerSpot(name: 'Joueur 15', role: 'SUB', number: 15, x: 0, y: 0),
        PlayerSpot(name: 'Joueur 20', role: 'SUB', number: 20, x: 0, y: 0),
      ],
      players: [
        PlayerSpot(name: 'Gardien', role: 'GK', number: 1, x: 0.50, y: 0.88),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 2, x: 0.20, y: 0.70),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 4, x: 0.40, y: 0.72),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 5, x: 0.60, y: 0.72),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 3, x: 0.80, y: 0.70),
        PlayerSpot(name: 'Milieu', role: 'MF', number: 6, x: 0.30, y: 0.50),
        PlayerSpot(
          name: 'Milieu',
          role: 'MF',
          number: 8,
          x: 0.50,
          y: 0.55,
          isCaptain: true,
        ),
        PlayerSpot(name: 'Milieu', role: 'MF', number: 10, x: 0.70, y: 0.50),
        PlayerSpot(name: 'Attaquant', role: 'FW', number: 11, x: 0.20, y: 0.25),
        PlayerSpot(name: 'Attaquant', role: 'FW', number: 9, x: 0.50, y: 0.18),
        PlayerSpot(name: 'Attaquant', role: 'FW', number: 7, x: 0.80, y: 0.25),
      ],
    ),
    awayLineup: TeamLineup(
      teamName: match.awayTeam,
      teamCode: match.awayCode,
      formation: '4-3-3',
      coach: 'Entraîneur B',
      kitColor: _getKitColor(match.awayCode),
      bench: [
        PlayerSpot(name: 'Joueur 14', role: 'SUB', number: 14, x: 0, y: 0),
        PlayerSpot(name: 'Joueur 16', role: 'SUB', number: 16, x: 0, y: 0),
        PlayerSpot(name: 'Joueur 21', role: 'SUB', number: 21, x: 0, y: 0),
      ],
      players: [
        PlayerSpot(name: 'Gardien', role: 'GK', number: 1, x: 0.50, y: 0.88),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 2, x: 0.20, y: 0.70),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 4, x: 0.40, y: 0.72),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 5, x: 0.60, y: 0.72),
        PlayerSpot(name: 'Défenseur', role: 'DF', number: 3, x: 0.80, y: 0.70),
        PlayerSpot(name: 'Milieu', role: 'MF', number: 6, x: 0.30, y: 0.50),
        PlayerSpot(
          name: 'Milieu',
          role: 'MF',
          number: 8,
          x: 0.50,
          y: 0.55,
          isCaptain: true,
        ),
        PlayerSpot(name: 'Milieu', role: 'MF', number: 10, x: 0.70, y: 0.50),
        PlayerSpot(name: 'Attaquant', role: 'FW', number: 11, x: 0.20, y: 0.25),
        PlayerSpot(name: 'Attaquant', role: 'FW', number: 9, x: 0.50, y: 0.18),
        PlayerSpot(name: 'Attaquant', role: 'FW', number: 7, x: 0.80, y: 0.25),
      ],
    ),
  );
}

int _getKitColor(String code) {
  return switch (code.toUpperCase()) {
    'QA' => 0xFF8D1B3D,
    'EC' => 0xFFFFD700,
    'AR' => 0xFF75AADB,
    'FR' => 0xFF002395,
    'GB' => 0xFFFFFFFF,
    'IR' => 0xFF239F40,
    'SN' => 0xFF00853F,
    'NL' => 0xFFFF4F00,
    'SA' => 0xFF006C35,
    _ => 0xFFFFFFFF,
  };
}
