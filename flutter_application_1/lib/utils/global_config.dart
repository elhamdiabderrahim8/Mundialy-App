import 'package:flutter/foundation.dart';

class GlobalConfig {
  /// URL du backend.
  /// - Production : Render.com (utilisé dans l'APK déployé)
  /// - Développement : IP locale (pour le debug sur votre réseau Wi-Fi)
  static const String backendUrl = kReleaseMode
      ? 'https://mundialy-backend.onrender.com'
      : 'http://192.168.1.16:5000';
}
