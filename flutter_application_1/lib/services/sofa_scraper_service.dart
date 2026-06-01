import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SofaScraperService {
  // L'adresse IP de ton PC. 
  // IMPORTANT: Si tu es sur émulateur Android, utilise 'http://10.0.2.2:5000'
  // Si tu es sur ton vrai téléphone Infinix, utilise l'IP de ton PC (ex: 'http://192.168.1.15:5000')
  static const String _baseUrl = 'http://10.0.2.2:5000'; 

  /// Récupère les compositions d'équipes et positions via le pont Python
  static Future<Map<String, dynamic>?> fetchLineups(String matchId) async {
    try {
      debugPrint('📡 Appel du pont Python pour le match: $matchId');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/match/$matchId'),
      ).timeout(const Duration(seconds: 30)); // Le scraping peut être long

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('❌ Erreur du pont: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('💥 Échec de connexion au pont Python: $e');
      debugPrint('Assure-toi que "python app.py" est bien lancé sur ton PC.');
    }
    return null;
  }
}
