import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Représente un match du jour depuis l'API kora-api.top
class KoraMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String homeLogoUrl;
  final String awayLogoUrl;
  final String league;
  final String leagueLogoUrl;
  final String time;
  final int status; // 0=upcoming, 1=live, 2=finished
  final String score;
  final String homeScore;
  final String awayScore;
  final List<String> edges;
  final String edgeDomain;

  const KoraMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogoUrl,
    required this.awayLogoUrl,
    required this.league,
    required this.leagueLogoUrl,
    required this.time,
    required this.status,
    required this.score,
    required this.homeScore,
    required this.awayScore,
    required this.edges,
    required this.edgeDomain,
  });

  bool get isLive => status == 1;
  bool get isFinished => status == 2;
  bool get isUpcoming => status == 0;

  factory KoraMatch.fromJson(Map<String, dynamic> json) {
    const cdnBase = 'https://cdn.kora-api.space/uploads';
    final homeLogo = json['home_logo']?.toString() ?? '';
    final awayLogo = json['away_logo']?.toString() ?? '';
    final leagueLogo = json['league_logo']?.toString() ?? '';

    return KoraMatch(
      id: json['id']?.toString() ?? '',
      homeTeam: json['home_en']?.toString() ??
          json['home']?.toString() ??
          'Home',
      awayTeam: json['away_en']?.toString() ??
          json['away']?.toString() ??
          'Away',
      homeLogoUrl: homeLogo.isNotEmpty
          ? '$cdnBase/team/$homeLogo'
          : '',
      awayLogoUrl: awayLogo.isNotEmpty
          ? '$cdnBase/team/$awayLogo'
          : '',
      league: json['league_en']?.toString() ??
          json['league']?.toString() ??
          '',
      leagueLogoUrl: leagueLogo.isNotEmpty
          ? '$cdnBase/league/$leagueLogo'
          : '',
      time: json['time']?.toString() ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      score: json['score']?.toString() ?? '',
      homeScore: (json['home_score']?.toString() ?? '').trim(),
      awayScore: (json['away_score']?.toString() ?? '').trim(),
      edges: (json['edges'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      edgeDomain: json['edge_domain']?.toString() ?? 'kora-plus.app',
    );
  }
}

/// Service pour récupérer les matchs du jour depuis kora-api.top
class KoraApiService {
  static const String _baseUrl = 'https://ws.kora-api.top';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://beinmatchtv.me/',
    'Accept': 'application/json',
  };

  /// Fetch today's matches
  static Future<List<KoraMatch>> fetchTodayMatches() async {
    final today = _todayFormatted();
    final url = Uri.parse('$_baseUrl/api/matches/$today/1');

    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[KoraAPI] HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final matchesList = data['matches'] as List? ?? [];
      return matchesList
          .map((m) => KoraMatch.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[KoraAPI] Error: $e');
      return [];
    }
  }

  static String _todayFormatted() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Build the WebView URL for a live match
  static String buildStreamUrl(String matchId) =>
      'https://strm01.app/?m=$matchId&lang=ar';
}
