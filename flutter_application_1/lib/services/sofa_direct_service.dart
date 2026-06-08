import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cronet_http/cronet_http.dart';

/// Service de récupération directe depuis l'API SofaScore.
/// Chaque téléphone a une IP résidentielle → jamais bloqué par Cloudflare.
class SofaDirectService {
  static const int _utId = 16; // World Cup unique tournament ID
  static const int _seasonId2026 = 58210;

  static const List<String> _domains = [
    'https://api.sofascore.com/api/v1',
    'https://api.sofascore.app/api/v1',
  ];

  static final _random = Random();
  static http.Client? _cronetClient;

  /// Initialise Cronet (le moteur réseau de Chrome) pour contourner Cloudflare
  static Future<http.Client> _getClient() async {
    if (_cronetClient != null) return _cronetClient!;
    if (Platform.isAndroid) {
      try {
        final engine = CronetEngine.build(
          cacheMode: CacheMode.memory,
          cacheMaxSize: 2 * 1024 * 1024,
          userAgent: 'Mozilla/5.0 (Linux; Android 13; Infinix) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        );
        _cronetClient = CronetClient.fromCronetEngine(engine);
        return _cronetClient!;
      } catch (e) {
        debugPrint('Cronet failed to load: $e');
      }
    }
    _cronetClient = http.Client();
    return _cronetClient!;
  }

  /// En-têtes qui imitent un navigateur mobile normal
  static Map<String, String> _headers() {
    return {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'Referer': 'https://www.sofascore.com/',
      'Origin': 'https://www.sofascore.com',
    };
  }

  /// Récupère du JSON depuis SofaScore avec retry, rotation de domaine et Cronet
  static Future<Map<String, dynamic>?> _fetchJson(String path,
      {int retries = 2}) async {
    final client = await _getClient();
    for (int attempt = 0; attempt <= retries; attempt++) {
      final domain = _domains[attempt % _domains.length];
      final url = '$domain$path';
      try {
        final response = await client
            .get(Uri.parse(url), headers: _headers())
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        debugPrint('[SofaDirect] Status ${response.statusCode} pour $url');
      } catch (e) {
        debugPrint('[SofaDirect] Erreur tentative ${attempt + 1}: $e');
      }
      if (attempt < retries) {
        await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(500)));
      }
    }
    return null;
  }

  // ============================================================
  //  MATCHS EN DIRECT (Live)
  // ============================================================

  /// Récupère les matchs en direct depuis SofaScore directement
  static Future<List<Map<String, dynamic>>> fetchLiveMatches() async {
    final data = await _fetchJson('/sport/football/events/live');
    if (data == null || data['events'] == null) return [];

    final events = data['events'] as List;
    final filtered = <Map<String, dynamic>>[];

    for (final e in events) {
      final status = e['status'] ?? {};
      final statusType = status['type'] ?? '';
      final isLive = statusType == 'inprogress';

      final homeScore = e['homeScore'] ?? {};
      final awayScore = e['awayScore'] ?? {};
      final dt = e['startTimestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (e['startTimestamp'] as int) * 1000)
          : DateTime.now();

      String shortStatus;
      if (statusType == 'finished') {
        shortStatus = 'FT';
      } else if (statusType == 'canceled') {
        shortStatus = 'CANC';
      } else if (statusType == 'postponed') {
        shortStatus = 'PST';
      } else if (isLive) {
        shortStatus = status['description'] ?? 'LIVE';
      } else {
        shortStatus = 'NS';
      }

      final currentHome = homeScore['current'] ?? homeScore['display'];
      final currentAway = awayScore['current'] ?? awayScore['display'];

      filtered.add({
        'fixture': {
          'id': e['id'],
          'date': dt.toIso8601String(),
          'timestamp': e['startTimestamp'],
          'status': {
            'short': shortStatus,
            'long': status['description'] ?? '',
            'type': statusType,
            'code': status['code'],
            'elapsed': status['currentMinute'],
          },
          'time': isLive ? (e['time'] ?? {}) : {},
        },
        'league': {
          'round': e['tournament']?['name'] ?? 'Match',
          'group': '',
        },
        'teams': {
          'home': {
            'id': e['homeTeam']?['id'],
            'name': e['homeTeam']?['name'],
            'logo':
                'https://api.sofascore.app/api/v1/team/${e['homeTeam']?['id']}/image',
          },
          'away': {
            'id': e['awayTeam']?['id'],
            'name': e['awayTeam']?['name'],
            'logo':
                'https://api.sofascore.app/api/v1/team/${e['awayTeam']?['id']}/image',
          },
        },
        'goals': {
          'home': currentHome is int ? currentHome : null,
          'away': currentAway is int ? currentAway : null,
        },
        'is_live': isLive,
      });
    }
    return filtered;
  }

  // ============================================================
  //  MATCHS / FIXTURES 2026
  // ============================================================

  /// Récupère tous les matchs de la Coupe du Monde 2026 (tous les rounds)
  static Future<List<Map<String, dynamic>>> fetchFixtures2026() async {
    final allEvents = <int, Map<String, dynamic>>{};

    // Récupérer les matchs par rounds (1 à 10) et les listes next/last en parallèle
    final futures = <Future<Map<String, dynamic>?>>[];
    for (int round = 1; round <= 10; round++) {
      futures.add(_fetchJson('/unique-tournament/$_utId/season/$_seasonId2026/events/round/$round'));
    }
    futures.add(_fetchJson('/unique-tournament/$_utId/season/$_seasonId2026/events/last/0'));
    futures.add(_fetchJson('/unique-tournament/$_utId/season/$_seasonId2026/events/next/0'));

    final results = await Future.wait(futures);

    for (final data in results) {
      if (data != null && data['events'] != null) {
        for (final ev in data['events'] as List) {
          allEvents[ev['id'] as int] = ev as Map<String, dynamic>;
        }
      }
    }

    if (allEvents.isEmpty) return [];

    final formatted = <Map<String, dynamic>>[];
    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (final e in allEvents.values) {
      final status = e['status'] ?? {};
      final statusType = status['type'] ?? '';

      String short;
      if (statusType == 'inprogress') {
        short = 'LIVE';
      } else if (statusType == 'finished') {
        short = 'FT';
      } else {
        short = 'NS';
      }

      // Minutes écoulées
      dynamic elapsed;
      if (short == 'LIVE') {
        final periodStart =
            (e['time'] ?? {})['currentPeriodStartTimestamp'];
        if (periodStart != null) {
          elapsed = (nowTs - (periodStart as int)) ~/ 60;
        }
        final desc = status['description'];
        if (desc != null && elapsed == null) elapsed = desc;
      }

      // Nom du round
      String roundName = (e['roundInfo'] ?? {})['name'] ??
          (e['tournament'] ?? {})['name'] ??
          '';
      if ((e['tournament'] ?? {})['isGroup'] == true) {
        final roundNum = (e['roundInfo'] ?? {})['round'];
        roundName =
            roundNum != null ? 'Group Stage - $roundNum' : 'Group Stage';
      }

      final hs = e['homeScore'] ?? {};
      final as_ = e['awayScore'] ?? {};
      final dt = e['startTimestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (e['startTimestamp'] as int) * 1000)
          : DateTime.now();

      formatted.add({
        'fixture': {
          'id': e['id'],
          'timestamp': e['startTimestamp'],
          'date': dt.toIso8601String(),
          'status': {
            'short': short,
            'long': status['description'] ?? '',
            'elapsed': elapsed,
          },
        },
        'league': {
          'round': roundName,
        },
        'teams': {
          'home': {
            'id': (e['homeTeam'] ?? {})['id'],
            'name': (e['homeTeam'] ?? {})['name'] ?? 'TBD',
            'logo':
                'https://api.sofascore.app/api/v1/team/${(e['homeTeam'] ?? {})['id']}/image',
          },
          'away': {
            'id': (e['awayTeam'] ?? {})['id'],
            'name': (e['awayTeam'] ?? {})['name'] ?? 'TBD',
            'logo':
                'https://api.sofascore.app/api/v1/team/${(e['awayTeam'] ?? {})['id']}/image',
          },
        },
        'goals': {
          'home': hs['current'] ?? hs['display'],
          'away': as_['current'] ?? as_['display'],
        },
        'score': {
          'penalty': {
            'home': hs['penalties'],
            'away': as_['penalties'],
          },
        },
      });
    }

    // Trier par date
    formatted.sort((a, b) {
      final tsA = a['fixture']?['timestamp'] ?? 0;
      final tsB = b['fixture']?['timestamp'] ?? 0;
      return (tsA as int).compareTo(tsB as int);
    });

    return formatted;
  }

  // ============================================================
  //  CLASSEMENTS 2026
  // ============================================================

  /// Récupère les classements des groupes de la Coupe du Monde 2026
  static Future<Map<String, dynamic>?> fetchStandings2026() async {
    final groupsData = await _fetchJson(
        '/unique-tournament/$_utId/season/$_seasonId2026/groups');
    if (groupsData == null || groupsData['groups'] == null) return null;

    final allStandings = <List<Map<String, dynamic>>>[];

    for (final g in groupsData['groups'] as List) {
      final tid = g['tournamentId'];
      if (tid == null) continue;

      final data = await _fetchJson(
          '/tournament/$tid/season/$_seasonId2026/standings/total');
      if (data != null && (data['standings'] as List?)?.isNotEmpty == true) {
        final teams = <Map<String, dynamic>>[];
        for (final r in (data['standings'] as List).first['rows'] as List) {
          final t = r['team'] ?? {};
          teams.add({
            'rank': r['position'],
            'group': g['groupName'],
            'team': {
              'id': t['id'],
              'name': t['name'],
              'logo':
                  'https://api.sofascore.app/api/v1/team/${t['id']}/image',
            },
            'points': r['points'] ?? 0,
            'goalsDiff':
                (r['goalsFor'] ?? 0) - (r['goalsAgainst'] ?? 0),
            'all': {
              'played': r['matches'] ?? 0,
              'win': r['wins'] ?? 0,
              'draw': r['draws'] ?? 0,
              'lose': r['losses'] ?? 0,
            },
          });
        }
        allStandings.add(teams);
      }
    }

    if (allStandings.isEmpty) return null;

    return {
      'response': [
        {
          'league': {
            'id': _utId,
            'name': 'World Cup 2026',
            'standings': allStandings,
          }
        }
      ]
    };
  }

  // ============================================================
  //  BUTEURS 2026
  // ============================================================

  /// Récupère les meilleurs buteurs de la Coupe du Monde 2026
  static Future<List<Map<String, dynamic>>> fetchTopScorers2026() async {
    final raw = await _fetchJson(
        '/unique-tournament/$_utId/season/$_seasonId2026/top-players/goals');
    if (raw == null) return [];

    final topPlayers = raw['topPlayers'] as List? ?? [];
    final formatted = <Map<String, dynamic>>[];

    for (final p in topPlayers.take(20)) {
      final player = p['player'] ?? {};
      final stats = p['statistics'] ?? {};
      formatted.add({
        'player': {
          'id': player['id'],
          'name': player['name'],
        },
        'team': p['team'] ?? {},
        'goals': stats['goals'] ?? 0,
        'assists': stats['assists'] ?? 0,
        'matches': stats['appearances'] ?? 0,
      });
    }
    return formatted;
  }

  // ============================================================
  //  DÉTAILS COMPLETS DU MATCH
  // ============================================================

  /// Récupère les détails complets d'un match directement depuis SofaScore
  /// Formate la réponse pour correspondre EXACTEMENT au format BFFv2 attendu par MatchDetails.fromApi
  static Future<Map<String, dynamic>?> fetchMatchDetails(int matchId) async {
    final results = await Future.wait([
      _fetchJson('/event/$matchId'),
      _fetchJson('/event/$matchId/lineups'),
      _fetchJson('/event/$matchId/incidents'),
      _fetchJson('/event/$matchId/statistics'),
    ]);

    final eventData = results[0];
    if (eventData == null) return null;

    final eventRaw = eventData['event'] ?? eventData;
    final lineupsData = results[1] ?? {};
    final incidentsData = results[2] ?? {};
    final statisticsData = results[3] ?? {};

    final homeTeamRaw = eventRaw['homeTeam'] ?? {};
    final awayTeamRaw = eventRaw['awayTeam'] ?? {};
    final hs = eventRaw['homeScore'] ?? {};
    final as_ = eventRaw['awayScore'] ?? {};
    
    final scoreH = hs['display'] ?? hs['current'] ?? 0;
    final scoreA = as_['display'] ?? as_['current'] ?? 0;

    // 3. Extraction Kit Colors (depuis incidents)
    String homeKitColor = '660000';
    String awayKitColor = '003399';
    if (incidentsData['home']?['playerColor']?['primary'] != null) {
      homeKitColor = incidentsData['home']['playerColor']['primary'];
    }
    if (incidentsData['away']?['playerColor']?['primary'] != null) {
      awayKitColor = incidentsData['away']['playerColor']['primary'];
    }

    // 4. Normalisation des lineups
    Map<String, dynamic> mapLineup(String side, Map<String, dynamic> teamData) {
      final data = lineupsData[side] ?? {};
      final players = data['players'] as List? ?? [];
      final starters = <Map<String, dynamic>>[];
      final subs = <Map<String, dynamic>>[];

      for (final p in players) {
        final pl = p['player'] ?? {};
        final entry = {
          'player': {
            'id': pl['id'] ?? 0,
            'name': pl['shortName'] ?? pl['name'] ?? 'Joueur',
            'number': p['shirtNumber'] ?? p['jerseyNumber'] ?? 0,
            'pos': p['position'] ?? '',
          }
        };
        if (p['substitute'] == true) {
          subs.add(entry);
        } else {
          starters.add(entry);
        }
      }

      final mgr = teamData['manager'] ?? {};
      return {
        'team': {
          'id': teamData['id'],
          'name': teamData['name'] ?? '',
          'nameCode': teamData['nameCode'] ?? '',
        },
        'formation': data['formation'] ?? 'N/A',
        'coach': {'name': mgr['name'] ?? ''},
        'startXI': starters,
        'substitutes': subs,
      };
    }

    final cleanLineups = {
      'home': mapLineup('home', homeTeamRaw),
      'away': mapLineup('away', awayTeamRaw),
    };

    // 5. Normalisation des incidents
    final cleanIncidents = <Map<String, dynamic>>[];
    final rawIncidents = incidentsData['incidents'] as List? ?? [];
    
    for (final inc in rawIncidents) {
      final iType = inc['incidentType'];
      if (!['goal', 'substitution', 'card', 'varDecision', 'injuryTime', 'penaltyShootout'].contains(iType)) {
        continue;
      }

      final timeVal = inc['time'] ?? 0;
      final added = inc['addedTime'];
      String displayTime = iType == 'penaltyShootout' ? 'TAB' : "$timeVal'";
      if (added != null && iType != 'penaltyShootout') {
        displayTime = "$timeVal+$added'";
      }

      final item = {
        'time': timeVal,
        'addedTime': added,
        'displayTime': displayTime,
        'incidentType': iType,
        'incidentClass': inc['incidentClass'] ?? '',
        'homeScore': inc['homeScore'],
        'awayScore': inc['awayScore'],
        'isHome': inc['isHome'],
        'length': inc['length'],
        'sequence': inc['sequence'],
      };

      if (iType == 'substitution') {
        final pIn = inc['playerIn'] ?? {};
        final pOut = inc['playerOut'] ?? {};
        item['playerIn'] = {
          'id': pIn['id'] ?? 0,
          'name': pIn['shortName'] ?? pIn['name'] ?? 'Entrant',
        };
        item['playerOut'] = {
          'id': pOut['id'] ?? 0,
          'name': pOut['shortName'] ?? pOut['name'] ?? 'Sortant',
        };
      } else if (iType == 'card' || iType == 'varDecision') {
        final pl = inc['player'] ?? {};
        item['player'] = {
          'id': pl['id'] ?? 0,
          'name': pl['shortName'] ?? pl['name'] ?? inc['playerName'] ?? 'Joueur',
        };
        if (iType == 'card') item['reason'] = inc['reason'] ?? '';
      } else if (iType == 'goal' || iType == 'penaltyShootout') {
        final pl = inc['player'] ?? {};
        item['player'] = {
          'id': pl['id'] ?? 0,
          'name': pl['shortName'] ?? pl['name'] ?? 'Joueur',
        };
        item['from'] = inc['from'] ?? '';
        final assistPl = inc['assist1'] ?? {};
        if (assistPl.isNotEmpty) {
          item['assist'] = {
            'id': assistPl['id'] ?? 0,
            'name': assistPl['shortName'] ?? assistPl['name'] ?? '',
          };
        }
      }

      cleanIncidents.add(item);
    }
    
    // Trier par temps
    cleanIncidents.sort((a, b) {
      final t1 = a['time'] as int? ?? 0;
      final t2 = b['time'] as int? ?? 0;
      if (t1 != t2) return t1.compareTo(t2);
      final a1 = a['addedTime'] as int? ?? 0;
      final a2 = b['addedTime'] as int? ?? 0;
      if (a1 != a2) return a1.compareTo(a2);
      final s1 = a['sequence'] as int? ?? 0;
      final s2 = b['sequence'] as int? ?? 0;
      return s1.compareTo(s2);
    });

    // 6. Venue
    final venueRaw = eventRaw['venue'] ?? {};
    final venueName = venueRaw['name'] ?? venueRaw['stadium']?['name'] ?? 'Stadium';
    final venueCity = venueRaw['city']?['name'] ?? '';
    final venueCapacity = venueRaw['capacity'] ?? venueRaw['stadium']?['capacity'] ?? '';

    // 7. Referee
    final refRaw = eventRaw['referee'] ?? {};
    final refName = refRaw['name'] ?? '';
    final refCountry = refRaw['country']?['name'] ?? '';

    // 8. Réponse BFF v2 finale
    const imgBase = 'https://api.sofascore.app/api/v1/team';
    
    return {
      'response': {
        'event': {
          'id': matchId,
          'homeTeam': {
            'id': homeTeamRaw['id'],
            'name': homeTeamRaw['name'] ?? 'Home',
            'nameCode': homeTeamRaw['nameCode'] ?? '',
            'logo': '$imgBase/${homeTeamRaw['id']}/image',
          },
          'awayTeam': {
            'id': awayTeamRaw['id'],
            'name': awayTeamRaw['name'] ?? 'Away',
            'nameCode': awayTeamRaw['nameCode'] ?? '',
            'logo': '$imgBase/${awayTeamRaw['id']}/image',
          },
          'homeScore': {'current': scoreH, 'penalties': hs['penalties']},
          'awayScore': {'current': scoreA, 'penalties': as_['penalties']},
          'winnerCode': eventRaw['winnerCode'],
          'status': eventRaw['status'] ?? {'description': 'Terminé', 'type': 'finished'},
          'startTimestamp': eventRaw['startTimestamp'] ?? 0,
        },
        'venue': {
          'name': venueName,
          'city': venueCity,
          'capacity': venueCapacity.toString(),
        },
        'referee': {
          'name': refName,
          'country': refCountry,
        },
        'managers': {
          'home': {'name': homeTeamRaw['manager']?['name'] ?? ''},
          'away': {'name': awayTeamRaw['manager']?['name'] ?? ''},
        },
        'lineups': cleanLineups,
        'statistics': statisticsData['statistics'] ?? [],
        'incidents': cleanIncidents,
        'kitColors': {
          'home': homeKitColor,
          'away': awayKitColor,
        },
      }
    };
  }

  // ============================================================
  //  COACH & SQUAD (Profil d'équipe)
  // ============================================================

  /// Récupère le coach d'une équipe
  static Future<Map<String, dynamic>?> fetchTeamCoach(int teamId) async {
    final data = await _fetchJson('/team/$teamId');
    if (data == null) return null;
    final manager = data['team']?['manager'] ?? data['manager'];
    if (manager == null) return null;
    return {
      'id': manager['id'],
      'name': manager['name'],
      'photo':
          'https://api.sofascore.app/api/v1/manager/${manager['id']}/image',
      'nationality': manager['country']?['name'],
    };
  }

  /// Récupère les joueurs d'une équipe
  static Future<List<Map<String, dynamic>>> fetchTeamSquad(int teamId) async {
    final data = await _fetchJson('/team/$teamId/players');
    if (data == null || data['players'] == null) return [];

    final players = <Map<String, dynamic>>[];
    for (final p in data['players'] as List) {
      final player = p['player'] ?? {};
      players.add({
        'id': player['id'],
        'name': player['name'],
        'position': player['position'],
        'shirtNumber': player['shirtNumber'] ?? p['shirtNumber'],
        'height': player['height'],
        'dateOfBirthTimestamp': player['dateOfBirthTimestamp'],
        'nationality': player['country']?['name'],
        'photo':
            'https://api.sofascore.app/api/v1/player/${player['id']}/image',
      });
    }
    return players;
  }

  // ============================================================
  //  STATS JOUEUR
  // ============================================================

  /// Récupère les stats d'un joueur pour un tournoi
  static Future<Map<String, dynamic>?> fetchPlayerStats(
      int playerId, int seasonId) async {
    final data = await _fetchJson(
        '/player/$playerId/unique-tournament/$_utId/season/$seasonId/statistics/overall');
    return data;
  }

  /// Récupère les statistiques en équipe nationale d'un joueur
  static Future<Map<String, dynamic>?> fetchPlayerNationalStats(int playerId) async {
    return await _fetchJson('/player/$playerId/national-team-statistics');
  }

  /// Récupère les caractéristiques physiques d'un joueur
  /// (taille, poids, pied préféré, âge, poste)
  static Future<Map<String, dynamic>?> fetchPlayerCharacteristics(int playerId) async {
    return await _fetchJson('/player/$playerId/characteristics');
  }

  /// Récupère les attributs de notation d'un joueur
  /// (vitesse, tir, passe, dribble, défense, physique — style FIFA)
  static Future<Map<String, dynamic>?> fetchPlayerAttributes(int playerId) async {
    return await _fetchJson('/player/$playerId/attribute-overviews');
  }
}
