import 'dart:async';

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final StreamController<void> refreshStreamController =
    StreamController<void>.broadcast();

// ─────────────────────────────────────────────────────────────────────────────
// MODE LECTURE EN DIRECT — suppression temporaire des notifications
// ─────────────────────────────────────────────────────────────────────────────

/// Vrai si l'utilisateur est en train de regarder un flux en direct
/// (lecteur IPTV ou lecteur live match).
bool isWatchingLive = false;

Timer? _watchingLiveRestoreTimer;

/// Appeler quand l'utilisateur OUVRE un lecteur vidéo en direct.
void enterLiveWatchMode() {
  // Annuler tout timer de restauration en cours
  _watchingLiveRestoreTimer?.cancel();
  _watchingLiveRestoreTimer = null;
  isWatchingLive = true;
  debugPrint('[Notifications] Mode lecture actif — notifications suspendues');
}

/// Appeler quand l'utilisateur QUITTE un lecteur vidéo en direct.
/// Un délai de 5 secondes est appliqué pour éviter les spoilers
/// de notifications qui auraient été mises en file d'attente.
void exitLiveWatchMode() {
  // Délai de grâce de 5 secondes avant de réactiver les notifications
  _watchingLiveRestoreTimer = Timer(const Duration(seconds: 5), () {
    isWatchingLive = false;
    _watchingLiveRestoreTimer = null;
    debugPrint('[Notifications] Mode lecture terminé — notifications réactivées');
  });
}
