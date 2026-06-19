import 'package:flutter/foundation.dart';

class AdUnits {
  const AdUnits._();

  static const String startAppId = '205563396';

  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
