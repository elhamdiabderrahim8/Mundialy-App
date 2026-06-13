import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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
import '../utils/team_resolver.dart';
import '../widgets/in_app_notification.dart';
import '../widgets/animated_goal_overlay.dart';
import '../utils/app_globals.dart';
import 'scores365_service.dart';
import 'scorer_calculation_service.dart';

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
  static const String _liveAlertsChannelId = 'mundialy_live_alerts_v2';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Map<String, _MatchState> _matchStates = {};
  static final Map<String, _CacheEntry> _cache = {};
  static String? pinnedMatchId;

  /// Helper HTTP pour les appels au backend Render.
  /// Gère le "cold start" du plan gratuit (30-60s de réveil)
  /// avec un timeout généreux et un retry automatique.
  static Future<http.Response?> _backendGet(
    String path, {
    int retries = 1,
  }) async {
    final baseUrls = <String>[
      GlobalConfig.backendUrl,
      if (!kReleaseMode && GlobalConfig.backendUrl.contains('192.168.'))
        'https://mundialy-backend.onrender.com',
    ];

    for (final baseUrl in baseUrls) {
      final url = Uri.parse('$baseUrl$path');
      for (int attempt = 0; attempt <= retries; attempt++) {
        try {
          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 60));
          if (response.statusCode == 200) return response;
          debugPrint(
            '[Backend] Status ${response.statusCode} pour $url (tentative ${attempt + 1})',
          );
        } catch (e) {
          debugPrint(
            '[Backend] Erreur tentative ${attempt + 1}/$retries pour $url: $e',
          );
        }
        if (attempt < retries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    return null;
  }

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

  static T? _getAnyCache<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    return entry.data as T;
  }

  static void _setCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data, DateTime.now());
  }

  static Future<void> initNotifications() async {
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const settings = InitializationSettings(android: android);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications.initialize(settings);

    const channel = AndroidNotificationChannel(
      _liveAlertsChannelId,
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

  static Future<void> showSystemNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      _liveAlertsChannelId,
      'Buts en Direct',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  static Future<List<LiveMatch>> fetchLiveMatches() async {
    const cacheKey = 'live_matches';
    try {
      // Appel DIRECT à 365Scores depuis le téléphone
      List<LiveMatch> matches = await Scores365Service.fetchLiveMatches();

      if (matches.isNotEmpty) {
        TeamResolver.indexMatches(matches);
        _setCache(cacheKey, matches);
        _checkGoals(matches);
        return matches;
      }
      debugPrint('fetchLiveMatches: No live matches found');
    } on TimeoutException {
      debugPrint('⚠️ fetchLiveMatches: timeout, returning empty list');
    } catch (e) {
      debugPrint('❌ fetchLiveMatches Error: $e');
    }
    return _getCache<List<LiveMatch>>(cacheKey, ttlMinutes: 1) ?? [];
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
        InAppNotification.show(
          context,
          m.homeTeam,
          m.awayTeam,
          m.matchMinute,
          title,
          body,
          isGoal: isGoal,
        );
      }
    }

    // 2. System Push Notification (Local)
    final android = AndroidNotificationDetails(
      _liveAlertsChannelId,
      'Buts en Direct',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: const Color(0xFFD4AF37),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Mundialy Live',
      ),
    );
    final details = NotificationDetails(android: android);
    await _notifications.show(m.id.hashCode, title, body, details);

    // 3. Crowdsourcing Firebase Push Notification
    // L'application prévient le backend pour qu'il envoie un push global FCM aux app fermées
    if (isGoal) {
      try {
        final payload = {
          "topic": "live_matches",
          "type": "goal",
          "title": title,
          "message": body,
          "homeTeamName": m.homeTeam,
          "awayTeamName": m.awayTeam,
          "homeScore": m.scoreHome,
          "awayScore": m.scoreAway,
          "minute": m.matchMinute,
        };

        await http
            .post(
              Uri.parse('${GlobalConfig.backendUrl}/api/admin/push'),
              headers: {
                'Content-Type': 'application/json',
                'X-Admin-Key': 'mundialy_secret_2026',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Erreur en signalant le but au serveur: $e');
      }
    }
  }

  static Future<List<LiveMatch>> fetchMatches({
    int? year,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'matches_$year';
    if (!forceRefresh) {
      final cached = _getCache<List<LiveMatch>>(
        cacheKey,
        ttlMinutes: year == 2022 ? 1440 : 5,
      );
      if (cached != null) return cached;
    }

    try {
      if (year == 2022) {
        // 2022 : chargement INSTANTANÉ depuis les assets embarqués (0 latence)
        final raw = await rootBundle.loadString(
          'assets/data/matches_2022.json',
        );
        final data = _parseMatchesResponse(raw);
        TeamResolver.indexMatches(data);
        _setCache(cacheKey, data);
        
        // Déclencher l'algorithme des buteurs même pour 2022 si besoin
        ScorerCalculationService.runAggregator(data);

        return data;
      } else {
        // 2026 : appel DIRECT à 365Scores
        final data = await Scores365Service.fetchFixtures2026();
        if (data.isNotEmpty) {
          TeamResolver.indexMatches(data);
          _setCache(cacheKey, data);
          
          // Déclencher l'algorithme des buteurs en arrière-plan
          ScorerCalculationService.runAggregator(data);

          return data;
        }
        debugPrint('fetchMatches: 365Scores direct returned no fixtures');
      }
    } catch (e) {
      debugPrint('❌ fetchMatches Error: $e');
    }
    return _getAnyCache<List<LiveMatch>>(cacheKey) ?? [];
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
        final matchesRaw = await rootBundle.loadString(
          'assets/data/matches_2022.json',
        );
        TeamResolver.indexMatches(_parseMatchesResponse(matchesRaw));
        final raw = await rootBundle.loadString(
          'assets/data/standings_2022.json',
        );
        final data = _remapStandingsIds(_parseStandingsResponse(raw));
        _setCache(cacheKey, data);
        return data;
      } else {
        // 2026 : appel DIRECT à 365Scores
        final data = await Scores365Service.fetchStandings2026();
        if (data.isNotEmpty) {
          _setCache(cacheKey, data);
          return data;
        }
        debugPrint('fetchStandings: 365Scores direct returned no groups');
      }
    } catch (e) {
      debugPrint('❌ fetchStandings Error: $e');
    }
    return _getAnyCache<List<GroupStanding>>(cacheKey) ?? [];
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
      final details = await Scores365Service.fetchMatchDetails(
        int.tryParse(fixtureId) ?? 0,
      );

      if (details != null) {
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
      final resolvedId = TeamResolver.resolve(teamName ?? '', hintId: teamId);
      final seasonYear = year ?? 2026;
      final seasonId = seasonYear == 2022
          ? GlobalConfig.season2022Id
          : GlobalConfig.season2026Id;

      debugPrint(
        '🔍 fetchTeamProfile: resolvedId=$resolvedId, teamName=$teamName, season=$seasonYear',
      );

      final results = await Future.wait([
        Scores365Service.fetchTeamCoach(resolvedId),
        Scores365Service.fetchTournamentSquad(resolvedId, seasonId),
      ]);

      final coachData = results[0] as Map<String, dynamic>?;
      var playersData = results[1] as List<Map<String, dynamic>>? ?? [];
      if (playersData.isEmpty) {
        playersData = await Scores365Service.fetchTeamSquad(resolvedId);
      }
      debugPrint(
        '🔍 fetchTeamProfile: coach=${coachData != null}, players=${playersData.length}',
      );

      TeamCoach? coach;
      if (coachData != null) {
        coach = TeamCoach.fromApi({
          'id': coachData['id'],
          'name': coachData['name'],
          'photo': coachData['photo'],
          'nationality': coachData['nationality'],
        });
      }

      final List<TeamPlayer> squad = playersData.map((p) {
        return TeamPlayer.fromApi(p, teamName ?? '');
      }).toList();

      debugPrint(
        '🔍 fetchTeamProfile: parsed ${squad.length} players, positions: ${squad.map((p) => p.position).toSet()}',
      );

      squad.sort(
        (a, b) => (a.shirtNumber ?? 999).compareTo(b.shirtNumber ?? 999),
      );

      return TeamProfile(
        id: resolvedId,
        name: teamName ?? 'Équipe',
        shortName: teamName ?? 'Équipe',
        code: resolveCountryCode(teamName ?? ''),
        logoUrl: null,
        venue: "",
        foundedLabel: "",
        coach: coach,
        players: squad,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ fetchTeamProfile Error: $e');
      debugPrint('❌ Stack: $stackTrace');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchPlayerStats({
    required int playerId,
    int? season,
  }) async {
    final resolvedSeason = season ?? 2026;
    final cacheKey = 'player_stats_${playerId}_$resolvedSeason';
    final cached = _getCache<Map<String, dynamic>>(cacheKey, ttlMinutes: 30);
    if (cached != null) return cached;

    try {
      final seasonId = resolvedSeason == 2022
          ? GlobalConfig.season2022Id
          : GlobalConfig.season2026Id;

      final results = await Future.wait([
        Scores365Service.fetchPlayerNationalStats(playerId),
        Scores365Service.fetchPlayerCharacteristics(playerId),
        Scores365Service.fetchPlayerAttributes(playerId),
        Scores365Service.fetchPlayerStats(playerId, seasonId),
      ]);
      final data = {
        'nationalStats': results[0],
        'characteristics': results[1],
        'attributes': results[2],
        'tournamentStats': results[3],
      };
      _setCache(cacheKey, data);
      return data;
    } catch (e) {
      debugPrint('❌ fetchPlayerStats Error: $e');
    }
    return null;
  }

  static Future<List<TopScorer>> fetchTopScorers({int? year}) async {
    final season = year ?? 2022;
    final cacheKey = 'topscorers_$season';
    
    // Pour l'onglet buteurs, on veut voir les résultats de notre algorithme
    // le plus vite possible, donc on réduit la durée du cache
    final cached = _getCache<List<TopScorer>>(
      cacheKey,
      ttlMinutes: 1, // Cache très court pour voir les mises à jour
    );
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      List<TopScorer> scorers;
      if (season == 2022) {
        // 2022 : chargement INSTANTANÉ depuis les assets embarqués
        final raw = await rootBundle.loadString(
          'assets/data/topscorers_2022.json',
        );
        final body = jsonDecode(raw);
        final data = body['response'] as List? ?? [];
        scorers = data
            .asMap()
            .entries
            .map<TopScorer>(
              (entry) => TopScorer.fromApi(
                entry.value as Map<String, dynamic>,
                entry.key + 1,
              ),
            )
            .toList();
      } else {
        // 2026 : On utilise d'abord l'algorithme local pour valider le calcul "éternel"
        scorers = await ScorerCalculationService.getStoredScorers();

        // Si l'algorithme local n'a encore rien (premier lancement), on essaie l'API
        if (scorers.isEmpty) {
          scorers = await Scores365Service.fetchTopScorers(
            Scores365Service.wcCompetitionId,
          );
        }

        // Rank them
        for (int i = 0; i < scorers.length; i++) {
          scorers[i].rank = i + 1;
        }
      }

      // Ne pas mettre en cache une liste vide pour permettre un rafraîchissement rapide
      if (scorers.isNotEmpty) {
        _setCache(cacheKey, scorers);
      }

      return scorers;
    } catch (e) {
      debugPrint('❌ fetchTopScorers Error: $e');
    }
    return [];
  }

  static Future<List<dynamic>> fetchNews({String? team}) async {
    try {
      final query = team != null && team.isNotEmpty ? '?team=$team' : '';
      final response = await _backendGet('/api/worldcup/news$query');
      if (response != null) {
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
      final String venuePath = (year == 2022)
          ? '/api/wc2022/venues'
          : '/api/venues?season=$year';
      final response = await _backendGet(venuePath);
      if (response != null) {
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
      final String cupTreePath = (year == 2022)
          ? '/api/wc2022/cuptree'
          : '/api/cuptree?season=$year';
      final response = await _backendGet(cupTreePath);
      if (response != null) {
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
      final String rankPath = (year == 2022)
          ? '/api/wc2022/power-rankings'
          : '/api/wc2022/power-rankings';
      final response = await _backendGet(rankPath);
      if (response != null) {
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

  /// Nettoie et normalise les noms d'équipes bruts de SofaScore
  static String _cleanTeamName(String? raw) {
    if (raw == null || raw.isEmpty) return 'TBD';
    // Table de traduction : noms SofaScore → noms propres
    const nameMap = {
      'USA': 'United States',
      'Korea Republic': 'South Korea',
      'Korea DPR': 'North Korea',
      'IR Iran': 'Iran',
      'Türkiye': 'Turkey',
      'Czechia': 'Czech Republic',
      'Cabo Verde': 'Cape Verde',
      'Chinese Taipei': 'Taiwan',
      'Congo DR': 'DR Congo',
      'Timor-Leste': 'Timor Leste',
      'Eswatini': 'Swaziland',
    };
    return nameMap[raw] ?? raw;
  }

  /// Convertit une valeur de score brute en int propre
  static int? _cleanScore(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static LiveMatch _mapSofaToMatch(dynamic json) {
    final fixture = json['fixture'] ?? {};
    final teams = json['teams'] ?? {};
    final goals = json['goals'] ?? {};
    final score = json['score'] ?? {};
    final status = fixture['status'] ?? {};

    final timeObj = json['time'] ?? fixture['time'] ?? status['time'] ?? {};
    final startTsRaw =
        timeObj['currentPeriodStartTimestamp'] ??
        json['currentPeriodStartTimestamp'] ??
        fixture['currentPeriodStartTimestamp'] ??
        status['currentPeriodStartTimestamp'] ??
        fixture['timestamp'] ??
        json['startTimestamp'];
    final int? startTs = startTsRaw != null
        ? int.tryParse(startTsRaw.toString())
        : null;

    DateTime date;
    if (startTs != null && startTs > 0) {
      final isMs = startTs > 9999999999;
      date = DateTime.fromMillisecondsSinceEpoch(
        isMs ? startTs : startTs * 1000,
      );
    } else {
      date =
          DateTime.tryParse(fixture['date'] ?? '')?.toLocal() ?? DateTime.now();
    }

    final String? shortStatus = (status['short'] ?? status['type'])?.toString();
    final String? longStatus =
        status['long']?.toString() ?? status['description']?.toString();

    // Déterminer si le match est terminé AVANT tout le reste
    final bool isFinished =
        shortStatus?.toUpperCase() == 'FT' ||
        shortStatus?.toUpperCase() == 'AET' ||
        shortStatus?.toUpperCase() == 'PEN' ||
        shortStatus?.toUpperCase() == 'FINISHED' ||
        status['type']?.toString().toLowerCase() == 'finished';

    // isLive : seulement si le match est VRAIMENT en cours (pas terminé)
    bool live =
        !isFinished &&
        ([
              '1H',
              '2H',
              'HT',
              'ET',
              'P',
              'LIVE',
              'INPROGRESS',
            ].contains(shortStatus?.toUpperCase()) ||
            status['type']?.toString().toLowerCase() == 'inprogress');

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
    if (startTs != null && live) {
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

    // Nettoyage des noms d'équipes
    final homeName = _cleanTeamName(teams['home']?['name']?.toString());
    final awayName = _cleanTeamName(teams['away']?['name']?.toString());

    // Extraction des IDs d'équipes (pour les liens vers le profil)
    final int? homeId = teams['home']?['id'] is int
        ? teams['home']['id'] as int
        : int.tryParse(teams['home']?['id']?.toString() ?? '');
    final int? awayId = teams['away']?['id'] is int
        ? teams['away']['id'] as int
        : int.tryParse(teams['away']?['id']?.toString() ?? '');

    // Nettoyage du label de phase
    String phaseLabel = json['league']?['round']?.toString() ?? 'World Cup';
    // Harmoniser : "Group Stage - 1" → "Group Stage - 1" (déjà bon)
    // Mais enlever les préfixes redondants comme "FIFA World Cup "
    phaseLabel = phaseLabel
        .replaceAll('FIFA World Cup 26: ', '')
        .replaceAll('FIFA World Cup ', '')
        .replaceAll('World Cup: ', '');

    return LiveMatch(
      id: fixture['id']?.toString() ?? '0',
      dateLabel:
          '${_formatDayName(date)} ${date.day} ${_formatMonthName(date)} ${date.year}',
      localTime:
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      dateTime: date,
      city: _resolveVenueLabel(fixture['venue']),
      homeTeam: homeName,
      homeCode: resolveCountryCode(homeName),
      homeTeamId: homeId,
      homeLogoUrl: null,
      scoreHome: _cleanScore(goals['home']),
      awayTeam: awayName,
      awayCode: resolveCountryCode(awayName),
      awayTeamId: awayId,
      awayLogoUrl: null,
      scoreAway: _cleanScore(goals['away']),
      penaltyHome: _cleanScore(score['penalty']?['home']),
      penaltyAway: _cleanScore(score['penalty']?['away']),
      phaseLabel: phaseLabel,
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

  static List<GroupStanding> _remapStandingsIds(List<GroupStanding> groups) {
    return groups.map((group) {
      final teams = group.teams.map((team) {
        final resolved = TeamResolver.resolve(
          team.teamName,
          hintId: team.teamId,
        );
        return StandingTeam(
          teamId: resolved > 0 ? resolved : team.teamId,
          rank: team.rank,
          teamName: team.teamName,
          teamLogo: '',
          points: team.points,
          played: team.played,
          goalsDiff: team.goalsDiff,
        );
      }).toList();
      return GroupStanding(groupName: group.groupName, teams: teams);
    }).toList();
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

  static String _resolveVenueLabel(dynamic venue) {
    if (venue is! Map) return 'Stade à confirmer';
    final city = venue['city']?.toString().trim() ?? '';
    final name = venue['name']?.toString().trim() ?? '';
    if (name.isNotEmpty && city.isNotEmpty) return '$name · $city';
    if (city.isNotEmpty) return city;
    if (name.isNotEmpty) return name;
    return 'Stade à confirmer';
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
