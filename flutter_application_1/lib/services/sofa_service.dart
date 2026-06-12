import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/live_match.dart';
import '../utils/country_flags.dart';
import '../utils/global_config.dart';

class SofaService {
  static const String _baseUrl = GlobalConfig.backendUrl;

  static Future<Map<String, dynamic>> fetchWorldCup2026CompleteData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/worldcup/complete-data'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        } else if (decoded is List) {
          return {'games': decoded};
        }
      }
    } catch (e) {
      debugPrint('Error 365 Data: $e');
    }
    return {};
  }

  static Future<List<dynamic>> fetchWorldCupNews() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/worldcup/news'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> news = [];

        if (decoded is Map && decoded.containsKey('news')) {
          news = decoded['news'] as List<dynamic>;
        } else if (decoded is List) {
          news = decoded;
        }

        return news.map((n) {
          String? img = n['imageURL'];
          if (img == null && n['imageRelativePath'] != null) {
            img =
                'https://image.365scores.com/image/upload/${n['imageRelativePath']}';
          }
          return {
            "title": n['title'] ?? 'Sans titre',
            "desc": n['teaser'] ?? n['description'] ?? '',
            "img": img,
            "url": n['link'],
            "source": "365Scores",
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error 365 News: $e');
    }
    return [];
  }

  static LiveMatch mapJsonToLiveMatch(
    dynamic g, [
    Map<int, dynamic>? competitorsMap,
  ]) {
    var home = g['homeCompetitor'];
    var away = g['awayCompetitor'];

    if (competitorsMap != null) {
      if (home == null && g['homeCompetitorId'] != null) {
        home = competitorsMap[(g['homeCompetitorId'] as num).toInt()];
      }
      if (away == null && g['awayCompetitorId'] != null) {
        away = competitorsMap[(g['awayCompetitorId'] as num).toInt()];
      }
    }

    home ??= {};
    away ??= {};

    DateTime dt = DateTime.now();
    if (g['startTime'] != null) {
      String st = g['startTime'].toString();
      if (!st.endsWith('Z') && !st.contains('+') && !st.contains('-')) {
        st += 'Z'; // Force UTC interpretation if no timezone is provided
      }
      dt = DateTime.tryParse(st)?.toLocal() ?? DateTime.now();
    }

    return LiveMatch(
      id: '${g['id']}',
      dateLabel: '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}',
      localTime: '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      city: 'Coupe du Monde 2026',
      homeTeam: home['name'] ?? 'TBD',
      homeCode: resolveCountryCode(home['name'] ?? ''),
      homeTeamId: (home['id'] as num?)?.toInt(),
      homeLogoUrl:
          home['imageURL'] ??
          (home['imageRelativePath'] != null
              ? 'https://image.365scores.com/image/upload/${home['imageRelativePath']}'
              : null),
      awayTeam: away['name'] ?? 'TBD',
      awayCode: resolveCountryCode(away['name'] ?? ''),
      awayTeamId: (away['id'] as num?)?.toInt(),
      awayLogoUrl:
          away['imageURL'] ??
          (away['imageRelativePath'] != null
              ? 'https://image.365scores.com/image/upload/${away['imageRelativePath']}'
              : null),
      scoreHome: (g['homeCompetitor']?['score'] as num?)?.toInt(),
      scoreAway: (g['awayCompetitor']?['score'] as num?)?.toInt(),
      phaseLabel: g['statusText'] ?? '',
      isLive: g['status'] == 2,
      source: MatchDataSource.wc2026api,
    );
  }
}
