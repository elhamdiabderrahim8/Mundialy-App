import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final StreamController<void> refreshStreamController =
    StreamController<void>.broadcast();

// ─────────────────────────────────────────────────────────────────────────────
// MODE LECTURE EN DIRECT — suppression temporaire des notifications
// ─────────────────────────────────────────────────────────────────────────────

// Clé SharedPreferences accessible depuis le background isolate
const String _kIsWatchingLiveKey = 'isWatchingLive';

/// Vrai si l'utilisateur est en train de regarder un flux en direct
/// (lecteur IPTV ou lecteur live match).
bool isWatchingLive = false;

Timer? _watchingLiveRestoreTimer;

/// Appeler quand l'utilisateur OUVRE un lecteur vidéo en direct.
void enterLiveWatchMode() {
  _watchingLiveRestoreTimer?.cancel();
  _watchingLiveRestoreTimer = null;
  isWatchingLive = true;
  // ► Persisté dans SharedPreferences pour que le background isolate puisse le lire
  SharedPreferences.getInstance().then((prefs) {
    prefs.setBool(_kIsWatchingLiveKey, true);
  });
  debugPrint('[Notifications] Mode lecture actif — notifications suspendues');
}

/// Appeler quand l'utilisateur QUITTE un lecteur vidéo en direct.
/// Un délai de 5 secondes est appliqué pour éviter les spoilers
/// de notifications qui auraient été mises en file d'attente.
void exitLiveWatchMode() {
  _watchingLiveRestoreTimer = Timer(const Duration(seconds: 5), () {
    isWatchingLive = false;
    _watchingLiveRestoreTimer = null;
    // ◄ Réinitialiser la persistance
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_kIsWatchingLiveKey, false);
    });
    debugPrint('[Notifications] Mode lecture terminé — notifications réactivées');
  });
}

/// Lire depuis SharedPreferences (utilisé dans le background isolate).
/// Retourne `false` si la clé n'existe pas.
Future<bool> isWatchingLivePersisted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kIsWatchingLiveKey) ?? false;
}
