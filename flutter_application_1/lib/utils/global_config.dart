import 'package:flutter/foundation.dart';

class GlobalConfig {
  /// URL du backend Python (Render.com).
  /// Garde UNIQUEMENT pour :
  ///   - Les données 2022 (cache statique)
  ///   - Les notifications Push Firebase (trigger_goal)
  ///   - Les News
  /// - Production : Render.com (utilisé dans l'APK déployé)
  /// - Développement : IP locale (pour le debug sur votre réseau Wi-Fi)
  static const String backendUrl = kReleaseMode
      ? 'https://mundialy-backend.onrender.com'
      : 'http://192.168.1.16:5000';

  /// URL de base de l'API SofaScore — appelée DIRECTEMENT par le téléphone.
  /// Jamais bloqué car l'IP est résidentielle (opérateur mobile / Wi-Fi maison).
  static const String sofaBaseUrl = 'https://api.sofascore.com/api/v1';

  /// IDs de la Coupe du Monde
  static const int worldCupTournamentId = 16;
  static const int season2026Id = 58210;
  static const int season2022Id = 41087;
}
