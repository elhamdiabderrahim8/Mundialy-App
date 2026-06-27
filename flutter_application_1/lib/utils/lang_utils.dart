import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class LangUtils {
  static String _currentLocale = 'fr'; // Default

  static void setLocale(String locale) {
    if (['fr', 'en', 'ar'].contains(locale)) {
      _currentLocale = locale;
    } else {
      _currentLocale = 'en'; // Default fallback
    }
  }

  static String get currentLocale => _currentLocale;

  static bool get isRtl => _currentLocale == 'ar';

  // 365Scores language mapping
  static int get scores365LangCode {
    switch (_currentLocale) {
      case 'fr': return 15; // User says it's 15
      case 'ar': return 27;
      default: return 1; // English
    }
  }

  static String getTranslatedEventTitle(dynamic icon, String originalTitle, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final iconStr = icon.toString();
    if (iconStr.contains('goal') && !iconStr.contains('own') && !iconStr.contains('penalty') && !iconStr.contains('cancelled')) return loc.goal;
    if (iconStr.contains('ownGoal')) return loc.ownGoal;
    if (iconStr.contains('penaltyGoal')) return loc.penaltyGoal;
    if (iconStr.contains('penaltyMissed')) return loc.penaltyMissed;
    if (iconStr.contains('yellowCard')) return loc.yellowCard;
    if (iconStr.contains('redCard')) return loc.redCard;
    if (iconStr.contains('substitution')) return loc.substitution;
    if (iconStr.contains('varReview')) return loc.varReview;
    if (iconStr.contains('offside')) return loc.offside;
    if (iconStr.contains('cancelledGoal')) return loc.cancelled;
    return originalTitle;
  }

  static String? normalizePhase(String raw) {
    final v = raw.toLowerCase().replaceAll('_', ' ');
    if (v.contains('round of 32') ||
        v.contains('16th') ||
        v.contains('seizième') ||
        v.contains('1/16') ||
        v.contains('32') ||
        v.contains('جولة 32') ||
        v.contains('tour de 32') ||
        v.trim() == 'round' ||
        v.trim() == 'جولة' ||
        v.trim() == 'الجولة' ||
        v.trim() == 'tour') {
      return 'Round of 32';
    }
    if (v.contains('round of 16') ||
        v.contains('8th finals') ||
        v.contains('huitième') ||
        v.contains('1/8') ||
        v.contains('16')) {
      return 'Round of 16';
    }
    if (v.contains('quarter') || v.contains('quart') || v.contains('1/4') || v.contains('ربع') || v.contains('8')) {
      return 'Quarter-finals';
    }
    if (v.contains('semi') || v.contains('demi') || v.contains('1/2') || v.contains('نصف') || v.contains('نهايى') || v.contains('نهائي') && !v.contains('ربع') && !v.contains('ثمن') && v.contains('نصف')) {
      return 'Semi-finals';
    }
    if (v.contains('third place') || v.contains('troisième') || v.contains('ثالث') || v.contains('المركز الثالث')) {
      return 'Third place';
    }
    if (v == 'final' ||
        (v.contains('final') &&
            !v.contains('semi') &&
            !v.contains('quarter')) || v.contains('نهائي') && !v.contains('نصف') && !v.contains('ربع') && !v.contains('ثمن') || v.contains('finale') && !v.contains('demi') && !v.contains('quart')) {
      return 'Final';
    }
    return null;
  }

  static String getTranslatedPhase(String originalPhase, BuildContext context) {
    final normalized = normalizePhase(originalPhase);
    if (normalized != null) {
      final loc = AppLocalizations.of(context)!;
      switch (normalized) {
        case 'Round of 32': return loc.roundOf32;
        case 'Round of 16': return loc.roundOf16;
        case 'Quarter-finals': return loc.quarterFinal;
        case 'Semi-finals': return loc.semiFinal;
        case 'Third place': return loc.thirdPlace;
        case 'Final': return loc.final_;
      }
    }
    return originalPhase;
  }
}
