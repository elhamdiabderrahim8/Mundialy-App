import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/global_config.dart';
import 'sofa_direct_service.dart';

class SofaScraperService {
  /// Récupère les compositions d'équipes et positions.
  /// - 2022 : via le backend (cache statique)
  /// - 2026 : appel DIRECT à SofaScore depuis le téléphone
  static Future<Map<String, dynamic>?> fetchLineups(String matchId) async {
    try {
      debugPrint('📡 Récupération des détails du match: $matchId');

      // Essayer d'abord en direct depuis SofaScore (pas de blocage Cloudflare)
      final directData = await SofaDirectService.fetchMatchDetails(
        int.tryParse(matchId) ?? 0,
      );
      if (directData != null) return directData;

      // Fallback : backend (pour les matchs 2022 en cache)
      final response = await http
          .get(Uri.parse('${GlobalConfig.backendUrl}/api/match/$matchId'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
          '❌ Erreur backend: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('💥 Échec de récupération des détails: $e');
    }
    return null;
  }
}
