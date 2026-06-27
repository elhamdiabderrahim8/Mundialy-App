import 'package:flutter/foundation.dart';
import 'package:startapp_sdk/startapp.dart';
import 'ad_units.dart';

class StartAppService {
  static final StartAppService _instance = StartAppService._internal();
  factory StartAppService() => _instance;
  StartAppService._internal();

  final StartAppSdk _startAppSdk = StartAppSdk();
  StartAppInterstitialAd? _interstitialAd;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;

  static Future<void> initialize() async {
    if (!AdUnits.isSupported) return;

    try {
      if (kDebugMode) {
        _instance._startAppSdk.setTestAdsEnabled(true);
      }
      // StartApp Return Ads are enabled by default. Nous supprimons l'appel
      // manuel à disableReturnAds car il n'est pas défini dans ce SDK Flutter.
      
      await _instance._loadAppOpenAd();
    } catch (error, stackTrace) {
      debugPrint('StartApp init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadAppOpenAd() async {
    if (!AdUnits.isSupported) return;

    try {
      final ad = await _startAppSdk.loadInterstitialAd();
      _interstitialAd = ad;
      _appOpenLoadTime = DateTime.now();
      debugPrint('StartApp Interstitial loaded successfully');
    } catch (error) {
      debugPrint('StartApp Interstitial failed to load: $error');
      _interstitialAd = null;
    }
  }

  static Future<void> showAppOpenAdIfAvailable() async {
    if (!AdUnits.isSupported) return;
    
    if (_instance._interstitialAd == null || _instance._isShowingAd) {
      _instance._loadAppOpenAd();
      return;
    }

    // Refresh ad if older than 4 hours (similar to AdMob policy)
    if (_instance._appOpenLoadTime != null &&
        DateTime.now().difference(_instance._appOpenLoadTime!) > const Duration(hours: 4)) {
      _instance._interstitialAd = null;
      await _instance._loadAppOpenAd();
      if (_instance._interstitialAd == null) return;
    }

    _instance._isShowingAd = true;
    try {
      final shown = await _instance._interstitialAd!.show();
      if (shown) {
        debugPrint('StartApp Interstitial shown');
      } else {
        debugPrint('StartApp Interstitial failed to show');
      }
    } catch (e) {
      debugPrint('StartApp Error showing ad: $e');
    } finally {
      _instance._isShowingAd = false;
      _instance._interstitialAd = null; // Important: nullify
      _instance._loadAppOpenAd(); // Preload next one
    }
  }
}
