import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  /// En-têtes qui imitent un navigateur mobile normal
  static Map<String, String> _headers() {
    return {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Infinix) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.sofascore.com/',
      'Origin': 'https://www.sofascore.com',
    };
  }

  /// Récupère du JSON depuis SofaScore avec retry et rotation de domaine
  static Future<Map<String, dynamic>?> _fetchJson(String path,
      {int retries = 2}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      final domain = _domains[attempt % _domains.length];
      final url = '$domain$path';
      try {
        final response = await http
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

    // Récupérer les matchs par rounds (1 à 10 pour couvrir groupes + éliminations)
    for (int round = 1; round <= 10; round++) {
      final data = await _fetchJson(
          '/unique-tournament/$_utId/season/$_seasonId2026/events/round/$round');
      if (data != null && data['events'] != null) {
        for (final ev in data['events'] as List) {
          allEvents[ev['id'] as int] = ev as Map<String, dynamic>;
        }
      }
    }

    // Aussi tenter les endpoints last/next
    for (final endpoint in ['events/last/0', 'events/next/0']) {
      final data = await _fetchJson(
          '/unique-tournament/$_utId/season/$_seasonId2026/$endpoint');
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
  static Future<Map<String, dynamic>?> fetchMatchDetails(int matchId) async {
    final results = await Future.wait([
      _fetchJson('/event/$matchId'),
      _fetchJson('/event/$matchId/lineups'),
      _fetchJson('/event/$matchId/incidents'),
      _fetchJson('/event/$matchId/statistics'),
    ]);

    final eventData = results[0];
    if (eventData == null) return null;

    final event = eventData['event'] ?? eventData;
    final lineups = results[1];
    final incidents = results[2];
    final statistics = results[3];

    final ht = event['homeTeam'] ?? {};
    final at = event['awayTeam'] ?? {};
    final hs = event['homeScore'] ?? {};
    final as_ = event['awayScore'] ?? {};
    final status = event['status'] ?? {};
    final statusType = status['type'] ?? '';

    String shortStatus;
    if (statusType == 'inprogress') {
      shortStatus = 'LIVE';
    } else if (statusType == 'finished') {
      shortStatus = 'FT';
    } else {
      shortStatus = 'NS';
    }

    // Parser les incidents (buts, cartons, remplacements)
    final incidentsList = <Map<String, dynamic>>[];
    if (incidents != null && incidents['incidents'] != null) {
      for (final inc in incidents['incidents'] as List) {
        incidentsList.add({
          'type': inc['incidentType'],
          'time': inc['time'],
          'addedTime': inc['addedTime'],
          'isHome': inc['isHome'],
          'player': {
            'id': inc['player']?['id'],
            'name': inc['player']?['name'],
          },
          'assist1': inc['assist1']?['name'],
          'incidentClass': inc['incidentClass'],
          'description': inc['description'],
          'playerIn': inc['playerIn'] != null
              ? {'id': inc['playerIn']['id'], 'name': inc['playerIn']['name']}
              : null,
          'playerOut': inc['playerOut'] != null
              ? {
                  'id': inc['playerOut']['id'],
                  'name': inc['playerOut']['name']
                }
              : null,
        });
      }
    }

    // Parser les stats
    final statsList = <Map<String, dynamic>>[];
    if (statistics != null && statistics['statistics'] != null) {
      for (final period in statistics['statistics'] as List) {
        for (final group in (period['groups'] ?? []) as List) {
          for (final item in (group['statisticsItems'] ?? []) as List) {
            statsList.add({
              'name': item['name'],
              'home': item['home'],
              'away': item['away'],
              'period': period['period'],
            });
          }
        }
      }
    }

    // Parser les compositions
    Map<String, dynamic>? formattedLineups;
    if (lineups != null) {
      formattedLineups = {
        'home': _parseLineup(lineups['home'] ?? {}, ht),
        'away': _parseLineup(lineups['away'] ?? {}, at),
      };
    }

    return {
      'response': {
        'fixture': {
          'id': event['id'],
          'date': event['startTimestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                      (event['startTimestamp'] as int) * 1000)
                  .toIso8601String()
              : '',
          'status': {
            'short': shortStatus,
            'long': status['description'] ?? '',
            'elapsed': status['currentMinute'],
          },
          'venue': event['venue'] != null
              ? {
                  'name': event['venue']['stadium']?['name'] ??
                      event['venue']['city']?['name'] ??
                      '',
                  'city': event['venue']['city']?['name'] ?? '',
                }
              : null,
        },
        'teams': {
          'home': {
            'id': ht['id'],
            'name': ht['name'],
            'logo':
                'https://api.sofascore.app/api/v1/team/${ht['id']}/image',
          },
          'away': {
            'id': at['id'],
            'name': at['name'],
            'logo':
                'https://api.sofascore.app/api/v1/team/${at['id']}/image',
          },
        },
        'goals': {
          'home': hs['current'] ?? hs['display'],
          'away': as_['current'] ?? as_['display'],
        },
        'score': {
          'halftime': {
            'home': hs['period1'],
            'away': as_['period1'],
          },
          'fulltime': {
            'home': hs['current'] ?? hs['normaltime'],
            'away': as_['current'] ?? as_['normaltime'],
          },
          'penalty': {
            'home': hs['penalties'],
            'away': as_['penalties'],
          },
        },
        'events': incidentsList,
        'statistics': statsList,
        'lineups': formattedLineups,
      },
    };
  }

  static Map<String, dynamic> _parseLineup(
      Map<String, dynamic> lineupData, Map<String, dynamic> team) {
    final players = <Map<String, dynamic>>[];
    for (final p in (lineupData['players'] ?? []) as List) {
      final player = p['player'] ?? {};
      final stats = p['statistics'] ?? {};
      players.add({
        'player': {
          'id': player['id'],
          'name': player['name'],
          'number': player['shirtNumber'] ?? p['shirtNumber'],
          'pos': player['position'] ?? p['position'],
          'grid': p['position'],
        },
        'statistics': stats,
        'substitute': p['substitute'] ?? false,
      });
    }
    return {
      'team': {
        'id': team['id'],
        'name': team['name'],
        'logo':
            'https://api.sofascore.app/api/v1/team/${team['id']}/image',
      },
      'formation': lineupData['formation'],
      'startXI': players.where((p) => p['substitute'] != true).toList(),
      'substitutes': players.where((p) => p['substitute'] == true).toList(),
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
}
