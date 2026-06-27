import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/live_match.dart';
import '../models/match_details.dart';
import '../models/standings.dart';
import '../models/top_scorer.dart';
import '../models/match_news.dart';
import '../utils/country_flags.dart';
import '../utils/lang_utils.dart';

class Scores365Service {
  static const int wcCompetitionId = 5930;

  static const String baseUrl = 'https://webws.365scores.com/web';

  static String get baseParams =>
      'appTypeId=5&langId=${LangUtils.scores365LangCode}&timezoneName=Europe%2FParis&userCountryId=135';

  static Map<String, String> _headers() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'Origin': 'https://www.365scores.com',
      'Referer': 'https://www.365scores.com/',
    };
  }

  static Future<Map<String, dynamic>?> _fetchJson(String path) async {
    final url = '$baseUrl/$path';
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      } else {
        debugPrint('[365Scores] Error ${response.statusCode} for $url');
      }
    } catch (e) {
      debugPrint('[365Scores] Request failed: $e');
    }
    return null;
  }

  // ============================================================
  //  MATCHS (Live & Fixtures)
  // ============================================================

  static Future<List<LiveMatch>> fetchLiveMatches() async {
    final data = await _fetchJson(
      'games/current/?$baseParams&competitions=$wcCompetitionId&showOdds=true',
    );
    if (data == null || data['games'] == null) return [];

    final games = data['games'] as List;
    final List<LiveMatch> liveMatches = [];

    for (final g in games) {
      final statusGroup = g['statusGroup'];
      if (statusGroup == 3) {
        liveMatches.add(_mapToLiveMatch(g));
      }
    }
    return liveMatches;
  }

  static Future<List<LiveMatch>> fetchFixtures(int year) async {
    String endpoint = 'games/?$baseParams&competitions=$wcCompetitionId';
    if (year == 2026) {
      endpoint += '&startDate=11/06/2026&endDate=19/07/2026';
    } else if (year == 2022) {
      endpoint += '&seasonNum=24';
    }
    
    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];

    final games = data['games'] as List;
    return games.map((g) => _mapToLiveMatch(g)).toList();
  }

  static LiveMatch _mapToLiveMatch(Map<String, dynamic> g) {
    final home = g['homeCompetitor'] ?? {};
    final away = g['awayCompetitor'] ?? {};

    final statusGroup = g['statusGroup'] ?? 1;
    final isLive = statusGroup == 3;
    final isFinished = statusGroup == 4;

    String shortStatus = 'NS';
    if (isFinished) {
      shortStatus = 'FT';
    } else if (isLive)
      shortStatus = 'LIVE';

    String? matchMinute;
    if (isLive) {
      matchMinute = '${g['gameTime']?.toInt() ?? ''}\'';
      if (g['shortStatusText'] == 'HT' || 
          g['shortStatusText'] == 'Mi-temps' || 
          g['statusText'] == 'Mi-temps' || 
          g['statusText'] == 'HT') {
        matchMinute = 'HT';
      }
    }

    DateTime dt = DateTime.now();
    if (g['startTime'] != null) {
      String st = g['startTime'].toString();
      // On s'assure que la chaîne est traitée comme UTC si elle n'a pas de fuseau
      if (!st.endsWith('Z') && !st.contains('+') && !st.contains('-')) {
        st += 'Z';
      }
      // .toLocal() convertit AUTOMATIQUEMENT vers le fuseau horaire du téléphone (Belgique, Australie, etc.)
      dt = DateTime.parse(st).toLocal();
    }

    final teamHomeName = _cleanTeamName(home['name']);
    final teamAwayName = _cleanTeamName(away['name']);

    return LiveMatch(
      id: g['id']?.toString() ?? '',
      dateLabel:
          '${dt.day.toString().padLeft(2, '0')} ${_getMonthName(dt.month)} ${dt.year}',
      localTime:
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      city: g['venue']?['name']?.toString() ?? 'Stade',
      homeTeam: teamHomeName,
      homeCode: _getTeamCode(teamHomeName),
      homeTeamId: home['id'],
      homeLogoUrl: null,
      awayTeam: teamAwayName,
      awayCode: _getTeamCode(teamAwayName),
      awayTeamId: away['id'],
      awayLogoUrl: null,
      phaseLabel: () {
        String phase = (g['groupName'] != null && g['groupName'].toString().isNotEmpty)
            ? g['groupName']
            : (g['roundName'] ?? g['stageName'] ?? 'World Cup');
        if (phase.toLowerCase().trim() == 'round') return 'Round of 32';
        return phase;
      }(),
      source: MatchDataSource.wc2026api,
      competitionId: g['competitionId'],
      scoreHome: home['score']?.toInt() == -1 ? null : home['score']?.toInt(),
      scoreAway: away['score']?.toInt() == -1 ? null : away['score']?.toInt(),
      isLive: isLive,
      dateTime: dt,
      statusShort: shortStatus,
      statusLong: g['statusText'] ?? '',
      matchMinute: matchMinute,
    );
  }

  static String _cleanTeamName(String? raw) {
    if (raw == null || raw.isEmpty) return 'TBD';
    return raw;
  }

  static String _getTeamCode(String teamName) {
    // Use ISO-2 country code resolution for correct flag display
    final iso2 = resolveCountryCode(teamName, fallback: '');
    if (iso2.isNotEmpty && iso2 != 'UN') return iso2;
    // Fallback: first 3 chars
    if (teamName.length < 3) return teamName.toUpperCase();
    return teamName.substring(0, 3).toUpperCase();
  }

  static String _getMonthName(int m) {
    switch (m) {
      case 1:
        return 'Jan';
      case 2:
        return 'Fév';
      case 3:
        return 'Mar';
      case 4:
        return 'Avr';
      case 5:
        return 'Mai';
      case 6:
        return 'Juin';
      case 7:
        return 'Juil';
      case 8:
        return 'Aoû';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Déc';
      default:
        return '';
    }
  }

  // ============================================================
  //  MATCH DETAILS (Stats, Incidents, Lineups)
  // ============================================================

  static Future<MatchDetails?> fetchMatchDetails(int matchId) async {
    final gameData = await _fetchJson('game/?$baseParams&gameId=$matchId');
    final statsData = await _fetchJson(
      'game/stats/?$baseParams&games=$matchId',
    );
    if (gameData == null || gameData['game'] == null) return null;

    return _mapToMatchDetails(gameData, statsData ?? {});
  }

  static MatchDetails _mapToMatchDetails(
    Map<String, dynamic> gameData,
    Map<String, dynamic> statsData,
  ) {
    final game = gameData['game'];
    final home = game['homeCompetitor'] ?? {};
    final away = game['awayCompetitor'] ?? {};

    final members = game['members'] as List? ?? [];
    final Map<int, Map<String, dynamic>> membersMap = {};
    for (var m in members) {
      if (m['id'] != null) membersMap[m['id']] = m;
    }

    List<Map<String, dynamic>> homeStarters = [];
    List<Map<String, dynamic>> homeSubs = [];
    List<Map<String, dynamic>> awayStarters = [];
    List<Map<String, dynamic>> awaySubs = [];

    void parseLineups(
      Map<String, dynamic> competitor,
      List<Map<String, dynamic>> starters,
      List<Map<String, dynamic>> subs,
    ) {
      final lineups = competitor['lineups'];
      if (lineups != null && lineups['members'] != null) {
        final lineupMembers = lineups['members'] as List;
        for (var lm in lineupMembers) {
          final posName = (lm['position']?['name'] ?? '').toString().toLowerCase();
          final isCoach = posName.contains('coach') || lm['status'] == 4;
          if (isCoach) continue;

          final memberId = lm['id'];
          final globalMember = membersMap[memberId] ?? {};
          final yard = lm['yardFormation'] as Map<String, dynamic>? ?? {};
          // yardFormation: fieldPosition 1=GK..., fieldLine 0-based line, fieldSide 0-100 (percent)
          final double xRel = (yard['fieldSide'] as num?)?.toDouble() ?? 50.0;
          final double line = (yard['fieldLine'] as num?)?.toDouble() ?? 0.0;
          final double yRel = 90.0 - (line * 15.0); // rough mapping
          final entry = {
            'player': {
              'id': globalMember['athleteId'] ?? memberId ?? 0,
              'name':
                  globalMember['name'] ?? globalMember['shortName'] ?? 'Joueur',
              'number': globalMember['jerseyNumber'] ?? 0,
              'pos': _map365Position(lm['position']?['id']),
            },
            // Removing raw x/y mapping because 365Scores yardFormation is inconsistent.
            // The UI will safely fallback to the perfect static `_formationCoordinates`.
            'x': null,
            'y': null,
            'ranking': lm['ranking'],
          };
          if (lm['status'] == 1) {
            starters.add(entry);
          } else {
            subs.add(entry);
          }
        }
      }
    }

    parseLineups(home, homeStarters, homeSubs);
    parseLineups(away, awayStarters, awaySubs);

    final events = game['events'] as List? ?? [];
    List<Map<String, dynamic>> parsedEvents = [];

    for (var ev in events) {
      final typeId = ev['eventType']?['id'] ?? 0;
      final typeName = ev['eventType']?['name']?.toString() ?? '';
      String type = '';
      String incidentClass = '';

      if (typeId == 1) {
        final subType =
            ev['eventType']?['subTypeName']?.toString().toLowerCase() ?? '';
        if (subType.contains('shootout') || ev['stageId'] == 5) {
          type = 'penaltyshootout';
          incidentClass = 'scored';
        } else {
          type = 'goal';
          if (subType.contains('penalty') || subType.contains('pénalty') || subType.contains('جزاء')) {
            incidentClass = 'penalty';
          } else if (subType.contains('own') || subType.contains('contre') || subType.contains('مرماه')) {
            incidentClass = 'own-goal';
          }
        }
      } else if (typeId == 2) {
        type = 'card';
        incidentClass = 'yellow';
      } else if (typeId == 3) {
        type = 'card';
        incidentClass = 'red';
      } else if (typeId == 10) {
        type = 'card';
        incidentClass = 'yellowred';
      } else if (typeId == 12) {
        type = 'woodwork';
        incidentClass = 'woodwork';
      } else if (typeId == 13) {
        type = 'penaltyshootout';
        incidentClass = 'missed';
      } else if (typeId == 14) {
        type = 'missedpenalty';
        incidentClass = 'missed';
      } else if (typeId == 1000) {
        type = 'substitution';
      } else if (typeName.toLowerCase().contains('var')) {
        type = 'var';
      } else if (typeName.toLowerCase().contains('miss') &&
          typeName.toLowerCase().contains('penalty')) {
        type = 'penaltyshootout';
        incidentClass = 'missed';
      }

      if (type.isNotEmpty) {
        int? actualTeamId = ev['competitorId'];
        final globalPlayer = membersMap[ev['playerId']];
        if (globalPlayer != null && globalPlayer['competitorId'] != null) {
          actualTeamId = globalPlayer['competitorId'];
        }
        final isHome = actualTeamId == home['id'];

        String? assistName;
        if (type == 'goal' &&
            ev['extraPlayers'] != null &&
            ev['extraPlayers'].isNotEmpty) {
          assistName = membersMap[ev['extraPlayers'][0]]?['name'];
        }

        String? playerInName;
        if (type == 'substitution' &&
            ev['extraPlayers'] != null &&
            ev['extraPlayers'].isNotEmpty) {
          playerInName =
              membersMap[ev['extraPlayers'][0]]?['name'] ??
              membersMap[ev['extraPlayers'][0]]?['shortName'];
        }

        final mainPlayerName =
            membersMap[ev['playerId']]?['name'] ?? ev['playerName'] ?? 'Joueur';
        final displayTime =
            ev['gameTimeDisplay']?.toString() ??
            "${ev['gameTime']?.toInt() ?? 0}'";

        parsedEvents.add({
          'displayTime': displayTime,
          'time': {
            'elapsed': ev['gameTime']?.toInt() ?? 0,
            'extra': ev['addedTime']?.toInt(),
          },
          'team': {
            'id': isHome ? home['id'] : away['id'],
            'name': isHome ? home['name'] : away['name'],
            'logo': isHome
                ? (home['nameCode'] ?? home['name'] ?? '')
                : (away['nameCode'] ?? away['name'] ?? ''),
          },
          'type': type,
          'incidentClass': incidentClass,
          'player': type != 'substitution'
              ? {
                  'name': mainPlayerName,
                  'id':
                      membersMap[ev['playerId']]?['athleteId'] ??
                      ev['playerId'] ??
                      0,
                }
              : null,
          'playerIn': type == 'substitution'
              ? {'name': playerInName ?? 'Entrant'}
              : null,
          'playerOut': type == 'substitution' ? {'name': mainPlayerName} : null,
          'assist': assistName != null ? {'name': assistName} : null,
          'isHome': isHome,
        });
      }
    }

    final List<Map<String, dynamic>> mappedStats = [];
    if (statsData['statistics'] != null) {
      final rawStats = statsData['statistics'] as List;
      final Map<int, Map<String, dynamic>> groupedStats = {};

      for (var s in rawStats) {
        final statId = s['id'] as int;
        final name = s['name']?.toString() ?? 'Stat';
        final compId = s['competitorId'] as int?;
        final value = s['value']?.toString() ?? '0';

        if (!groupedStats.containsKey(statId)) {
          groupedStats[statId] = {
            'name': name,
            'homeValue': '0',
            'awayValue': '0',
          };
        }

        if (compId == home['id']) {
          groupedStats[statId]!['homeValue'] = value;
        } else if (compId == away['id']) {
          groupedStats[statId]!['awayValue'] = value;
        }
      }

      groupedStats.forEach((key, statMap) {
        mappedStats.add({
          'type': statMap['name'],
          'home': statMap['homeValue'],
          'away': statMap['awayValue'],
        });
      });
    }

    String refereeName = 'Arbitre inconnu';
    final officials = game['officials'] as List? ?? [];
    if (officials.isNotEmpty) {
      // roleId 1 = referee, but if not present just take the first official
      final ref = officials.firstWhere(
        (o) => o['roleId'] == 1,
        orElse: () => officials.first,
      );
      refereeName = ref['name']?.toString() ?? refereeName;
      // Clean parenthetical nationality suffix (e.g. "Wilton Sampaio (Brazil)")
      final parenIdx = refereeName.indexOf('(');
      if (parenIdx > 0) refereeName = refereeName.substring(0, parenIdx).trim();
    }

    String homeCoach = 'Inconnu';
    String awayCoach = 'Inconnu';
    // Coach is at the end of lineups members with status != 1 and position name containing 'coach'
    for (var competitor in [home, away]) {
      final lineupMembers = (competitor['lineups']?['members'] as List? ?? []);
      for (var lm in lineupMembers) {
        final posName = (lm['position']?['name'] ?? '')
            .toString()
            .toLowerCase();
        if (posName.contains('coach') || lm['status'] == 4) {
          final memberId = lm['id'];
          final globalMember = membersMap[memberId] ?? {};
          final coachName = globalMember['name'] ?? globalMember['shortName'];
          if (coachName != null) {
            final dobStr = globalMember['dateOfBirth'] ?? globalMember['birthDate'];
            String ageStr = '';
            if (dobStr != null) {
              try {
                final dob = DateTime.parse(dobStr.toString());
                int age = DateTime.now().year - dob.year;
                if (DateTime.now().month < dob.month || (DateTime.now().month == dob.month && DateTime.now().day < dob.day)) {
                  age--;
                }
                ageStr = ' ($age ans)';
              } catch (_) {}
            } else if (globalMember['age'] != null) {
              ageStr = ' (${globalMember['age']} ans)';
            }
            final finalCoach = '$coachName$ageStr';

            if (competitor['id'] == home['id']) {
              homeCoach = finalCoach;
            } else {
              awayCoach = finalCoach;
            }
          }
        }
      }
    }

    // Fallback: search by jerseyNumber == -1 in root members (old format)
    if (homeCoach == 'Inconnu' || awayCoach == 'Inconnu') {
      for (var m in members) {
        if (m['jerseyNumber'] == -1) {
          final dobStr = m['dateOfBirth'] ?? m['birthDate'];
          String ageStr = '';
          if (dobStr != null) {
            try {
              final dob = DateTime.parse(dobStr.toString());
              int age = DateTime.now().year - dob.year;
              if (DateTime.now().month < dob.month || (DateTime.now().month == dob.month && DateTime.now().day < dob.day)) age--;
              ageStr = ' ($age ans)';
            } catch (_) {}
          } else if (m['age'] != null) {
            ageStr = ' (${m['age']} ans)';
          }
          final coachName = m['name'] ?? m['shortName'] ?? 'Inconnu';
          final finalCoach = coachName != 'Inconnu' ? '$coachName$ageStr' : 'Inconnu';

          if (m['competitorId'] == home['id'] && homeCoach == 'Inconnu') {
            homeCoach = finalCoach;
          } else if (m['competitorId'] == away['id'] && awayCoach == 'Inconnu') {
            awayCoach = finalCoach;
          }
        }
      }
    }

    // Formation is a direct string in 365scores API (e.g. "4-3-3")
    String homeFormation = home['lineups']?['formation']?.toString() ?? 'N/A';
    String awayFormation = away['lineups']?['formation']?.toString() ?? 'N/A';
    // Legacy fallback: was previously an array
    if (homeFormation == '[' || homeFormation.startsWith('['))
      homeFormation = 'N/A';
    if (awayFormation == '[' || awayFormation.startsWith('['))
      awayFormation = 'N/A';

    return MatchDetails.fromApi({
      'fixture': {
        'id': game['id'],
        'status': {
          'long': game['statusText'] ?? 'N/A',
          'elapsed': game['gameTime'] ?? 0,
        },
        'date': game['startTime'] ?? '',
        'referee': refereeName,
        'venue': {
          'name': game['venue']?['name'] ?? 'Stade inconnu',
          'city': '',
        },
      },
      'teams': {
        'home': {
          'id': home['id'],
          'name': home['name'],
          'logo':
              'https://imagecache.365scores.com/image/upload/f_png,w_48,h_48,c_limit,q_auto:eco,dpr_3,d_Competitors:default1.png/v3/Competitors/${home['id']}',
        },
        'away': {
          'id': away['id'],
          'name': away['name'],
          'logo':
              'https://imagecache.365scores.com/image/upload/f_png,w_48,h_48,c_limit,q_auto:eco,dpr_3,d_Competitors:default1.png/v3/Competitors/${away['id']}',
        },
      },
      'goals': {
        'home': home['score']?.toInt() ?? 0,
        'away': away['score']?.toInt() ?? 0,
      },
      'lineups': [
        {
          'team': {
            'id': home['id'],
            'name': home['name'],
            'nameCode': home['nameCode'] ?? home['id'].toString(),
            'colors': {
              'player': {'primary': home['color'] ?? 'FFFFFF'},
            },
          },
          'formation': homeFormation,
          'coach': {'name': homeCoach},
          'startXI': homeStarters,
          'substitutes': homeSubs,
        },
        {
          'team': {
            'id': away['id'],
            'name': away['name'],
            'nameCode': away['nameCode'] ?? away['id'].toString(),
            'colors': {
              'player': {'primary': away['color'] ?? 'FFFFFF'},
            },
          },
          'formation': awayFormation,
          'coach': {'name': awayCoach},
          'startXI': awayStarters,
          'substitutes': awaySubs,
          'color': away['color'] ?? '003399',
        },
      ],
      'events': parsedEvents,
      'statistics': mappedStats,
    });
  }


  // ============================================================
  //  STANDINGS
  // ============================================================

  static Future<List<GroupStanding>> fetchStandings(int year) async {
    String endpoint = 'standings/?$baseParams&competitions=$wcCompetitionId&live=true';
    if (year == 2022) {
      endpoint += '&seasonNum=24';
    }
    final data = await _fetchJson(endpoint);
    if (data == null || data['standings'] == null) return [];

    final standings = data['standings'] as List;
    if (standings.isEmpty) return [];

    final rows = standings[0]['rows'] as List? ?? [];
    if (rows.isEmpty) return [];

    final Map<int, List<dynamic>> groupedRows = {};
    for (var r in rows) {
      final gNum = r['groupNum'] as int? ?? 1;
      groupedRows.putIfAbsent(gNum, () => []);
      groupedRows[gNum]!.add(r);
    }

    final List<GroupStanding> groups = [];

    groupedRows.forEach((groupNum, groupRows) {
      final groupName = 'Group ${String.fromCharCode(64 + groupNum)}';

      final teams = groupRows.map((r) {
        final comp = r['competitor'] ?? {};
        return StandingTeam.fromApi({
          'team': {'id': comp['id'], 'name': comp['name']},
          'rank': r['position']?.toInt(),
          'points': r['points']?.toInt(),
          'isQualified': comp['isQualified'],
          'toQualify': comp['toQualify'],
          'all': {
            'played': r['gamePlayed']?.toInt() ?? 0,
            'win': r['gamesWon']?.toInt() ?? 0,
            'draw': r['gamesEven']?.toInt() ?? 0,
            'lose': r['gamesLost']?.toInt() ?? 0,
            'goals': {
              'for': r['for']?.toInt() ?? 0,
              'against': r['against']?.toInt() ?? 0,
            },
          },
          'goalsDiff': r['ratio']?.toInt() ?? 0,
        });
      }).toList();

      groups.add(
        GroupStanding(groupName: groupName, teams: teams.cast<StandingTeam>()),
      );
    });

    return groups;
  }

  // ============================================================
  //  STUB METHODS
  // ============================================================

  static Future<Map<String, dynamic>?> fetchTeamCoach(int resolvedId) async {
    try {
      final result = await _fetchSquadData(resolvedId);
      return result['coach'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('fetchTeamCoach error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchTournamentSquad(
    int resolvedId,
    int seasonId,
  ) async {
    return fetchTeamSquad(resolvedId);
  }

  static Future<List<Map<String, dynamic>>> fetchTeamSquad(
    int resolvedId,
  ) async {
    try {
      final result = await _fetchSquadData(resolvedId);
      return (result['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('fetchTeamSquad error: $e');
      return [];
    }
  }

  /// Shared method: one API call for both coach + players
  static final Map<int, Future<Map<String, dynamic>>> _squadCache = {};

  static Future<Map<String, dynamic>> _fetchSquadData(int resolvedId) async {
    if (_squadCache.containsKey(resolvedId)) {
      return _squadCache[resolvedId]!;
    }
    final future = _doFetchSquadData(resolvedId);
    _squadCache[resolvedId] = future;
    // Remove from cache after 60 seconds
    future.whenComplete(() {
      Future.delayed(const Duration(seconds: 60), () {
        _squadCache.remove(resolvedId);
      });
    });
    return future;
  }

  static Future<Map<String, dynamic>> _doFetchSquadData(int resolvedId) async {
    final url = 'squads/?competitors=$resolvedId&$baseParams';
    final data = await _fetchJson(url);
    if (data == null) return {'coach': null, 'players': <Map<String, dynamic>>[]};

    final squads = data['squads'] as List?;
    if (squads == null || squads.isEmpty) return {'coach': null, 'players': <Map<String, dynamic>>[]};

    final athletes = squads[0]['athletes'] as List?;
    if (athletes == null || athletes.isEmpty) return {'coach': null, 'players': <Map<String, dynamic>>[]};

    Map<String, dynamic>? coachData;
    final List<Map<String, dynamic>> playersList = [];

    for (final athlete in athletes) {
      final formPos = athlete['formationPosition'];
      final formPosName = formPos?['name']?.toString().toLowerCase() ?? '';
      final posName = athlete['position']?['name']?.toString() ?? '';
      final imgVer = athlete['imageVersion'] ?? 1;
      final photoUrl = 'https://imagecache.365scores.com/image/upload/f_auto,q_auto,c_fill,w_300,h_300/v$imgVer/Athletes/${athlete['id']}';

      // Skip coaches and staff (coach, assistant coach, manager, etc.)
      if (formPosName.contains('coach') || formPosName == 'manager' || formPos?['id'] == 16 || formPos?['id'] == 17) {
        // Only record the head coach (id=16), not assistants (id=17)
        if ((formPosName == 'coach' || formPosName == 'head coach' || formPos?['id'] == 16) && coachData == null) {
          coachData = {
            'id': athlete['id'],
            'name': athlete['name'],
            'nationality': athlete['nationalityName'] ?? '',
            'nationalityId': athlete['nationalityId'],
            'photo': photoUrl,
          };
        }
        continue; // Don't add any staff to player list
      }

      // Resolve position: prefer position.id (most reliable), then name, then formationPosition
      final posId = athlete['position']?['id'] as int?;
      String resolvedPos;
      if (posId != null && posId > 0) {
        resolvedPos = _map365Position(posId);
      } else {
        resolvedPos = posName.isNotEmpty ? _mapPositionName(posName) : _mapPositionName(formPosName);
      }

      playersList.add({
        'id': athlete['id'],
        'name': athlete['name'],
        'shirtNumber': athlete['jerseyNum'],
        'position': resolvedPos,
        'photo': photoUrl,
        'age': athlete['age'],
      });
    }

    return {'coach': coachData, 'players': playersList};
  }

  /// Map full position names to short codes used in the app
  static String _mapPositionName(String name) {
    final lower = name.toLowerCase();
    if (lower == 'goalkeeper') return 'G';
    if (lower == 'defender' || lower == 'centre back' || lower == 'left back' || lower == 'right back') return 'D';
    if (lower == 'midfielder' || lower == 'central midfielder' || lower == 'defensive midfielder' || lower == 'attacking midfielder') return 'M';
    if (lower == 'forward' || lower == 'striker' || lower == 'left winger' || lower == 'right winger') return 'F';
    // Already a short code
    if (['G', 'D', 'M', 'F'].contains(name)) return name;
    return _map365Position(int.tryParse(name));
  }

  static String _map365Position(int? posId) {
    if (posId == null) return 'M';
    if (posId == 1) return 'G';
    if (posId == 2) return 'D';
    if (posId == 3) return 'M';
    if (posId == 4) return 'F';
    return 'M';
  }


  static Future<Map<String, dynamic>?> fetchPlayerNationalStats(
    int playerId,
  ) async => null;
  static Future<Map<String, dynamic>?> fetchPlayerCharacteristics(
    int playerId,
  ) async => null;
  static Future<Map<String, dynamic>?> fetchPlayerAttributes(
    int playerId,
  ) async => null;
  static Future<Map<String, dynamic>?> fetchPlayerStats(
    int playerId,
    int seasonId,
  ) async {
    final url = 'athletes/?$baseParams&athletes=$playerId';
    final data = await _fetchJson(url);
    if (data == null ||
        data['athletes'] == null ||
        (data['athletes'] as List).isEmpty) return null;
    final athlete = data['athletes'][0];

    return {
      'characteristics': {
        'preferredFoot': athlete['preferredFoot'] ?? '',
        'height': athlete['height'] ?? 0,
        'weight': athlete['weight'] ?? 0,
        'position': athlete['position']?['name'] ?? '',
        'shirtNumber': athlete['jerseyNum'] ?? 0,
      },
      'attributes': {
        'age': athlete['age'] ?? 0,
        'nationality': athlete['nationalityName'] ?? '',
      },
      'nationalStats': {},
      'tournamentStats': {},
    };
  }

  static Future<List<TopScorer>> fetchTopScorers(int year, int competitionId) async {
    String url = 'stats/?$baseParams&competitions=$competitionId';
    if (year == 2022) {
      url += '&seasonNum=24';
    }
    final data = await _fetchJson(url);
    if (data == null || data['stats'] == null) return [];

    final stats = data['stats'];
    if (stats is! Map || stats['athletesStats'] == null) return [];

    final athletesStats = stats['athletesStats'] as List;
    if (athletesStats.isEmpty) return [];

    // "Goals" is usually the first category (id: 1)
    final goalsCategory = athletesStats.firstWhere(
      (cat) => cat['name'] == 'Goals' || cat['id'] == 1,
      orElse: () => null,
    );

    if (goalsCategory == null || goalsCategory['rows'] == null) return [];

    final rows = goalsCategory['rows'] as List;
    return rows.map((row) => TopScorer.fromJson(row)).toList();
  }

  static Future<List<MatchNews>> fetchMatchNews(int matchId) async {
    final url = 'news/?$baseParams&gameId=$matchId';
    final data = await _fetchJson(url);
    if (data == null || data['news'] == null) return [];

    // Parse newsSources to map
    final Map<int, String> sourcesMap = {};
    if (data['newsSources'] != null) {
      for (final source in data['newsSources']) {
        sourcesMap[source['id']] = source['name'];
      }
    }

    final newsList = data['news'] as List;
    return newsList.map((item) => MatchNews.fromJson(item, sourcesMap)).toList();
  }
}
