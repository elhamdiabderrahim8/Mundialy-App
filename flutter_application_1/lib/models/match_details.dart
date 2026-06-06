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
    // Détecte le format BFF v2 (response.event + response.venue + response.referee séparés)
    final bool isBFFv2 = json.containsKey('event') && json.containsKey('venue') && json.containsKey('referee');
    // Format BFF v1 legacy (event contient tout)
    final bool isCombined = json.containsKey('event');
    // Format API-Sports (fixture + teams + goals)
    final bool isApiSports = json.containsKey('fixture');

    MatchDetails details;
    if (isBFFv2) {
      details = _parseBFFv2(json);
    } else if (isCombined) {
      details = _parseBFFv1(json);
    } else if (isApiSports) {
      details = _parseApiSports(json);
    } else {
      details = _parseBFFv2(json);
    }
    
    _applyEventsToLineups(details.summary.events, details.homeLineup, details.awayLineup);
    return details;
  }

  /// Parse le format BFF v2 (nouveau format propre)
  static MatchDetails _parseBFFv2(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>? ?? {};
    final homeTeam = event['homeTeam'] as Map<String, dynamic>? ?? {};
    final awayTeam = event['awayTeam'] as Map<String, dynamic>? ?? {};
    final hScore = event['homeScore'] as Map<String, dynamic>? ?? {};
    final aScore = event['awayScore'] as Map<String, dynamic>? ?? {};
    final status = event['status'] as Map<String, dynamic>? ?? {};
    final venue = json['venue'] as Map<String, dynamic>? ?? {};
    final referee = json['referee'] as Map<String, dynamic>? ?? {};
    final managers = json['managers'] as Map<String, dynamic>? ?? {};
    final kitColors = json['kitColors'] as Map<String, dynamic>? ?? {};

    // Logos — flagcdn.com handles display via countryCode in NationFlagBadge
    final String homeLogoUrl = homeTeam['logo'] ?? '';
    final String awayLogoUrl = awayTeam['logo'] ?? '';

    // Code pays pour drapeaux (3 lettres comme QAT, ECU)
    final String homeCode = homeTeam['nameCode']?.toString() ?? '';
    final String awayCode = awayTeam['nameCode']?.toString() ?? '';

    // Timestamp → date lisible
    final int ts = event['startTimestamp'] ?? 0;
    String startTimeStr = '';
    if (ts > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
      startTimeStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // Coach names
    final String homeCoach = (managers['home'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
    final String awayCoach = (managers['away'] as Map<String, dynamic>?)?['name']?.toString() ?? '';

    // Kit colors
    final int homeKitColor = _parseHexColor(kitColors['home']?.toString() ?? '660000');
    final int awayKitColor = _parseHexColor(kitColors['away']?.toString() ?? '003399');

    return MatchDetails(
      matchId: event['id']?.toString() ?? '0',
      overview: MatchOverview(
        title: '${homeTeam['name']} vs ${awayTeam['name']}',
        homeTeam: homeTeam['name'] ?? 'Home',
        homeCode: homeCode,
        homeLogoUrl: homeLogoUrl,
        awayTeam: awayTeam['name'] ?? 'Away',
        awayCode: awayCode,
        awayLogoUrl: awayLogoUrl,
        scoreHome: _toIntSafe(hScore['current']),
        scoreAway: _toIntSafe(aScore['current']),
        penaltyHome: _toIntOrNull(hScore['penalties']),
        penaltyAway: _toIntOrNull(aScore['penalties']),
        status: status['description']?.toString() ?? 'Terminé',
        minute: 'FT',
      ),
      summary: MatchSummary(
        events: _parseIncidents(json['incidents'], homeTeam, awayTeam, homeCode, awayCode),
        referee: MatchOfficial(
          name: referee['name']?.toString() ?? '',
          nationality: referee['country']?.toString() ?? '',
        ),
        venue: MatchVenue(
          stadium: venue['name']?.toString() ?? 'Stadium',
          capacity: venue['capacity']?.toString() ?? '',
          city: venue['city']?.toString() ?? '',
        ),
        startTime: startTimeStr,
      ),
      stats: _parseStats(json['statistics'], true),
      homeLineup: _parseLineupBFF(
        json['lineups']?['home'], 
        homeTeam['name'] ?? '', 
        homeCode, 
        homeCoach, 
        homeKitColor,
      ),
      awayLineup: _parseLineupBFF(
        json['lineups']?['away'], 
        awayTeam['name'] ?? '', 
        awayCode, 
        awayCoach, 
        awayKitColor,
      ),
    );
  }

  /// Parse les incidents BFF v2
  static List<MatchEvent> _parseIncidents(dynamic incidentsJson, Map<String, dynamic> homeTeam, Map<String, dynamic> awayTeam, String homeCode, String awayCode) {
    if (incidentsJson is! List) return [];
    return incidentsJson.map<MatchEvent?>((e) {
      final json = e as Map<String, dynamic>;
      final type = json['incidentType']?.toString().toLowerCase() ?? '';
      final incidentClass = json['incidentClass']?.toString().toLowerCase() ?? '';
      final from = json['from']?.toString().toLowerCase() ?? '';
      final isHome = json['isHome'] as bool?;

      String tName = '';
      String tCode = '';
      int? tId;

      if (isHome != null) {
        if (isHome) {
          tName = homeTeam['name']?.toString() ?? '';
          tCode = homeCode;
          tId = _toIntOrNull(homeTeam['id']);
        } else {
          tName = awayTeam['name']?.toString() ?? '';
          tCode = awayCode;
          tId = _toIntOrNull(awayTeam['id']);
        }
      }

      MatchEventIcon icon = MatchEventIcon.goal;
      String title = 'Action';
      String description = '';

      if (type == 'goal') {
        icon = MatchEventIcon.goal;
        final playerName = json['player']?['name'] ?? 'Joueur';
        final assistName = json['assist']?['name'];
        if (incidentClass == 'penalty' || from == 'penalty') {
          title = "PENALTY MARQUÉ";
        } else if (incidentClass == 'owngoal' || incidentClass == 'own-goal') {
          title = "BUT CONTRE SON CAMP";
        } else {
          title = "BUT !";
        }
        description = playerName;
        if (assistName != null && assistName.isNotEmpty) {
          description += ' (pass. $assistName)';
        }
      } else if (type == 'penaltyshootout') {
        final isScored = incidentClass == 'scored';
        icon = isScored ? MatchEventIcon.goal : MatchEventIcon.penaltyMissed;
        title = isScored ? "TIR AU BUT MARQUÉ" : "TIR AU BUT MANQUÉ";
        description = json['player']?['name'] ?? 'Joueur';
        
        final homeScore = json['homeScore'];
        final awayScore = json['awayScore'];
        if (homeScore != null && awayScore != null) {
          description += ' ($homeScore - $awayScore)';
        }
      } else if (type == 'substitution') {
        icon = MatchEventIcon.substitution;
        title = "CHANGEMENT";
        final pIn = json['playerIn']?['name'] ?? 'Entrant';
        final pOut = json['playerOut']?['name'] ?? 'Sortant';
        description = "$pIn remplace $pOut";
      } else if (type == 'card') {
        if (incidentClass == 'red' || incidentClass == 'yellowred') {
          icon = MatchEventIcon.redCard;
          title = incidentClass == 'yellowred' ? "SECOND JAUNE" : "CARTON ROUGE";
        } else {
          icon = MatchEventIcon.yellowCard;
          title = "CARTON JAUNE";
        }
        description = json['player']?['name'] ?? 'Joueur';
        final reason = json['reason']?.toString() ?? '';
        if (reason.isNotEmpty) description += ' ($reason)';
      } else if (type == 'vardecision') {
        icon = MatchEventIcon.varReview;
        title = "DÉCISION VAR";
        description = json['player']?['name'] ?? '';
        if (incidentClass == 'goalawarded') {
          title = "VAR: BUT ACCORDÉ";
        } else if (incidentClass == 'goalnotawarded') {
          title = "VAR: BUT ANNULÉ";
          icon = MatchEventIcon.cancelledGoal;
        }
      } else if (type == 'injurytime') {
        return MatchEvent(
          minute: "${json['time'] ?? 45}'",
          title: "TEMPS ADDITIONNEL",
          description: "+${json['length'] ?? '?'} min",
          icon: MatchEventIcon.offside,
          detail: '',
        );
      } else {
        return null;
      }

      return MatchEvent(
        minute: json['displayTime']?.toString() ?? "${json['time'] ?? 0}'",
        title: title,
        description: description,
        icon: icon,
        detail: incidentClass,
        teamId: tId,
        teamName: tName,
        teamCode: tCode,
        playerId: _toIntOrNull(json['player']?['id']),
        playerIn: json['playerIn']?['name'],
        playerInId: _toIntOrNull(json['playerIn']?['id']),
        playerOut: json['playerOut']?['name'],
        playerOutId: _toIntOrNull(json['playerOut']?['id']),
        assistant: json['assist']?['name'],
        assistantId: _toIntOrNull(json['assist']?['id']),
      );
    }).whereType<MatchEvent>().toList();
  }

  /// Parse les lineups BFF v2
  static TeamLineup _parseLineupBFF(
    dynamic lineupJson, 
    String teamName, 
    String teamCode, 
    String coach, 
    int kitColor,
  ) {
    if (lineupJson is! Map<String, dynamic>) {
      return TeamLineup(
        teamName: teamName,
        teamCode: teamCode,
        formation: 'N/A',
        coach: coach,
        players: [],
        bench: [],
        kitColor: kitColor,
      );
    }
    final json = lineupJson;
    final starters = (json['startXI'] as List? ?? []).map<PlayerSpot>((p) {
      final player = p['player'] as Map<String, dynamic>? ?? {};
      return PlayerSpot(
        id: _toIntSafe(player['id']),
        name: player['name']?.toString() ?? '',
        number: _toIntSafe(player['number']),
        role: player['pos']?.toString() ?? '',
        x: 0, y: 0,
      );
    }).toList();

    final subs = (json['substitutes'] as List? ?? []).map<PlayerSpot>((p) {
      final player = p['player'] as Map<String, dynamic>? ?? {};
      return PlayerSpot(
        id: _toIntSafe(player['id']),
        name: player['name']?.toString() ?? '',
        number: _toIntSafe(player['number']),
        role: player['pos']?.toString() ?? '',
        x: 0, y: 0,
      );
    }).toList();

    return TeamLineup(
      teamName: json['team']?['name']?.toString() ?? teamName,
      teamCode: json['team']?['nameCode']?.toString() ?? teamCode,
      formation: json['formation']?.toString() ?? 'N/A',
      coach: json['coach']?['name']?.toString() ?? coach,
      players: starters,
      bench: subs,
      kitColor: kitColor,
    );
  }

  /// Parse le format BFF v1 legacy
  static MatchDetails _parseBFFv1(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>? ?? {};
    final teams = {
      'home': event['homeTeam'] ?? {},
      'away': event['awayTeam'] ?? {},
    };
    final goals = {
      'home': event['homeScore']?['current'],
      'away': event['awayScore']?['current'],
    };
    final score = {
      'penalty': {
        'home': event['homeScore']?['penalties'],
        'away': event['awayScore']?['penalties'],
      }
    };

    return MatchDetails(
      matchId: event['id']?.toString() ?? '0',
      overview: MatchOverview(
        title: '${teams['home']?['name']} vs ${teams['away']?['name']}',
        homeTeam: teams['home']?['name'] ?? 'Home',
        homeCode: teams['home']?['nameCode']?.toString() ?? teams['home']?['id']?.toString() ?? 'H',
        homeLogoUrl: teams['home']?['logo'] ?? '',
        awayTeam: teams['away']?['name'] ?? 'Away',
        awayCode: teams['away']?['nameCode']?.toString() ?? teams['away']?['id']?.toString() ?? 'A',
        awayLogoUrl: teams['away']?['logo'] ?? '',
        scoreHome: _toIntSafe(goals['home']),
        scoreAway: _toIntSafe(goals['away']),
        penaltyHome: _toIntOrNull(score['penalty']?['home']),
        penaltyAway: _toIntOrNull(score['penalty']?['away']),
        status: event['status']?['description']?.toString() ?? 'Unknown',
        minute: 'FT',
      ),
      summary: MatchSummary(
        events: (json['incidents'] is List 
            ? _parseIncidents(
                json['incidents'], 
                teams['home'] as Map<String, dynamic>? ?? {}, 
                teams['away'] as Map<String, dynamic>? ?? {}, 
                teams['home']?['nameCode']?.toString() ?? '', 
                teams['away']?['nameCode']?.toString() ?? ''
              ) 
            : (json['events'] as List? ?? []).map((e) => MatchEvent.fromApi(e as Map<String, dynamic>)).toList()),
        referee: MatchOfficial(
          name: json['referee']?['name']?.toString() ?? 
                json['managers']?['home']?['name']?.toString() ?? 'Arbitre',
          nationality: json['referee']?['country']?.toString() ?? '',
        ),
        venue: MatchVenue(
          stadium: json['venue']?['name']?.toString() ?? 'Stadium',
          capacity: json['venue']?['capacity']?.toString() ?? '',
          city: json['venue']?['city']?.toString() ?? 'City',
        ),
        startTime: '',
      ),
      stats: _parseStats(json['statistics'], true),
      homeLineup: TeamLineup.fromApi(json['lineups']?['home'] ?? {}),
      awayLineup: TeamLineup.fromApi(json['lineups']?['away'] ?? {}),
    );
  }

  /// Parse le format API-Sports (non utilisé actuellement)
  static MatchDetails _parseApiSports(Map<String, dynamic> json) {
    final fixture = json['fixture'] ?? {};
    final teams = json['teams'] ?? {};
    final goals = json['goals'] ?? {};
    final score = json['score'] ?? {};

    return MatchDetails(
      matchId: fixture['id']?.toString() ?? '0',
      overview: MatchOverview(
        title: '${teams['home']?['name']} vs ${teams['away']?['name']}',
        homeTeam: teams['home']?['name'] ?? 'Home',
        homeCode: teams['home']?['id']?.toString() ?? 'H',
        homeLogoUrl: teams['home']?['logo'],
        awayTeam: teams['away']?['name'] ?? 'Away',
        awayCode: teams['away']?['id']?.toString() ?? 'A',
        awayLogoUrl: teams['away']?['logo'],
        scoreHome: _toIntSafe(goals['home']),
        scoreAway: _toIntSafe(goals['away']),
        penaltyHome: _toIntOrNull(score['penalty']?['home']),
        penaltyAway: _toIntOrNull(score['penalty']?['away']),
        status: fixture['status']?['long']?.toString() ?? 'Unknown',
        minute: fixture['status']?['elapsed']?.toString() ?? '0',
      ),
      summary: MatchSummary(
        events: (json['events'] as List? ?? []).map((e) => MatchEvent.fromApi(e as Map<String, dynamic>)).toList(),
        referee: MatchOfficial(name: fixture['referee']?.toString() ?? 'Arbitre', nationality: ''),
        venue: MatchVenue(
          stadium: fixture['venue']?['name']?.toString() ?? 'Stadium',
          capacity: '',
          city: fixture['venue']?['city']?.toString() ?? 'City',
        ),
        startTime: fixture['date']?.toString() ?? '',
      ),
      stats: _parseStats(json['statistics'], false),
      homeLineup: TeamLineup.fromApi(json['lineups'] is List && (json['lineups'] as List).isNotEmpty ? json['lineups'][0] : {}),
      awayLineup: TeamLineup.fromApi(json['lineups'] is List && (json['lineups'] as List).length > 1 ? json['lineups'][1] : {}),
    );
  }

  static int _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return int.tryParse(hex, radix: 16) ?? 0xFF660000;
  }

  static int _toIntSafe(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static List<MatchStat> _parseStats(dynamic statsJson, bool isCombined) {
    if (statsJson == null) return [];
    final List<MatchStat> result = [];
    
    if (statsJson is List) {
      for (var period in statsJson) {
        if (period is Map && period['period'] == 'ALL') {
          final groups = period['groups'] as List? ?? [];
          for (var group in groups) {
            final items = group['statisticsItems'] as List? ?? [];
            for (var item in items) {
              if (item is Map) {
                result.add(MatchStat(
                  label: item['name']?.toString() ?? '',
                  homeValue: MatchStat._p(item['homeValue']),
                  awayValue: MatchStat._p(item['awayValue']),
                ));
              }
            }
          }
        }
      }
    }
    
    if (result.isNotEmpty) return result;
    if (statsJson is List) {
      return statsJson
          .whereType<Map<String, dynamic>>()
          .map((s) => MatchStat.fromApi(s))
          .toList();
    }
    return [];
  }

  static void _applyEventsToLineups(List<MatchEvent> events, TeamLineup homeLineup, TeamLineup awayLineup) {
    PlayerSpot? findTarget(Iterable<PlayerSpot> players, int? id, String? name) {
      if (id != null) {
        for (final p in players) {
          if (p.id == id) return p;
        }
      }
      if (name != null && name.isNotEmpty) {
        for (final p in players) {
          if (p.name.contains(name) || name.contains(p.name)) return p;
        }
      }
      return null;
    }

    for (final event in events) {
      final isHome = (event.teamName == homeLineup.teamName || event.teamCode == homeLineup.teamCode);
      final lineup = isHome ? homeLineup : awayLineup;
      final Iterable<PlayerSpot> allPlayers = [...lineup.players, ...lineup.bench];

      if (event.icon == MatchEventIcon.substitution) {
        final inTarget = findTarget(allPlayers, event.playerInId, event.playerIn);
        if (inTarget != null) inTarget.substitutedIn = true;
        
        final outTarget = findTarget(allPlayers, event.playerOutId, event.playerOut);
        if (outTarget != null) outTarget.substitutedOut = true;
      } else {
        final target = findTarget(allPlayers, event.playerId, event.description);
        if (target != null) {
          if (event.icon == MatchEventIcon.goal) target.goals++;
          if (event.icon == MatchEventIcon.yellowCard) target.yellowCards++;
          if (event.icon == MatchEventIcon.redCard) target.redCard = true;
        }
        
        if (event.assistant != null || event.assistantId != null) {
          final astTarget = findTarget(allPlayers, event.assistantId, event.assistant);
          if (astTarget != null) astTarget.assists++;
        }
      }
    }
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
    final type = json['incidentType']?.toString().toLowerCase() ?? json['type']?.toString().toLowerCase() ?? '';
    final incidentClass = json['incidentClass']?.toString().toLowerCase() ?? '';

    MatchEventIcon icon = MatchEventIcon.goal;
    String title = json['type']?.toString() ?? 'Action';
    String description = json['player']?['name']?.toString() ?? 'Joueur';
    
    if (type == 'goal') {
      icon = MatchEventIcon.goal;
      if (incidentClass == 'penalty') {
        title = "PENALTY MARQUÉ";
      } else if (incidentClass == 'own-goal' || incidentClass == 'owngoal') {
        title = "BUT CONTRE SON CAMP";
      } else {
        title = "BUT !";
      }
    } else if (type == 'substitution') {
      icon = MatchEventIcon.substitution;
      title = "CHANGEMENT";
      final pIn = json['playerIn']?['name'] ?? 'Entrant';
      final pOut = json['playerOut']?['name'] ?? 'Sortant';
      description = "$pIn remplace $pOut";
    } else if (type == 'card') {
      if (incidentClass == 'red') {
        icon = MatchEventIcon.redCard;
        title = "CARTON ROUGE";
      } else {
        icon = MatchEventIcon.yellowCard;
        title = "CARTON JAUNE";
      }
    } else if (type == 'var' || type == 'vardecision') {
      icon = MatchEventIcon.varReview;
      title = "DÉCISION VAR";
    }

    return MatchEvent(
      minute: "${_readElapsedMinute(json) ?? 0}'",
      title: title,
      description: description,
      icon: icon,
      detail: incidentClass,
      teamId: _toInt(json['team']?['id']),
      teamName: json['team']?['name']?.toString() ?? '',
      playerIn: json['playerIn']?['name']?.toString(),
      playerOut: json['playerOut']?['name']?.toString(),
    );
  }

  static int? _readElapsedMinute(Map<String, dynamic> json) {
    final dynamic timeValue = json['time'];
    if (timeValue is Map) {
      return _toInt(timeValue['elapsed']) ?? _toInt(timeValue['current']) ?? _toInt(timeValue['minute']);
    }
    return _toInt(timeValue) ?? _toInt(json['elapsed']) ?? _toInt(json['minute']);
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
      label: json['type']?.toString() ?? '',
      homeValue: _p(json['home']),
      awayValue: _p(json['away']),
    );
  }
  static double _p(dynamic v) { if (v == null) return 0; if (v is String) return double.tryParse(v.replaceAll('%', '')) ?? 0; return (v as num).toDouble(); }
}

class PlayerSpot {
  PlayerSpot({
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
    this.substitutedIn = false,
    this.substitutedOut = false,
  });

  int id;
  String name;
  String role;
  int number;
  double x;
  double y;
  String rating;
  bool isCaptain;
  int goals;
  int assists;
  int yellowCards;
  bool redCard;
  bool substitutedIn;
  bool substitutedOut;

  factory PlayerSpot.fromApi(Map<String, dynamic> json) {
    final player = json['player'] ?? {};
    return PlayerSpot(
      id: player['id'] ?? 0,
      name: player['name']?.toString() ?? '',
      number: player['number'] ?? json['number'] ?? json['jerseyNumber'] ?? 0,
      role: player['pos']?.toString() ?? player['position']?.toString() ?? '',
      x: 0, y: 0,
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
  final List<PlayerSpot> bench;
  final int kitColor;

  factory TeamLineup.fromApi(Map<String, dynamic> json) {
    final team = json['team'] ?? {};
    final startXI = (json['startXI'] as List? ?? []).map((p) => PlayerSpot.fromApi(p as Map<String, dynamic>)).toList();
    final substitutes = (json['substitutes'] as List? ?? []).map((p) => PlayerSpot.fromApi(p as Map<String, dynamic>)).toList();
    
    return TeamLineup(
      teamName: team['name']?.toString() ?? '',
      teamCode: team['nameCode']?.toString() ?? team['id']?.toString() ?? '',
      formation: json['formation']?.toString() ?? '',
      coach: json['coach']?['name']?.toString() ?? '',
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
