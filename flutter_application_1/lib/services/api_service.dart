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
import '../utils/country_flags.dart';
import '../utils/global_config.dart';

class ApiService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final Map<String, String> _lastScores = {};

  static Future<void> initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    await _notifications.initialize(settings);
    
    const channel = AndroidNotificationChannel(
      'goal_channel', 'Buts en Direct',
      description: 'Alertes en temps réel lors d\'un but',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  static Future<List<LiveMatch>> fetchLiveMatches() async {
    try {
      final response = await http
          .get(Uri.parse('${GlobalConfig.backendUrl}/api/worldcup/live'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['response'] as List? ?? [];
        final matches = data.map((j) => _mapSofaToMatch(j)).toList();
        _checkGoals(matches);
        return matches;
      }
    } on TimeoutException {
      debugPrint('⚠️ fetchLiveMatches: timeout, returning empty list');
    } on http.ClientException catch (e) {
      debugPrint('⚠️ fetchLiveMatches: network issue ($e), returning empty list');
    } catch (e) {
      debugPrint('❌ fetchLiveMatches Error: $e');
    }
    return [];
  }

  static void _checkGoals(List<LiveMatch> matches) {
    for (var m in matches) {
      final currentScore = '${m.scoreHome ?? 0}-${m.scoreAway ?? 0}';
      if (_lastScores.containsKey(m.id) && _lastScores[m.id] != currentScore) {
        _showGoalNotification(m);
      }
      _lastScores[m.id] = currentScore;
    }
  }

  static Future<void> _showGoalNotification(LiveMatch m) async {
    const android = AndroidNotificationDetails(
      'goal_channel', 'Buts en Direct',
      importance: Importance.max, priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(m.id.hashCode, '⚽ BUT !!!', '${m.homeTeam} ${m.scoreHome} - ${m.scoreAway} ${m.awayTeam}', details);
  }

  static Future<List<LiveMatch>> fetchMatches({int? year}) async {
    try {
      final String path = (year == 2022) ? '/api/wc2022/fixtures' : '/api/fixtures';
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}$path'));
      if (response.statusCode == 200) return _parseMatchesResponse(response.body);
    } catch (e) { debugPrint('❌ fetchMatches Error: $e'); }
    return [];
  }

  static Future<List<GroupStanding>> fetchStandings({int? year}) async {
    try {
      final String path = (year == 2022) ? '/api/wc2022/standings' : '/api/standings';
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}$path'));
      if (response.statusCode == 200) return _parseStandingsResponse(response.body);
    } catch (e) { debugPrint('❌ fetchStandings Error: $e'); }
    return [];
  }

  static Future<MatchDetails?> fetchFullMatchDetails(String fixtureId, {int? year}) async {
    try {
      // Pour les détails, on utilise la route unique /api/match/id
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/match/$fixtureId'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dynamic payload = (decoded is Map<String, dynamic>) ? decoded['response'] : decoded;

        if (payload is List && payload.isNotEmpty && payload.first is Map) {
          return MatchDetails.fromApi(Map<String, dynamic>.from(payload.first as Map));
        }

        if (payload is Map) {
          return MatchDetails.fromApi(Map<String, dynamic>.from(payload));
        }

        if (decoded is Map<String, dynamic>) {
          return MatchDetails.fromApi(decoded);
        }
      }
    } catch (e) { debugPrint('❌ fetchFullMatchDetails Error: $e'); }
    return null;
  }

  static Future<MatchDetails?> fetchMatchDetails(LiveMatch match) async {
    return fetchFullMatchDetails(match.id, year: match.dateTime?.year);
  }

  static Future<TeamProfile?> fetchTeamProfile({required int teamId, String? teamName, int? year}) async {
    try {
      final seasonQuery = year != null ? '?season=$year' : '';
      final results = await Future.wait([
        http.get(Uri.parse('${GlobalConfig.backendUrl}/api/team/$teamId/coach$seasonQuery')),
        http.get(Uri.parse('${GlobalConfig.backendUrl}/api/team/$teamId/squad$seasonQuery')),
      ]);
      final coachData = jsonDecode(results[0].body)['response'] as List? ?? [];
      final playersData = jsonDecode(results[1].body)['response'] as List? ?? [];
      TeamCoach? coach;
      if (coachData.isNotEmpty) coach = TeamCoach.fromApi(coachData[0]);
      final List<TeamPlayer> squad = playersData.map((p) => TeamPlayer.fromApi(p, teamName ?? '')).toList();
      squad.sort((a, b) => (a.shirtNumber ?? 999).compareTo(b.shirtNumber ?? 999));
      return TeamProfile(
        id: teamId, name: teamName ?? 'Équipe', shortName: teamName ?? 'Équipe',
        code: resolveCountryCode(teamName ?? ''), logoUrl: "https://api.sofascore.com/api/v1/team/$teamId/image",
        venue: "", foundedLabel: "", coach: coach, players: squad,
      );
    } catch (e) { debugPrint('❌ fetchTeamProfile Error: $e'); }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchPlayerStats({required int playerId, int? season}) async {
    try {
      final seasonQuery = season != null ? '?season=$season' : '';
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/player/$playerId/stats$seasonQuery'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint('❌ fetchPlayerStats Error: $e'); }
    return null;
  }

  static Future<List<TopScorer>> fetchTopScorers({int? year}) async {
    try {
      final season = year ?? 2022;
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/topscorers?season=$season'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body['response'] as List? ?? [];
        return data.asMap().entries.map<TopScorer>((entry) => TopScorer.fromApi(entry.value as Map<String, dynamic>, entry.key + 1)).toList();
      }
    } catch (e) { debugPrint('❌ fetchTopScorers Error: $e'); }
    return [];
  }

  static Future<List<dynamic>> fetchNews() async {
    try {
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/worldcup/news'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as List? ?? [];
      }
    } catch (e) { debugPrint('❌ fetchNews Error: $e'); }
    return [];
  }

  static Future<List<dynamic>> fetchVenues() async {
    try {
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/wc2022/venues'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as List? ?? [];
      }
    } catch (e) { debugPrint('❌ fetchVenues Error: $e'); }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchCupTree() async {
    try {
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/wc2022/cuptree'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      }
    } catch (e) { debugPrint('❌ fetchCupTree Error: $e'); }
    return null;
  }

  static Future<List<dynamic>> fetchPowerRankings() async {
    try {
      final response = await http.get(Uri.parse('${GlobalConfig.backendUrl}/api/wc2022/power-rankings'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as List? ?? [];
      }
    } catch (e) { debugPrint('❌ fetchPowerRankings Error: $e'); }
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
    final date = DateTime.tryParse(fixture['date'] ?? '')?.toLocal() ?? DateTime.now();
    return LiveMatch(
      id: fixture['id']?.toString() ?? '0',
      dateLabel: '${_formatDayName(date)} ${date.day} ${_formatMonthName(date)} ${date.year}',
      localTime: '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
      dateTime: date, city: fixture['venue']?['city'] ?? 'Stadium',
      homeTeam: teams['home']?['name'] ?? 'TBD',
      homeCode: resolveCountryCode(teams['home']?['name']),
      homeLogoUrl: teams['home']?['logo'], scoreHome: goals['home'],
      awayTeam: teams['away']?['name'] ?? 'TBD',
      awayCode: resolveCountryCode(teams['away']?['name']),
      awayLogoUrl: teams['away']?['logo'], scoreAway: goals['away'],
      penaltyHome: score['penalty']?['home'],
      penaltyAway: score['penalty']?['away'],
      phaseLabel: json['league']?['round'] ?? 'World Cup',
      isLive: ['1H', '2H', 'HT', 'ET', 'P'].contains(fixture['status']?['short']),
      source: MatchDataSource.wc2026api, streamUrl: json['stream_url'],
    );
  }

  static List<GroupStanding> _parseStandingsResponse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    final List<dynamic> groups = <dynamic>[];

    if (decoded is Map<String, dynamic>) {
      final dynamic response = decoded['response'];

      if (response is List) {
        for (final item in response) {
          if (item is Map && item['league'] is Map && item['league']['standings'] is List) {
            groups.addAll(item['league']['standings'] as List);
          }
        }
      } else if (response is Map && response['league'] is Map && response['league']['standings'] is List) {
        groups.addAll(response['league']['standings'] as List);
      } else if (decoded['league'] is Map && decoded['league']['standings'] is List) {
        groups.addAll(decoded['league']['standings'] as List);
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map && item['league'] is Map && item['league']['standings'] is List) {
          groups.addAll(item['league']['standings'] as List);
        }
      }
    }

    if (groups.isNotEmpty) {
      return groups.whereType<List>().map((g) {
        final teams = g.whereType<Map>().map<StandingTeam>((t) => StandingTeam.fromApi(Map<String, dynamic>.from(t))).toList();
        final groupName = teams.isNotEmpty ? (g.first is Map ? (g.first['group']?.toString() ?? 'Groupe') : 'Groupe') : 'Groupe';
        return GroupStanding(groupName: groupName, teams: teams);
      }).toList();
    }

    return [];
  }

  static String _formatDayName(DateTime d) => ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][d.weekday - 1];
  static String _formatMonthName(DateTime d) => ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'][d.month - 1];
}
