import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_units.dart';

class AdMobService {
  const AdMobService._();

  static InterstitialAd? _interstitialAd;
  static bool _isLoadingInterstitial = false;
  static int _navigationActionsSinceAd = 0;
  static DateTime? _lastInterstitialShownAt;

  static Future<void> initialize() async {
    if (!AdUnits.isSupported) return;

    try {
      await MobileAds.instance.initialize();
      await _loadInterstitial();
    } catch (error, stackTrace) {
      debugPrint('AdMob init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> maybeShowInterstitialAfterNavigation() async {
    if (!AdUnits.isSupported || AdUnits.interstitial.isEmpty) return;

    _navigationActionsSinceAd++;
    final lastShown = _lastInterstitialShownAt;
    final isCoolingDown =
        lastShown != null &&
        DateTime.now().difference(lastShown) < const Duration(seconds: 90);

    if (_navigationActionsSinceAd < 3 || isCoolingDown) {
      if (_interstitialAd == null) await _loadInterstitial();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      await _loadInterstitial();
      return;
    }

    _interstitialAd = null;
    _navigationActionsSinceAd = 0;
    _lastInterstitialShownAt = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        _loadInterstitial();
      },
    );

    await ad.show();
  }

  static Future<void> _loadInterstitial() async {
    if (_isLoadingInterstitial || _interstitialAd != null) return;
    if (!AdUnits.isSupported || AdUnits.interstitial.isEmpty) return;

    _isLoadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _isLoadingInterstitial = false;
        },
      ),
    );
  }
}
