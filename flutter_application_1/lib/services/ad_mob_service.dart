import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_units.dart';

class AdMobService {
  const AdMobService._();

  static Future<void> initialize() async {
    if (!AdUnits.isSupported) return;

    try {
      await MobileAds.instance.initialize();
    } catch (error, stackTrace) {
      debugPrint('AdMob init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
