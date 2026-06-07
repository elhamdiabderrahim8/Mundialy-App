import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/live_match.dart';
import '../models/match_details.dart';
import '../models/standings.dart';
import '../models/team_player.dart';
import '../models/team_profile.dart';
import '../models/top_scorer.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../utils/country_flags.dart';
import '../utils/global_config.dart';
import '../main.dart';
import '../widgets/in_app_notification.dart';
import '../widgets/animated_goal_overlay.dart';
import 'sofa_direct_service.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry(this.data, this.timestamp);
  bool isExpired(int ttlMinutes) =>
      DateTime.now().difference(timestamp).inMinutes >= ttlMinutes;
}

class _MatchState {
  final int home;
  final int away;
  final String status;
  _MatchState(this.home, this.away, this.status);
}

class ApiService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Map<String, _MatchState> _matchStates = {};
  static final Map<String, _CacheEntry> _cache = {};
  static String? pinnedMatchId;

  static T? _getCache<T>(String key, {int ttlMinutes = 5}) {
    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (!entry.isExpired(ttlMinutes)) {
        return entry.data as T;
      } else {
        _cache.remove(key);
      }
    }
    return null;
  }

  static void _setCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data, DateTime.now());
  }

  static Future<void> initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const settings = InitializationSettings(android: android);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications.initialize(settings);

    const channel = AndroidNotificationChannel(
      'goal_channel',
      'Buts en Direct',
      description: 'Alertes en temps réel lors d\'un but',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<List<LiveMatch>> fetchLiveMatches() async {
    try {
      // Appel DIRECT à SofaScore depuis le téléphone (jamais bloqué)
      final data = await SofaDirectService.fetchLiveMatches();
      final matches = data.map((j) => _mapSofaToMatch(j)).toList();
      _checkGoals(matches);
      return matches;
    } on TimeoutException {
      debugPrint('⚠️ fetchLiveMatches: timeout, returning empty list');
    } catch (e) {
      debugPrint('❌ fetchLiveMatches Error: $e');
    }
    return [];
  }

  static void _checkGoals(List<LiveMatch> matches) {
    for (var m in matches) {
      final currentHome = m.scoreHome ?? 0;
      final currentAway = m.scoreAway ?? 0;
      final currentStatus = m.statusShort ?? '';

      if (_matchStates.containsKey(m.id)) {
        final lastState = _matchStates[m.id]!;

        // Check for Goal Scored
        if (currentHome > lastState.home || currentAway > lastState.away) {
          bool homeScored = currentHome > lastState.home;
          _triggerNotification(
            m,
            '⚽ BUT !!!',
            '${m.homeTeam} $currentHome - $currentAway ${m.awayTeam}',
            true,
            homeScored: homeScored,
          );
        }
        // Check for Cancelled Goal (VAR)
        else if (currentHome < lastState.home || currentAway < lastState.away) {
          _triggerNotification(
            m,
            '❌ BUT ANNULÉ',
            'Retour au score : ${m.homeTeam} $currentHome - $currentAway ${m.awayTeam}',
            false,
          );
        }

        // Check for Status Change
        if (currentStatus != lastState.status) {
          if (currentStatus == 'HT') {
            _triggerNotification(
              m,
              '⏱ MI-TEMPS',
              '${m.homeTeam} $currentHome - $currentAway ${m.awayTeam}',
              false,
            );
          } else if (currentStatus == 'FT' ||
              currentStatus == 'AET' ||
              currentStatus == 'PEN') {
            _triggerNotification(
              m,
              '🏁 FIN DU MATCH',
              '${m.homeTeam} $currentHome - $currentAway ${m.awayTeam}',
              false,
            );
          }
        }
      }
      _matchStates[m.id] = _MatchState(currentHome, currentAway, currentStatus);
    }

    _updateOverlayIfActive(matches);
  }

  static Future<void> _updateOverlayIfActive(List<LiveMatch> matches) async {
    try {
      if (await FlutterOverlayWindow.isActive() && pinnedMatchId != null) {
        final matchToUpdate = matches
            .where((m) => m.id == pinnedMatchId)
            .firstOrNull;
        if (matchToUpdate != null) {
          await FlutterOverlayWindow.shareData({
            'home': matchToUpdate.homeTeam,
            'away': matchToUpdate.awayTeam,
            'homeCode': matchToUpdate.homeCode,
            'awayCode': matchToUpdate.awayCode,
            'score':
                '${matchToUpdate.scoreHome ?? 0} - ${matchToUpdate.scoreAway ?? 0}',
            'minute': matchToUpdate.matchMinute ?? '',
          });
        }
      }
    } catch (_) {}
  }

  static Future<void> _triggerNotification(
    LiveMatch m,
    String title,
    String body,
    bool isGoal, {
    bool? homeScored,
  }) async {
    // 1. In-App Animated Notification (if app is open)
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      if (isGoal && homeScored != null) {
        showGoalOverlay(context, {
          'scoringTeamCode': homeScored ? m.homeCode : m.awayCode,
          'homeTeamName': m.homeTeam,
          'awayTeamName': m.awayTeam,
          'homeScore': '${m.scoreHome ?? 0}',
          'awayScore': '${m.scoreAway ?? 0}',
          'scoringTeam': homeScored ? 'home' : 'away',
          'minute': m.matchMinute,
        });
      } else {
        InAppNotification.show(context, m, title, body, isGoal: isGoal);
      }
    }

    // 2. System Push Notification (Local)
    const android = AndroidNotificationDetails(
      'goal_channel',
      'Buts en Direct',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(m.id.hashCode, title, body, details);

    // 3. Crowdsourcing Firebase Push Notification
    // L'application prévient le backend pour qu'il envoie un push global FCM aux app fermées
    try {
      final payload = {
        "match_id": m.id,
        "title": title,
        "body": body,
        "home_score": m.scoreHome,
        "away_score": m.scoreAway,
        "home_team": m.homeTeam,
        "away_team": m.awayTeam,
        "home_code": m.homeCode,
        "away_code": m.awayCode,
        "is_goal": isGoal,
        "minute": m.matchMinute,
        "scoring_team": homeScored != null ? (homeScored ? 'home' : 'away') : null
      };

      await http
          .post(
            Uri.parse('${GlobalConfig.backendUrl}/api/trigger_goal'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('⚠️ Erreur en signalant le but au serveur: $e');
    }
  }

  static Future<List<LiveMatch>> fetchMatches({int? year}) async {
    final cacheKey = 'matches_$year';
    final cached = _getCache<List<LiveMatch>>(
      cacheKey,
      ttlMinutes: year == 2022 ? 1440 : 5,
    );
    if (cached != null) return cached;

    try {
      if (year == 2022) {
        // 2022 : on garde le backend (cache statique, jamais bloqué)
        final response = await http.get(
          Uri.parse('${GlobalConfig.backendUrl}/api/wc2022/fixtures'),
        );
        if (response.statusCode == 200) {
          final data = _parseMatchesResponse(response.body);
          _setCache(cacheKey, data);
          return data;
        }
      } else {
        // 2026 : appel DIRECT à SofaScore depuis le téléphone
        final rawData = await SofaDirectService.fetchFixtures2026();
        if (rawData.isNotEmpty) {
          final data = rawData.map((j) => _mapSofaToMatch(j)).toList();
          _setCache(cacheKey, data);
          return data;
        }
      }
    } catch (e) {
      debugPrint('❌ fetchMatches Error: $e');
    }
    return [];
  }

  static Future<List<GroupStanding>> fetchStandings({int? year}) async {
    final cacheKey = 'standings_$year';
    final cached = _getCache<List<GroupStanding>>(
      cacheKey,
      ttlMinutes: year == 2022 ? 1440 : 5,
    );
    if (cached != null) return cached;

    try {
      if (year == 2022) {
        // 2022 : backend (cache statique)
        final response = await http.get(
          Uri.parse('${GlobalConfig.backendUrl}/api/wc2022/standings'),
        );
        if (response.statusCode == 200) {
          final data = _parseStandingsResponse(response.body);
          _setCache(cacheKey, data);
          return data;
        }
      } else {
        // 2026 : appel DIRECT à SofaScore
        final rawData = await SofaDirectService.fetchStandings2026();
        if (rawData != null) {
          final data = _parseStandingsResponse(jsonEncode(rawData));
          _setCache(cacheKey, data);
          return data;
        }
      }
    } catch (e) {
      debugPrint('❌ fetchStandings Error: $e');
    }
    return [];
  }

  static Future<MatchDetails?> fetchFullMatchDetails(
    String fixtureId, {
    int? year,
    bool isFinished = false,
  }) async {
    final cacheKey = 'match_$fixtureId';
    final cached = _getCache<MatchDetails>(
      cacheKey,
      ttlMinutes: isFinished ? 1440 : 1,
    );
    if (cached != null) return cached;

    try {
      Map<String, dynamic>? decoded;

      if (year == 2022) {
        // 2022 : backend (cache statique)
        final response = await http.get(
          Uri.parse('${GlobalConfig.backendUrl}/api/match/$fixtureId'),
        );
        if (response.statusCode == 200) {
          decoded = jsonDecode(response.body);
        }
      } else {
        // 2026 : appel DIRECT à SofaScore
        decoded = await SofaDirectService.fetchMatchDetails(
            int.tryParse(fixtureId) ?? 0);
      }

      if (decoded != null) {
        final dynamic payload = decoded.containsKey('response')
            ? decoded['response']
            : decoded;

        MatchDetails details;
        if (payload is List && payload.isNotEmpty && payload.first is Map) {
          details = MatchDetails.fromApi(
            Map<String, dynamic>.from(payload.first as Map),
          );
        } else if (payload is Map) {
          details = MatchDetails.fromApi(Map<String, dynamic>.from(payload));
        } else {
          details = MatchDetails.fromApi(decoded);
        }

        _setCache(cacheKey, details);
        return details;
      }
    } catch (e) {
      debugPrint('❌ fetchFullMatchDetails Error: $e');
    }
    return null;
  }

  static Future<MatchDetails?> fetchMatchDetails(LiveMatch match) async {
    return fetchFullMatchDetails(
      match.id,
      year: match.dateTime?.year,
      isFinished: match.isFinished,
    );
  }

  static Future<TeamProfile?> fetchTeamProfile({
    required int teamId,
    String? teamName,
    int? year,
  }) async {
    try {
      if (year == 2022) {
        // 2022 : backend
        final seasonQuery = '?season=$year';
        final results = await Future.wait([
          http.get(Uri.parse(
              '${GlobalConfig.backendUrl}/api/team/$teamId/coach$seasonQuery')),
          http.get(Uri.parse(
              '${GlobalConfig.backendUrl}/api/team/$teamId/squad$seasonQuery')),
        ]);
        final coachData =
            jsonDecode(results[0].body)['response'] as List? ?? [];
        final playersData =
            jsonDecode(results[1].body)['response'] as List? ?? [];
        TeamCoach? coach;
        if (coachData.isNotEmpty) coach = TeamCoach.fromApi(coachData[0]);
        final List<TeamPlayer> squad = playersData
            .map((p) => TeamPlayer.fromApi(p, teamName ?? ''))
            .toList();
        squad.sort(
          (a, b) => (a.shirtNumber ?? 999).compareTo(b.shirtNumber ?? 999),
        );
        return TeamProfile(
          id: teamId,
          name: teamName ?? 'Équipe',
          shortName: teamName ?? 'Équipe',
          code: resolveCountryCode(teamName ?? ''),
          logoUrl: "https://api.sofascore.com/api/v1/team/$teamId/image",
          venue: "",
          foundedLabel: "",
          coach: coach,
          players: squad,
        );
      } else {
        // 2026 : appel DIRECT à SofaScore
        final coachData = await SofaDirectService.fetchTeamCoach(teamId);
        final playersData = await SofaDirectService.fetchTeamSquad(teamId);
        TeamCoach? coach;
        if (coachData != null) coach = TeamCoach.fromApi(coachData);
        final List<TeamPlayer> squad = playersData
            .map((p) => TeamPlayer.fromApi(p, teamName ?? ''))
            .toList();
        squad.sort(
          (a, b) => (a.shirtNumber ?? 999).compareTo(b.shirtNumber ?? 999),
        );
        return TeamProfile(
          id: teamId,
          name: teamName ?? 'Équipe',
          shortName: teamName ?? 'Équipe',
          code: resolveCountryCode(teamName ?? ''),
          logoUrl: "https://api.sofascore.com/api/v1/team/$teamId/image",
          venue: "",
          foundedLabel: "",
          coach: coach,
          players: squad,
        );
      }
    } catch (e) {
      debugPrint('❌ fetchTeamProfile Error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchPlayerStats({
    required int playerId,
    int? season,
  }) async {
    try {
      final seasonQuery = season != null ? '?season=$season' : '';
      final response = await http.get(
        Uri.parse(
          '${GlobalConfig.backendUrl}/api/player/$playerId/stats$seasonQuery',
        ),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ fetchPlayerStats Error: $e');
    }
    return null;
  }

  static Future<List<TopScorer>> fetchTopScorers({int? year}) async {
    final season = year ?? 2022;
    final cacheKey = 'topscorers_$season';
    final cached = _getCache<List<TopScorer>>(
      cacheKey,
      ttlMinutes: season == 2022 ? 1440 : 10,
    );
    if (cached != null) return cached;

    try {
      List data;
      if (season == 2022) {
        // 2022 : backend (cache statique)
        final response = await http.get(
          Uri.parse('${GlobalConfig.backendUrl}/api/topscorers?season=$season'),
        );
        if (response.statusCode != 200) return [];
        final body = jsonDecode(response.body);
        data = body['response'] as List? ?? [];
      } else {
        // 2026 : appel DIRECT à SofaScore
        data = await SofaDirectService.fetchTopScorers2026();
      }

      final scorers = data
          .asMap()
          .entries
          .map<TopScorer>(
            (entry) => TopScorer.fromApi(
              entry.value as Map<String, dynamic>,
              entry.key + 1,
            ),
          )
          .toList();
      _setCache(cacheKey, scorers);
      return scorers;
    } catch (e) {
      debugPrint('❌ fetchTopScorers Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchNews({String? team}) async {
    try {
      final query = team != null && team.isNotEmpty ? '?team=$team' : '';
      final response = await http.get(
        Uri.parse('${GlobalConfig.backendUrl}/api/worldcup/news$query'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns a list of news items directly
        if (data is List) return data;
        // Fallback if wrapped in a key
        return data['response'] as List? ?? [];
      }
    } catch (e) {
      debugPrint('❌ fetchNews Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchVenues({int year = 2022}) async {
    try {
      final String path = (year == 2022)
          ? '/api/wc2022/venues'
          : '/api/venues?season=$year';
      final response = await http.get(
        Uri.parse('${GlobalConfig.backendUrl}$path'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as List? ?? [];
      }
    } catch (e) {
      debugPrint('❌ fetchVenues Error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchCupTree({int year = 2022}) async {
    try {
      final String path = (year == 2022)
          ? '/api/wc2022/cuptree'
          : '/api/cuptree?season=$year';
      final response = await http.get(
        Uri.parse('${GlobalConfig.backendUrl}$path'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      }
    } catch (e) {
      debugPrint('❌ fetchCupTree Error: $e');
    }
    return null;
  }

  static Future<List<dynamic>> fetchPowerRankings({int year = 2022}) async {
    try {
      // Power rankings fallback to 2022 or generic if not implemented yet
      final String path = (year == 2022)
          ? '/api/wc2022/power-rankings'
          : '/api/wc2022/power-rankings';
      final response = await http.get(
        Uri.parse('${GlobalConfig.backendUrl}$path'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as List? ?? [];
      }
    } catch (e) {
      debugPrint('❌ fetchPowerRankings Error: $e');
    }
    return [];
  }

  static List<LiveMatch> _parseMatchesResponse(String rawJson) {
    final body = jsonDecode(rawJson);
    final data = body['response'] as List? ?? [];
    return data.map((j) => _mapSofaToMatch(j)).toList();
  }

  static LiveMatch _mapSofaToMatch(dynamic json) {
    final fixture = json['fixture'] ?? {};
    final teams = json['teams'] ?? {};
    final goals = json['goals'] ?? {};
    final score = json['score'] ?? {};
    final status = fixture['status'] ?? {};
    final date =
        DateTime.tryParse(fixture['date'] ?? '')?.toLocal() ?? DateTime.now();
    final String? shortStatus = (status['short'] ?? status['type'])?.toString();
    final String? longStatus =
        status['long']?.toString() ?? status['description']?.toString();

    final timeObj = json['time'] ?? fixture['time'] ?? status['time'] ?? {};
    final startTsRaw =
        timeObj['currentPeriodStartTimestamp'] ??
        json['currentPeriodStartTimestamp'] ??
        fixture['currentPeriodStartTimestamp'] ??
        status['currentPeriodStartTimestamp'];
    final int? startTs = startTsRaw != null
        ? int.tryParse(startTsRaw.toString())
        : null;

    bool live =
        [
          '1H',
          '2H',
          'HT',
          'ET',
          'P',
          'LIVE',
          'INPROGRESS',
        ].contains(shortStatus?.toUpperCase()) ||
        status['type']?.toString().toLowerCase() == 'inprogress' ||
        startTs != null;

    String? minuteStr =
        (status['elapsed'] ??
                status['currentMinute'] ??
                timeObj['currentMinute'] ??
                timeObj['played'] ??
                json['currentMinute'])
            ?.toString();

    // Safety check for HT
    if (shortStatus == 'HT' ||
        longStatus == 'HT' ||
        longStatus == 'Half-time' ||
        longStatus == 'Mi-temps') {
      minuteStr = 'HT';
    }

    DateTime? pStart;
    int? pBase;
    if (startTs != null) {
      final isMs = startTs > 9999999999;
      pStart = DateTime.fromMillisecondsSinceEpoch(
        isMs ? startTs : startTs * 1000,
      );
      final code = status['code'] ?? status['short'] ?? json['status']?['code'];
      pBase = 0;
      if (code == 7 || code == '2H') {
        pBase = 45;
      } else if (code == 24 || code == 'ET1') {
        pBase = 90;
      } else if (code == 25 || code == 'ET2') {
        pBase = 105;
      }

      if (minuteStr == null || minuteStr.isEmpty || minuteStr == '0') {
        if (code == 31 || code == 'HT' || shortStatus == 'HT') {
          minuteStr = 'HT';
        } else {
          int diff = DateTime.now().difference(pStart).inMinutes;
          minuteStr = '${pBase + diff}';
        }
      }
    }

    return LiveMatch(
      id: fixture['id']?.toString() ?? '0',
      dateLabel:
          '${_formatDayName(date)} ${date.day} ${_formatMonthName(date)} ${date.year}',
      localTime: '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
      dateTime: date,
      city: fixture['venue']?['city'] ?? 'Stadium',
      homeTeam: teams['home']?['name'] ?? 'TBD',
      homeCode: resolveCountryCode(teams['home']?['name']),
      homeLogoUrl: teams['home']?['logo'],
      scoreHome: goals['home'],
      awayTeam: teams['away']?['name'] ?? 'TBD',
      awayCode: resolveCountryCode(teams['away']?['name']),
      awayLogoUrl: teams['away']?['logo'],
      scoreAway: goals['away'],
      penaltyHome: score['penalty']?['home'],
      penaltyAway: score['penalty']?['away'],
      phaseLabel: json['league']?['round'] ?? 'World Cup',
      isLive: live,
      statusShort: shortStatus,
      statusLong: longStatus,
      matchMinute: minuteStr,
      periodStart: pStart,
      periodBaseMinute: pBase,
      source: MatchDataSource.wc2026api,
      streamUrl: json['stream_url'],
    );
  }

  static List<GroupStanding> _parseStandingsResponse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    final List<dynamic> groups = <dynamic>[];

    if (decoded is Map<String, dynamic>) {
      final dynamic response = decoded['response'];

      if (response is List) {
        for (final item in response) {
          if (item is Map &&
              item['league'] is Map &&
              item['league']['standings'] is List) {
            groups.addAll(item['league']['standings'] as List);
          }
        }
      } else if (response is Map &&
          response['league'] is Map &&
          response['league']['standings'] is List) {
        groups.addAll(response['league']['standings'] as List);
      } else if (decoded['league'] is Map &&
          decoded['league']['standings'] is List) {
        groups.addAll(decoded['league']['standings'] as List);
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map &&
            item['league'] is Map &&
            item['league']['standings'] is List) {
          groups.addAll(item['league']['standings'] as List);
        }
      }
    }

    if (groups.isNotEmpty) {
      return groups.whereType<List>().map((g) {
        final teams = g
            .whereType<Map>()
            .map<StandingTeam>(
              (t) => StandingTeam.fromApi(Map<String, dynamic>.from(t)),
            )
            .toList();
        final groupName = teams.isNotEmpty
            ? (g.first is Map
                  ? (g.first['group']?.toString() ?? 'Groupe')
                  : 'Groupe')
            : 'Groupe';
        return GroupStanding(groupName: groupName, teams: teams);
      }).toList();
    }

    return [];
  }

  static String _formatDayName(DateTime d) =>
      ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][d.weekday - 1];
  static String _formatMonthName(DateTime d) => [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Aoû',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ][d.month - 1];
}
