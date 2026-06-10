import 'package:flutter/foundation.dart';

class AdUnits {
  const AdUnits._();

  static bool get useTestAds => kDebugMode;

  static const String androidAppId = 'ca-app-pub-1247207419826743~3215224806';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidTestBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const String _androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  static const String _androidProductionBanner =
      'ca-app-pub-1247207419826743/7799627213';
  static const String _androidProductionInterstitial =
      'ca-app-pub-1247207419826743/5093572824';
  static const String _iosProductionBanner = '';
  static const String _iosProductionInterstitial = '';

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

  static String get interstitial {
    if (!isSupported) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return useTestAds
          ? _androidTestInterstitial
          : _androidProductionInterstitial;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return useTestAds ? _iosTestInterstitial : _iosProductionInterstitial;
    }
    return '';
  }
}
