import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_units.dart';

class AdMobService {
  const AdMobService._();

  static AppOpenAd? _appOpenAd;
  static bool _isShowingAd = false;
  static bool _isAppOpenAdLoaded = false;
  static DateTime? _appOpenLoadTime;

  static Future<void> initialize() async {
    if (!AdUnits.isSupported) return;

    try {
      await MobileAds.instance.initialize();
      await loadAppOpenAd();
      await showAppOpenAdIfAvailable();
    } catch (error, stackTrace) {
      debugPrint('AdMob init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> loadAppOpenAd() async {
    if (!AdUnits.isSupported || AdUnits.appOpen.isEmpty) return;

    await AppOpenAd.load(
      adUnitId: AdUnits.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoaded = true;
          _appOpenLoadTime = DateTime.now();
          debugPrint('AppOpenAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _isAppOpenAdLoaded = false;
        },
      ),
    );
  }

  static Future<void> showAppOpenAdIfAvailable() async {
    if (!AdUnits.isSupported) return;
    if (_appOpenAd == null || !_isAppOpenAdLoaded || _isShowingAd) {
      loadAppOpenAd();
      return;
    }

    // Ad expires after 4 hours as per AdMob guidelines
    if (_appOpenLoadTime != null &&
        DateTime.now().difference(_appOpenLoadTime!) >
            const Duration(hours: 4)) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _isAppOpenAdLoaded = false;
      loadAppOpenAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
        loadAppOpenAd(); // Load the next one
      },
    );

    await _appOpenAd!.show();
  }
}
