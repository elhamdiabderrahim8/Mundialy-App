import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/global_config.dart';

class SofaScraperService {
  static String get _baseUrl => GlobalConfig.backendUrl;

  /// Récupère les compositions d'équipes et positions via le pont Python
  static Future<Map<String, dynamic>?> fetchLineups(String matchId) async {
    try {
      debugPrint('📡 Appel du pont Python pour le match: $matchId');
      final response = await http
          .get(Uri.parse('$_baseUrl/api/match/$matchId'))
          .timeout(const Duration(seconds: 30)); // Le scraping peut être long

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
          '❌ Erreur du pont: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('💥 Échec de connexion au pont Python: $e');
      debugPrint('Assure-toi que "python app.py" est bien lancé sur ton PC.');
    }
    return null;
  }
}
