import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  // ── Client HTTP persistant (keep-alive + connexions réutilisées) ──────────
  // Une seule connexion TLS est établie pour toutes les requêtes 365scores,
  // économisant ~300ms de handshake par appel.
  static final http.Client _client = http.Client();

  static Map<String, String> _headers() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      // ✅ Fix 1 — Activer la compression gzip : réduit la taille des réponses de ~10x
      // (ex: standings 245KB → 24KB, fixtures 207KB → 21KB)
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'fr-FR,fr;q=0.9',
      'Origin': 'https://www.365scores.com',
      'Referer': 'https://www.365scores.com/',
    };
  }

  // ── Fonction de décodage isolée (tourne dans un thread séparé) ───────────
  static Map<String, dynamic>? _decodeJson(List<int> bytes) {
    try {
      // Tenter la décompression gzip si nécessaire
      List<int> decoded;
      try {
        decoded = GZipCodec().decode(bytes);
      } catch (_) {
        decoded = bytes; // Déjà non compressé
      }
      final str = utf8.decode(decoded, allowMalformed: true);
      return jsonDecode(str) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchJson(String path) async {
    final url = '$baseUrl/$path';
    try {
      // ✅ Fix 4 — Utiliser le client persistant pour réutiliser la connexion TLS
      final response = await _client
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // ✅ Fix 2 — Parser le JSON dans un Isolate séparé pour ne pas bloquer l'UI
        // Critique pour les gros payloads (207KB fixtures, 245KB standings)
        return await compute(_decodeJson, response.bodyBytes);
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

  // ============================================================
  //  MÉTHODES GÉNÉRIQUES — Multi-compétitions
  // ============================================================

  /// Fetch les matchs d'une compétition quelconque sur une plage de dates.
  static Future<List<LiveMatch>> fetchMatchesByCompetition({
    required int competitionId,
    String? startDate,
    String? endDate,
    String? competitionName,
  }) async {
    String endpoint = 'games/current/?$baseParams&competitions=$competitionId';
    if (startDate != null && endDate != null) {
      endpoint += '&startDate=$startDate&endDate=$endDate';
    }
    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];
    final games = data['games'] as List;
    return games.map((g) {
      final m = _mapToLiveMatch(g);
      return m.copyWithCompetitionInfo(
        competitionId: competitionId,
        competitionName: competitionName ??
            (g['competitionDisplayName']?.toString() ?? ''),
      );
    }).toList();
  }

  static Future<List<LiveMatch>> fetchAllMatchesForCompetition({
    required int competitionId,
    String? competitionName,
  }) async {
    // results = terminés, current = en cours + à venir, fixtures = programmés.
    // Les 3 sont nécessaires : pour un tournoi en cours, les matchs à venir
    // ne sont QUE dans current ; pour un tournoi passé, tout est dans results.
    final results = await Future.wait([
      _fetchJson('games/results/?$baseParams&competitions=$competitionId'),
      _fetchJson('games/current/?$baseParams&competitions=$competitionId'),
      _fetchJson('games/fixtures/?$baseParams&competitions=$competitionId'),
    ]);
    final allGames = <dynamic>[];
    for (final data in results) {
      if (data != null && data['games'] != null) {
        allGames.addAll(data['games'] as List);
      }
    }
    
    final Map<String, LiveMatch> uniqueMatches = {};
    for (final g in allGames) {
      final m = _mapToLiveMatch(g).copyWithCompetitionInfo(
        competitionId: competitionId,
        competitionName: competitionName ?? (g['competitionDisplayName']?.toString() ?? ''),
      );
      uniqueMatches[m.id] = m;
    }
    
    return uniqueMatches.values.toList();
  }

  static Future<List<LiveMatch>> fetchMatchesForMultipleCompetitions({
    required List<int> competitionIds,
    String? startDate,
    String? endDate,
  }) async {
    final compString = competitionIds.join(',');
    String endpoint = 'games/?$baseParams&competitions=$compString';
    if (startDate != null && endDate != null) {
      endpoint += '&startDate=$startDate&endDate=$endDate';
    }
    final data = await _fetchJson(endpoint);
    if (data == null || data['games'] == null) return [];
    final games = data['games'] as List;
    return games.map((g) => _mapToLiveMatch(g)).toList();
  }

  /// Récupère l'arbre du tournoi (Brackets)
  static Future<Map<String, dynamic>?> fetchBracketsByCompetition(
      int competitionId) async {
    final data = await _fetchJson(
      'brackets/?$baseParams&competitions=$competitionId',
    );
    if (data == null || data['brackets'] == null) return null;
    return data;
  }

  /// Fetch les matchs live d'une compétition quelconque.
  static Future<List<LiveMatch>> fetchLiveMatchesByCompetition(
      int competitionId) async {
    final data = await _fetchJson(
      'games/current/?$baseParams&competitions=$competitionId&showOdds=true',
    );
    if (data == null || data['games'] == null) return [];
    final games = data['games'] as List;
    return games
        .where((g) => (g['statusGroup'] as int? ?? 0) == 3)
        .map((g) => _mapToLiveMatch(g).copyWithCompetitionInfo(
              competitionId: competitionId,
              competitionName: g['competitionDisplayName']?.toString() ?? '',
            ))
        .toList();
  }

  /// Fetch les classements d'une compétition quelconque.
  static Future<List<GroupStanding>> fetchStandingsByCompetition(
      int competitionId) async {
    final data = await _fetchJson(
      'standings/?$baseParams&competitions=$competitionId&live=true',
    );
    if (data == null || data['standings'] == null) return [];
    // Vrais noms de groupes fournis par l'API (ex: Group A..D).
    final Map<int, String> groupNames = {};
    final standings = data['standings'] as List? ?? [];
    if (standings.isNotEmpty && standings[0] is Map) {
      for (final gr in (standings[0]['groups'] as List? ?? [])) {
        if (gr is Map) {
          final gNum = (gr['num'] as num?)?.toInt();
          final name = gr['name']?.toString();
          if (gNum != null && name != null && name.isNotEmpty) {
            groupNames[gNum] = name;
          }
        }
      }
    }
    return _extractGroupStandings(data, groupNames: groupNames);
  }

  /// Fetch les buteurs d'une compétition quelconque.
  /// Endpoint réel : `stats/` (le `stats/players/?statsId=3` renvoie 404).
  /// Fonctionne pour chaque tournoi via son competitionId.
  static Future<List<TopScorer>> fetchTopScorersByCompetition(
      int competitionId) async {
    final data = await _fetchJson(
      'stats/?$baseParams&competitions=$competitionId',
    );
    if (data == null) return [];
    return parseAthletesStats(data);
  }

  /// Extrait les classements groupés depuis la réponse API.
  /// [groupNames] : table num -> nom réel (ex: 1 -> "Group A").
  /// Les lignes SANS groupNum (tour de qualification : Somalia, Djibouti...)
  /// sont exclues des groupes — elles faussaient le Group A sinon.
  static List<GroupStanding> _extractGroupStandings(
      Map<String, dynamic> data,
      {Map<int, String>? groupNames}) {
    final standings = data['standings'] as List? ?? [];
    if (standings.isEmpty) return [];

    final rows = standings[0]['rows'] as List? ?? [];
    if (rows.isEmpty) return [];

    final Map<int, List<dynamic>> groupedRows = {};
    for (var r in rows) {
      final gNum = (r is Map) ? r['groupNum'] as int? : null;
      if (gNum == null) continue; // qualifications -> hors groupes
      groupedRows.putIfAbsent(gNum, () => []).add(r);
    }

    final List<GroupStanding> groups = [];
    groupedRows.forEach((groupNum, groupRows) {
      final groupName = groupNames?[groupNum] ??
          'Group ${String.fromCharCode(64 + groupNum)}';
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
          GroupStanding(groupName: groupName, teams: teams.cast<StandingTeam>()));
    });
    return groups;
  }

  /// Extrait les buteurs depuis la réponse `stats/` (format réel 365Scores).
  /// Structure : stats.athletesStats[] = catégories {id:1 Goals, id:3 Assists...},
  /// chaque row = {entity:{id,name,competitorId,imageVersion}, stats:[{typeId,value}]}.
  /// On fusionne Goals + Assists par entity.id et on résout le nom d'équipe
  /// via la table `competitors` de la réponse. Trié par buts décroissants.
  /// Public pour réutilisation / tests : fonctionne pour chaque competitionId.
  static List<TopScorer> parseAthletesStats(Map<String, dynamic> data) {
    final stats = data['stats'];
    if (stats is! Map || stats['athletesStats'] == null) return [];
    final categories = stats['athletesStats'] as List? ?? [];
    if (categories.isEmpty) return [];

    Map<String, dynamic>? findCategory(bool Function(Map<String, dynamic>) test) {
      for (final c in categories) {
        if (c is Map<String, dynamic> && test(c)) return c;
      }
      return null;
    }

    final goalsCat = findCategory(
        (c) => c['name'] == 'Goals' || c['id'] == 1);
    if (goalsCat == null || goalsCat['rows'] == null) return [];
    final assistsCat = findCategory(
        (c) => c['name'] == 'Assists' || c['id'] == 3);

    // Table competitors : id -> {name, symbolicName}
    final Map<int, Map<String, String>> teams = {};
    for (final comp in (data['competitors'] as List? ?? [])) {
      if (comp is Map) {
        final id = (comp['id'] as num?)?.toInt();
        if (id != null) {
          teams[id] = {
            'name': comp['name']?.toString() ?? '',
            'code': comp['symbolicName']?.toString() ?? '',
          };
        }
      }
    }

    // Assists par athleteId (fusion Goals + Assists)
    final Map<int, int> assistsByAthlete = {};
    for (final row in (assistsCat?['rows'] as List? ?? [])) {
      if (row is! Map) continue;
      final entity = row['entity'] as Map? ?? {};
      final aid = (entity['id'] as num?)?.toInt();
      if (aid == null) continue;
      int assists = 0;
      for (final s in (row['stats'] as List? ?? [])) {
        if (s is Map && s['typeId'] == 2) {
          final v = s['value'];
          assists = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
        }
      }
      assistsByAthlete[aid] = assists;
    }

    final List<TopScorer> scorers = [];
    for (final row in (goalsCat['rows'] as List? ?? [])) {
      if (row is! Map<String, dynamic>) continue;
      final entity = row['entity'] as Map? ?? {};
      final compId = (entity['competitorId'] as num?)?.toInt();
      final team = compId != null ? teams[compId] : null;
      final enriched = Map<String, dynamic>.from(row)
        ..['resolvedTeamName'] = team?['name'] ?? compId?.toString() ?? ''
        ..['resolvedTeamCode'] = team?['code'] ?? compId?.toString() ?? '';
      var scorer = TopScorer.fromJson(enriched);
      final aid = scorer.playerId;
      if (scorer.assists == 0 && assistsByAthlete.containsKey(aid)) {
        scorer = TopScorer(
          playerId: scorer.playerId,
          playerName: scorer.playerName,
          teamName: scorer.teamName,
          teamCode: scorer.teamCode,
          goals: scorer.goals,
          matches: scorer.matches,
          assists: assistsByAthlete[aid] ?? 0,
          photoUrl: scorer.photoUrl,
        );
      }
      if (scorer.playerName.isNotEmpty && scorer.goals > 0) {
        scorers.add(scorer);
      }
    }

    scorers.sort((a, b) {
      final g = b.goals.compareTo(a.goals);
      if (g != 0) return g;
      return b.assists.compareTo(a.assists);
    });
    for (int i = 0; i < scorers.length; i++) {
      scorers[i].rank = i + 1;
    }
    return scorers;
  }

  /// Extrait les buteurs depuis la réponse API (compat : délègue au parser réel).
  static List<TopScorer> _extractTopScorers(Map<String, dynamic> data) {
    return parseAthletesStats(data);
  }


  /// Fetch les métadonnées d'une compétition (nom, saisons, hasStandings...).
  static Future<Map<String, dynamic>?> fetchCompetitionMeta(
      int competitionId) async {
    final data = await _fetchJson(
      'competitions/?$baseParams&competitions=$competitionId&withSeasons=true&withBestOdds=true&isDashboard=true',
    );
    if (data == null) return null;
    final comps = data['competitions'] as List?;
    if (comps == null || comps.isEmpty) return null;
    return comps.first as Map<String, dynamic>?;
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
        // Use stageNum (like backend) for correct knockout round identification
        final stageNum = (g['stageNum'] as num?)?.toInt() ?? 0;
        final groupName = g['groupName']?.toString() ?? '';
        final roundNum = (g['roundNum'] as num?)?.toInt();
        final groupNum = (g['groupNum'] as num?)?.toInt();

        if (groupName.isNotEmpty) {
          return groupName; // Group Stage: "Group A", "Group B", etc.
        }

        // Certaines compétitions (ex: Arab Cup) ne renvoient pas groupName
        // pour la phase de groupes : repli sur groupNum (1->A, 2->B...).
        // Gardé aux stageNum 1-2 uniquement pour ne jamais étiqueter
        // un match à élimination directe comme match de groupe.
        if (groupNum != null &&
            groupNum >= 1 &&
            groupNum <= 26 &&
            stageNum <= 2) {
          return 'Group ${String.fromCharCode(64 + groupNum)}';
        }

        // Knockout stages based on stageNum (365Scores convention)
        switch (stageNum) {
          case 1:
            return roundNum != null ? 'Group Stage - $roundNum' : 'Group Stage';
          case 2:
            return 'Round of 32';
          case 3:
            return 'Round of 16';
          case 4:
            return 'Quarter-finals';
          case 5:
            return 'Semi-finals';
          case 6:
            return 'Final';
          default:
            // Fallback to roundName/stageName if stageNum not available
            final fallback = g['roundName'] ?? g['stageName'] ?? 'World Cup';
            if (fallback.toLowerCase().trim() == 'round') return 'Round of 32';
            return fallback;
        }
      }(),
      source: MatchDataSource.wc2026api,
      competitionId: g['competitionId'],
      scoreHome: home['score']?.toInt() == -1 ? null : home['score']?.toInt(),
      scoreAway: away['score']?.toInt() == -1 ? null : away['score']?.toInt(),
      penaltyHome: () {
        // 1. Try stages array — 365Scores WC2026 API has a "Penalties" stage
        //    with homeCompetitorScore / awayCompetitorScore
        final stages = g['stages'] as List? ?? [];
        for (final stage in stages) {
          final name = (stage['name']?.toString() ?? '').toLowerCase();
          if (name.contains('penalt') ||
              name.contains('tirs') ||
              name.contains('pênalt')) {
            final v = (stage['homeCompetitorScore'] as num?)?.toInt();
            if (v != null) return v;
          }
        }
        // 2. Fallback: penaltyScore field (singular — NOT penaltiesScore)
        final v = (home['penaltyScore'] as num?)?.toInt();
        return (v != null && v > 0) ? v : null;
      }(),
      penaltyAway: () {
        final stages = g['stages'] as List? ?? [];
        for (final stage in stages) {
          final name = (stage['name']?.toString() ?? '').toLowerCase();
          if (name.contains('penalt') ||
              name.contains('tirs') ||
              name.contains('pênalt')) {
            final v = (stage['awayCompetitorScore'] as num?)?.toInt();
            if (v != null) return v;
          }
        }
        final v = (away['penaltyScore'] as num?)?.toInt();
        return (v != null && v > 0) ? v : null;
      }(),
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
    // ✅ Fix 3 — Deux requêtes indépendantes lancées en parallèle (au lieu de séquentiel)
    // Gain : ~50% du temps de chargement des détails d'un match
    final results = await Future.wait([
      _fetchJson('game/?$baseParams&gameId=$matchId'),
      _fetchJson('game/stats/?$baseParams&games=$matchId'),
    ]);
    final gameData  = results[0];
    final statsData = results[1];
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

      // ── Penalty Shootout detection (365Scores WC2026) ──
      // stageId=11 = penalty shootout stage (confirmed from API analysis)
      // stageId=10 = extra time, stageId=9 = regular time
      bool isShootoutStage = ev['stageId'] == 11 || ev['stageId'] == '11';

      // Fallback: if statusText indicates penalties AND gameTime >= 120,
      // it's very likely a shootout event (WC2026 uses gameTime 121-125 for kicks)
      if (!isShootoutStage) {
        final statusTextLower = (game['statusText']?.toString() ?? '').toLowerCase();
        final gameTimeVal = (ev['gameTime'] as num?)?.toDouble() ?? 0;
        if ((statusTextLower.contains('penalties') ||
                statusTextLower.contains('tirs au but') ||
                statusTextLower.contains('après') ||
                statusTextLower.contains('pen')) &&
            gameTimeVal >= 120) {
          isShootoutStage = true;
        }
      }

      if (typeId == 1) {
        final subType =
            ev['eventType']?['subTypeName']?.toString().toLowerCase() ?? '';
        if (subType.contains('shootout') || isShootoutStage) {
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
      } else if (typeId == 6) {
        // typeId=6 = "Penalty Miss" — directly from 365Scores WC2026 API
        type = 'penaltyshootout';
        incidentClass = 'missed';
      } else if (typeId == 13 || (typeId == 14 && isShootoutStage)) {
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
        type = isShootoutStage ? 'penaltyshootout' : 'missedpenalty';
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

    // Post-process to robustly detect shootout sequence
    // A shootout sequence occurs when events with elapsed time 1, 2, 3.. appear AFTER events with elapsed time > 45
    bool inShootout = false;
    int maxElapsed = 0;
    for (var i = 0; i < parsedEvents.length; i++) {
      final ev = parsedEvents[i];
      final elapsed = ev['time']?['elapsed'] as int? ?? 0;
      
      if (elapsed > maxElapsed) {
        maxElapsed = elapsed;
      }
      
      // If we've advanced deep into the match (e.g. past half time) and time resets to <= 25
      if (maxElapsed >= 45 && elapsed <= 25) {
        inShootout = true;
      }

      if (inShootout) {
        if (ev['type'] == 'goal' || ev['incidentClass'] == 'penalty' || ev['type'] == 'penaltyshootout') {
           ev['type'] = 'penaltyshootout';
           ev['incidentClass'] = 'scored';
        } else if (ev['type'] == 'missedpenalty' || ev['incidentClass'] == 'missed') {
           ev['type'] = 'penaltyshootout';
           ev['incidentClass'] = 'missed';
        }
      }
    }

    // Calculate penalty score if it's a shootout
    int? calcPenaltyHome;
    int? calcPenaltyAway;
    for (var ev in parsedEvents) {
      if (ev['type'] == 'penaltyshootout' && ev['incidentClass'] == 'scored') {
        calcPenaltyHome ??= 0;
        calcPenaltyAway ??= 0;
        if (ev['isHome']) {
          calcPenaltyHome++;
        } else {
          calcPenaltyAway++;
        }
      }
    }
    // If we detected a shootout, ensure we have at least 0-0 for the UI to show the penalty score section
    final statusTextLower = (game['statusText']?.toString() ?? '').toLowerCase();
    final hasPenaltyStatus = statusTextLower.contains('penalties') ||
        statusTextLower.contains('tirs au but') ||
        statusTextLower.contains('after pen') ||   // "After Penalties" (EN 365Scores)
        statusTextLower.contains('pós-pên') ||      // Portuguese "Pós-pênaltis"
        statusTextLower.contains('pénalt') ||       // French variant
        statusTextLower.contains('penalt');         // General fallback
    if (calcPenaltyHome == null && hasPenaltyStatus) {
      calcPenaltyHome = 0;
      calcPenaltyAway = 0;
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
          'nameCode': home['nameCode']?.toString() ?? '',
          'logo':
              'https://imagecache.365scores.com/image/upload/f_png,w_48,h_48,c_limit,q_auto:eco,dpr_3,d_Competitors:default1.png/v3/Competitors/${home['id']}',
        },
        'away': {
          'id': away['id'],
          'name': away['name'],
          'nameCode': away['nameCode']?.toString() ?? '',
          'logo':
              'https://imagecache.365scores.com/image/upload/f_png,w_48,h_48,c_limit,q_auto:eco,dpr_3,d_Competitors:default1.png/v3/Competitors/${away['id']}',
        },
      },
      'goals': {
        'home': home['score']?.toInt() ?? 0,
        'away': away['score']?.toInt() ?? 0,
      },
      'score': {
        'penalty': {
          // Priority order for penalty scores (WC2026 365Scores):
          // 1. stages array: stageId=11 "Penalties" with homeCompetitorScore/awayCompetitorScore
          // 2. penaltyScore field (singular, not penaltiesScore) in homeCompetitor
          // 3. calcPenaltyHome calculated from stageId=11 events (typeId=1 = goal)
          'home': () {
            // 1. Stages array (most reliable — contains explicit penalty score)
            final stages = game['stages'] as List? ?? [];
            for (final stage in stages) {
              final name = (stage['name']?.toString() ?? '').toLowerCase();
              if (name.contains('penalt') ||
                  name.contains('tirs') ||
                  name.contains('pênalt')) {
                final v = (stage['homeCompetitorScore'] as num?)?.toInt();
                if (v != null) return v;
              }
            }
            // 2. penaltyScore field (singular — correct 365Scores field name)
            final fromApi = (home['penaltyScore'] as num?)?.toInt();
            if (fromApi != null && fromApi > 0) return fromApi;
            // 3. Calculated from stageId=11 events
            return calcPenaltyHome;
          }(),
          'away': () {
            final stages = game['stages'] as List? ?? [];
            for (final stage in stages) {
              final name = (stage['name']?.toString() ?? '').toLowerCase();
              if (name.contains('penalt') ||
                  name.contains('tirs') ||
                  name.contains('pênalt')) {
                final v = (stage['awayCompetitorScore'] as num?)?.toInt();
                if (v != null) return v;
              }
            }
            final fromApi = (away['penaltyScore'] as num?)?.toInt();
            if (fromApi != null && fromApi > 0) return fromApi;
            return calcPenaltyAway;
          }(),
        },
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

  /// Numéros de maillot réels (athleteId -> numéro).
  /// `squads/` renvoie -1 pour les sélections ; les vrais numéros sont dans
  /// `game.members[].jerseyNumber`. On lit le dernier match terminé de
  /// l'équipe dans la compétition (2 appels max, cachés par équipe).
  static final Map<String, Map<int, int>> _numbersCache = {};

  static Future<Map<int, int>> fetchShirtNumbers({
    required int teamCompetitorId,
    required int competitionId,
  }) async {
    final key = '${competitionId}_$teamCompetitorId';
    if (_numbersCache.containsKey(key)) return _numbersCache[key]!;
    try {
      final result = await _doFetchShirtNumbers(
        teamCompetitorId: teamCompetitorId,
        competitionId: competitionId,
      );
      _numbersCache[key] = result;
      return result;
    } catch (e) {
      debugPrint('fetchShirtNumbers error: $e');
      return {};
    }
  }

  static Future<Map<int, int>> _doFetchShirtNumbers({
    required int teamCompetitorId,
    required int competitionId,
  }) async {
    final data = await _fetchJson(
      'games/results/?$baseParams&competitions=$competitionId',
    );
    final games = data?['games'] as List? ?? [];

    bool involvesTeam(Map g) {
      final home = g['homeCompetitor'] as Map? ?? {};
      final away = g['awayCompetitor'] as Map? ?? {};
      return home['id'] == teamCompetitorId ||
          away['id'] == teamCompetitorId;
    }

    Map? best;
    // Passe 1 : terminé + compositions disponibles.
    for (final g in games) {
      if (g is! Map) continue;
      if (!involvesTeam(g)) continue;
      if ((g['statusGroup'] as num?)?.toInt() != 4) continue;
      if (g['hasLineups'] != true) continue;
      if (best == null ||
          (g['id'] as num? ?? 0) > (best['id'] as num? ?? 0)) {
        best = g;
      }
    }
    // Passe 2 : n'importe quel match terminé de l'équipe.
    if (best == null) {
      for (final g in games) {
        if (g is! Map) continue;
        if (!involvesTeam(g)) continue;
        if ((g['statusGroup'] as num?)?.toInt() != 4) continue;
        if (best == null ||
            (g['id'] as num? ?? 0) > (best['id'] as num? ?? 0)) {
          best = g;
        }
      }
    }
    if (best == null) return {};

    final game =
        await _fetchJson('game/?$baseParams&gameId=${best['id']}');
    final members =
        (game?['game'] as Map?)?['members'] as List? ?? [];
    final numbers = <int, int>{};
    for (final m in members) {
      if (m is! Map) continue;
      if (m['competitorId'] != teamCompetitorId) continue;
      final aid = (m['athleteId'] as num?)?.toInt();
      final jersey = (m['jerseyNumber'] as num?)?.toInt();
      if (aid != null && aid > 0 && jersey != null && jersey > 0) {
        numbers[aid] = jersey;
      }
    }
    return numbers;
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
        // L'API renvoie -1 quand le numéro est inconnu (toutes les
        // sélections) : null = masqué dans l'UI + trié en fin de liste.
        'shirtNumber':
            (athlete['jerseyNum'] == null || athlete['jerseyNum'] == -1)
                ? null
                : athlete['jerseyNum'],
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
    if (data == null) return [];
    // Parser unique : fusion Goals + Assists, résolution noms d'équipes.
    return parseAthletesStats(data);
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
