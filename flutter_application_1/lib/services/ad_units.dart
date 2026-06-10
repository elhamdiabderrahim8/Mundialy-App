import 'package:flutter/foundation.dart';

class AdUnits {
  const AdUnits._();

  static const bool useTestAds = true;

  static const String androidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidTestBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBanner =
      'ca-app-pub-3940256099942544/2934735716';

  static const String _androidProductionBanner = '';
  static const String _iosProductionBanner = '';

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String get inlineBanner {
    if (!isSupported) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return useTestAds ? _androidTestBanner : _androidProductionBanner;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return useTestAds ? _iosTestBanner : _iosProductionBanner;
    }
    return '';
  }
}
