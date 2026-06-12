import 'package:flutter/foundation.dart';

class AdUnits {
  const AdUnits._();

  static bool get useTestAds => kDebugMode;

  static const String androidAppId = 'ca-app-pub-1247207419826743~3215224806';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidTestBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const String _androidTestAppOpen =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _iosTestAppOpen =
      'ca-app-pub-3940256099942544/5575463023';

  static const String _androidProductionBanner =
      'ca-app-pub-1247207419826743/1505792978';
  static const String _androidProductionAppOpen =
      'ca-app-pub-1247207419826743/2487702150';
  static const String _iosProductionBanner = '';
  static const String _iosProductionAppOpen = '';

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

  static String get appOpen {
    if (!isSupported) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return useTestAds ? _androidTestAppOpen : _androidProductionAppOpen;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return useTestAds ? _iosTestAppOpen : _iosProductionAppOpen;
    }
    return '';
  }
}
