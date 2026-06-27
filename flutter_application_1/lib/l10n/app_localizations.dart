import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mundialy'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @live.
  ///
  /// In fr, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @matches.
  ///
  /// In fr, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @groups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groups;

  /// No description provided for @scorers.
  ///
  /// In fr, this message translates to:
  /// **'Buteurs'**
  String get scorers;

  /// No description provided for @bracket.
  ///
  /// In fr, this message translates to:
  /// **'Bracket'**
  String get bracket;

  /// No description provided for @finalPhase.
  ///
  /// In fr, this message translates to:
  /// **'PHASE FINALE'**
  String get finalPhase;

  /// No description provided for @groupStage.
  ///
  /// In fr, this message translates to:
  /// **'PHASE DE GROUPES'**
  String get groupStage;

  /// No description provided for @worldCup2022.
  ///
  /// In fr, this message translates to:
  /// **'WORLD CUP 2022'**
  String get worldCup2022;

  /// No description provided for @worldCup2026.
  ///
  /// In fr, this message translates to:
  /// **'WORLD CUP 2026'**
  String get worldCup2026;

  /// No description provided for @matchInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations du match'**
  String get matchInfo;

  /// No description provided for @referee.
  ///
  /// In fr, this message translates to:
  /// **'Arbitre'**
  String get referee;

  /// No description provided for @stadium.
  ///
  /// In fr, this message translates to:
  /// **'Stade'**
  String get stadium;

  /// No description provided for @city.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get city;

  /// No description provided for @kickoff.
  ///
  /// In fr, this message translates to:
  /// **'Heure de debut'**
  String get kickoff;

  /// No description provided for @finished.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get finished;

  /// No description provided for @liveNow.
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get liveNow;

  /// No description provided for @notStarted.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get notStarted;

  /// No description provided for @postponed.
  ///
  /// In fr, this message translates to:
  /// **'Reporté'**
  String get postponed;

  /// No description provided for @lineup.
  ///
  /// In fr, this message translates to:
  /// **'Composition'**
  String get lineup;

  /// No description provided for @startingXI.
  ///
  /// In fr, this message translates to:
  /// **'Composition de départ'**
  String get startingXI;

  /// No description provided for @substitutes.
  ///
  /// In fr, this message translates to:
  /// **'Remplaçants'**
  String get substitutes;

  /// No description provided for @coach.
  ///
  /// In fr, this message translates to:
  /// **'Entraîneur'**
  String get coach;

  /// No description provided for @stats.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get stats;

  /// No description provided for @events.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get events;

  /// No description provided for @shootout.
  ///
  /// In fr, this message translates to:
  /// **'SÉANCE DE TIRS AU BUT'**
  String get shootout;

  /// No description provided for @halfTime.
  ///
  /// In fr, this message translates to:
  /// **'Mi-temps'**
  String get halfTime;

  /// No description provided for @fullTime.
  ///
  /// In fr, this message translates to:
  /// **'Temps réglementaire'**
  String get fullTime;

  /// No description provided for @extraTime.
  ///
  /// In fr, this message translates to:
  /// **'Prolongations'**
  String get extraTime;

  /// No description provided for @penaltyShootout.
  ///
  /// In fr, this message translates to:
  /// **'Tirs au but'**
  String get penaltyShootout;

  /// No description provided for @goal.
  ///
  /// In fr, this message translates to:
  /// **'BUT'**
  String get goal;

  /// No description provided for @ownGoal.
  ///
  /// In fr, this message translates to:
  /// **'BUT CONTRE SON CAMP'**
  String get ownGoal;

  /// No description provided for @penaltyGoal.
  ///
  /// In fr, this message translates to:
  /// **'PENALTY MARQUÉ'**
  String get penaltyGoal;

  /// No description provided for @penaltyMissed.
  ///
  /// In fr, this message translates to:
  /// **'PENALTY MANQUÉ'**
  String get penaltyMissed;

  /// No description provided for @yellowCard.
  ///
  /// In fr, this message translates to:
  /// **'CARTON JAUNE'**
  String get yellowCard;

  /// No description provided for @redCard.
  ///
  /// In fr, this message translates to:
  /// **'CARTON ROUGE'**
  String get redCard;

  /// No description provided for @substitution.
  ///
  /// In fr, this message translates to:
  /// **'REMPLACEMENT'**
  String get substitution;

  /// No description provided for @varReview.
  ///
  /// In fr, this message translates to:
  /// **'VAR'**
  String get varReview;

  /// No description provided for @offside.
  ///
  /// In fr, this message translates to:
  /// **'HORS-JEU'**
  String get offside;

  /// No description provided for @cancelled.
  ///
  /// In fr, this message translates to:
  /// **'BUT ANNULÉ'**
  String get cancelled;

  /// No description provided for @goals.
  ///
  /// In fr, this message translates to:
  /// **'Buts'**
  String get goals;

  /// No description provided for @assists.
  ///
  /// In fr, this message translates to:
  /// **'Passes déc.'**
  String get assists;

  /// No description provided for @shotsTotal.
  ///
  /// In fr, this message translates to:
  /// **'Tirs'**
  String get shotsTotal;

  /// No description provided for @shotsOnTarget.
  ///
  /// In fr, this message translates to:
  /// **'Tirs cadrés'**
  String get shotsOnTarget;

  /// No description provided for @possession.
  ///
  /// In fr, this message translates to:
  /// **'Possession'**
  String get possession;

  /// No description provided for @passes.
  ///
  /// In fr, this message translates to:
  /// **'Passes'**
  String get passes;

  /// No description provided for @corners.
  ///
  /// In fr, this message translates to:
  /// **'Corners'**
  String get corners;

  /// No description provided for @fouls.
  ///
  /// In fr, this message translates to:
  /// **'Fautes'**
  String get fouls;

  /// No description provided for @offsides.
  ///
  /// In fr, this message translates to:
  /// **'Hors-jeux'**
  String get offsides;

  /// No description provided for @scorersTitle.
  ///
  /// In fr, this message translates to:
  /// **'CLASSEMENT DES BUTEURS'**
  String get scorersTitle;

  /// No description provided for @goalsLabel.
  ///
  /// In fr, this message translates to:
  /// **'buts'**
  String get goalsLabel;

  /// No description provided for @assistsLabel.
  ///
  /// In fr, this message translates to:
  /// **'passes'**
  String get assistsLabel;

  /// No description provided for @matchesLabel.
  ///
  /// In fr, this message translates to:
  /// **'matchs'**
  String get matchesLabel;

  /// No description provided for @minutesLabel.
  ///
  /// In fr, this message translates to:
  /// **'min'**
  String get minutesLabel;

  /// No description provided for @noScorers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun buteur pour le moment'**
  String get noScorers;

  /// No description provided for @groupTable.
  ///
  /// In fr, this message translates to:
  /// **'CLASSEMENT DU GROUPE'**
  String get groupTable;

  /// No description provided for @played.
  ///
  /// In fr, this message translates to:
  /// **'J'**
  String get played;

  /// No description provided for @wins.
  ///
  /// In fr, this message translates to:
  /// **'V'**
  String get wins;

  /// No description provided for @draws.
  ///
  /// In fr, this message translates to:
  /// **'N'**
  String get draws;

  /// No description provided for @losses.
  ///
  /// In fr, this message translates to:
  /// **'D'**
  String get losses;

  /// No description provided for @points.
  ///
  /// In fr, this message translates to:
  /// **'Pts'**
  String get points;

  /// No description provided for @goalsFor.
  ///
  /// In fr, this message translates to:
  /// **'BP'**
  String get goalsFor;

  /// No description provided for @goalsAgainst.
  ///
  /// In fr, this message translates to:
  /// **'BC'**
  String get goalsAgainst;

  /// No description provided for @goalDiff.
  ///
  /// In fr, this message translates to:
  /// **'+/-'**
  String get goalDiff;

  /// No description provided for @roundOf32.
  ///
  /// In fr, this message translates to:
  /// **'16es de finale'**
  String get roundOf32;

  /// No description provided for @roundOf16.
  ///
  /// In fr, this message translates to:
  /// **'Huitièmes de finale'**
  String get roundOf16;

  /// No description provided for @quarterFinal.
  ///
  /// In fr, this message translates to:
  /// **'Quarts de finale'**
  String get quarterFinal;

  /// No description provided for @semiFinal.
  ///
  /// In fr, this message translates to:
  /// **'Demi-finales'**
  String get semiFinal;

  /// No description provided for @final_.
  ///
  /// In fr, this message translates to:
  /// **'Finale'**
  String get final_;

  /// No description provided for @thirdPlace.
  ///
  /// In fr, this message translates to:
  /// **'3e place'**
  String get thirdPlace;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée disponible'**
  String get noData;

  /// No description provided for @playerProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil du Joueur'**
  String get playerProfile;

  /// No description provided for @nationality.
  ///
  /// In fr, this message translates to:
  /// **'Nationalité'**
  String get nationality;

  /// No description provided for @age.
  ///
  /// In fr, this message translates to:
  /// **'Âge'**
  String get age;

  /// No description provided for @position.
  ///
  /// In fr, this message translates to:
  /// **'Poste'**
  String get position;

  /// No description provided for @club.
  ///
  /// In fr, this message translates to:
  /// **'Club'**
  String get club;

  /// No description provided for @height.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get weight;

  /// No description provided for @years.
  ///
  /// In fr, this message translates to:
  /// **'ans'**
  String get years;

  /// No description provided for @teamProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil de l\'Équipe'**
  String get teamProfile;

  /// No description provided for @players.
  ///
  /// In fr, this message translates to:
  /// **'Joueurs'**
  String get players;

  /// No description provided for @formation.
  ///
  /// In fr, this message translates to:
  /// **'Formation'**
  String get formation;

  /// No description provided for @switchTheme.
  ///
  /// In fr, this message translates to:
  /// **'Changer de thème'**
  String get switchTheme;

  /// No description provided for @switchYear.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'année'**
  String get switchYear;

  /// No description provided for @noMatchesFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun match trouvé'**
  String get noMatchesFound;

  /// No description provided for @liveMatches.
  ///
  /// In fr, this message translates to:
  /// **'Matchs en cours'**
  String get liveMatches;

  /// No description provided for @upcomingMatches.
  ///
  /// In fr, this message translates to:
  /// **'Prochains matchs'**
  String get upcomingMatches;

  /// No description provided for @newsFifa.
  ///
  /// In fr, this message translates to:
  /// **'ACTUALITÉS FIFA'**
  String get newsFifa;

  /// No description provided for @latestNews.
  ///
  /// In fr, this message translates to:
  /// **'Les dernières nouvelles du Mondial'**
  String get latestNews;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'TOUT'**
  String get all;

  /// No description provided for @standingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'CLASSEMENTS'**
  String get standingsTitle;

  /// No description provided for @groupPhaseOfficial.
  ///
  /// In fr, this message translates to:
  /// **'Phase de groupes – Classement officiel'**
  String get groupPhaseOfficial;

  /// No description provided for @schedule.
  ///
  /// In fr, this message translates to:
  /// **'PROGRAMME'**
  String get schedule;

  /// No description provided for @newsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Actualités indisponibles'**
  String get newsUnavailable;

  /// No description provided for @iptvTitle.
  ///
  /// In fr, this message translates to:
  /// **'TV En Direct'**
  String get iptvTitle;

  /// No description provided for @iptvSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Regardez vos chaînes en direct'**
  String get iptvSubtitle;

  /// No description provided for @iptvConnectM3u.
  ///
  /// In fr, this message translates to:
  /// **'Diffusion en direct'**
  String get iptvConnectM3u;

  /// No description provided for @iptvConnectM3uSub.
  ///
  /// In fr, this message translates to:
  /// **'Lancer la lecture des chaînes sport en un clic'**
  String get iptvConnectM3uSub;

  /// No description provided for @iptvEnterUrl.
  ///
  /// In fr, this message translates to:
  /// **'Saisir l\'URL de votre playlist'**
  String get iptvEnterUrl;

  /// No description provided for @iptvConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours...'**
  String get iptvConnecting;

  /// No description provided for @iptvChannels.
  ///
  /// In fr, this message translates to:
  /// **'Chaînes disponibles'**
  String get iptvChannels;

  /// No description provided for @iptvSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une chaîne...'**
  String get iptvSearch;

  /// No description provided for @iptvNoChannels.
  ///
  /// In fr, this message translates to:
  /// **'Aucune chaîne trouvée'**
  String get iptvNoChannels;

  /// No description provided for @iptvError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la playlist'**
  String get iptvError;

  /// No description provided for @iptvDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get iptvDisconnect;

  /// No description provided for @iptvWatching.
  ///
  /// In fr, this message translates to:
  /// **'Lecture en direct'**
  String get iptvWatching;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
