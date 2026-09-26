# Mundialy — Design System de référence

> Extrait de l'ancien commit **`7166519`** — *chore: bump version to v2.0.5* (2026-07-02).
> Fichiers sources : `lib/constants/app_colors.dart`, `lib/constants/app_sizes.dart`,
> `lib/services/theme_provider.dart`, `lib/main.dart` (`_buildLightTheme` / `_buildDarkTheme`),
> `lib/widgets/*.dart`, `pubspec.yaml`.
> Consolidé dans `flutter_application_1/lib/theme/app_theme.dart` (`AppTheme.light()` / `AppTheme.dark()`).
> Aucune police custom : typographie = Material par défaut, teintée via `textTheme.apply`.

## 1. Palette (AppColors)

| Token       | Hex       | Rôle DS d'origine                              |
|-------------|-----------|------------------------------------------------|
| `primary`   | `0xFF16324A` | Bleu nuit — boutons, icônes clair, texte clair |
| `secondary` | `0xFFE7C16A` | Or champagne — sélection, curseur, accents     |
| `background`| `0xFFF7F2E8` | Fond scaffold mode clair                       |
| `surface`   | `0xFFFFFBF5` | Cartes mode clair (alpha 0.96)                 |
| `error`     | `0xFFB3261E` | Erreurs                                        |
| `accent`    | `0xFF2C4E6D` | Bleu secondaire                                |
| `ink`       | `0xFF0E1A24` | Fond scaffold mode sombre                      |
| `white`     | `0xFFFFFFFF` | —                                              |
| `black`     | `0xFF000000` | —                                              |

Couleurs thème complémentaires (définies dans les ThemeData, pas dans AppColors) :

| Hex           | Usage DS                                              |
|---------------|-------------------------------------------------------|
| `0xFFD8C8A8`  | `dividerColor` mode clair                             |
| `0xFF5B6B79`  | BottomNav non-sélectionné (clair)                     |
| `0xFF162634`  | Fond de carte mode sombre                             |
| `0xFFE53935` | Pastille LIVE, score live, border live (clair + sombre, source unique `MatchColors.liveIndicator`) |
| `Colors.white54`   | BottomNav non-sélectionné (sombre)              |

## 2. Typographie

- Aucune `fontFamily` (ni pubspec ni `GoogleFonts`) : Roboto système par défaut.
- Clair : `textTheme.apply(bodyColor: primary, displayColor: primary)`.
- Sombre : `textTheme.apply(bodyColor: white, displayColor: white)`.
- BottomNav : label sélectionné `w700 / 11px`, non-sélectionné `10px`.
- Titres d'écrans : style local historique `w800 / 18px` (ex. top bar détails match).

## 3. Espacements, rayons, tailles (AppSizes)

| Token            | Valeur | Usage DS                        |
|------------------|--------|---------------------------------|
| `paddingXSmall`  | 4      | micro-espacements               |
| `paddingSmall`   | 8      |                                 |
| `paddingMedium`  | 16     | padding standard écrans         |
| `paddingLarge`   | 24     |                                 |
| `paddingXLarge`  | 32     |                                 |
| `radiusSmall`    | 4      |                                 |
| `radiusMedium`   | 8      | blocs skeleton, badges          |
| `radiusLarge`    | 12     |                                 |
| `buttonHeight`   | 48     | hauteur `CustomButton`          |
| `inputHeight`    | 56     | champs de saisie                |

Rayons complémentaires vus dans le thème/widgets : cartes **28**, boutons elevated **20**,
`CustomButton` **18**, bannières/pin **10–14**, skeleton bloc **8** (défaut), pastilles **999/cercle**.
Élévation : **0 partout** (cartes, boutons, appbars transparentes), sauf BottomNav (**8**).

## 4. Thème clair / sombre (résumé)

| Propriété        | Clair                        | Sombre              |
|------------------|------------------------------|---------------------|
| scaffold         | `background` (crème)         | `ink`               |
| appbar           | transparente, texte primary  | transparente, blanc |
| cartes           | `surface` @0.96, radius 28   | `0xFF162634`, r. 28 |
| bouton elevated  | fond primary, texte blanc    | (hérité dark)       |
| icônes           | primary                      | blanc               |
| divider          | `0xFFD8C8A8`                 | `white12`           |
| curseur texte    | `secondary` (or)             | —                   |

Bascule via `ThemeProvider` (`services/theme_provider.dart`) : `ThemeMode.system/light/dark`,
persisté en SharedPreferences sous la clé `theme_mode`.

## 5. Widgets réutilisables

| Widget | Fichier | Paramètres |
|--------|---------|------------|
| `CustomButton` | `widgets/custom_button.dart` | `label*`, `onPressed*`, `isLoading=false`, `backgroundColor` (défaut primary) |
| `BouncingCard` | `widgets/bouncing_card.dart` | `child*`, `onTap*`, `scaleFactor=0.96` (100 ms / 150 ms) |
| `NationFlagBadge` | `widgets/nation_flag_badge.dart` | `countryCode*`, `size*`, `imageUrlOverride?`, `teamName?` (losange blanc + fallback initiales) |
| `PinMatchButton` | `widgets/pin_match_button.dart` | `onTap*`, `compact=false` (dégradé or adaptatif clair/sombre) |
| `MundialyLogo` | `widgets/mundialy_logo.dart` | `size=28`, `showLabel=false` (`assets/logo.png`) |
| `FadeSlideEntrance` | `widgets/fade_slide_entrance.dart` | `child*`, `delay=Duration.zero` (500 ms, easeOutCubic, +30px) |
| `SkeletonBlock` | `widgets/loading_skeletons.dart` | `height*`, `width?`, `radius=8`, `color?` |
| `SkeletonCard` | `widgets/loading_skeletons.dart` | `margin`, `child` |
| `SkeletonShimmer` | `widgets/loading_skeletons.dart` | `child*`, `isDark?` (package `shimmer`) |
| `MatchListSkeleton` | `widgets/loading_skeletons.dart` | `isDark*`, `itemCount=6` |
| `MatchDetailsSkeleton` | `widgets/loading_skeletons.dart` | — |
| `InAppNotification.show` | `widgets/in_app_notification.dart` | `context, homeTeam, awayTeam, matchMinute?, title, message, {isGoal=true}` (overlay 5 s) |
| `AnimatedGoalOverlay` | `widgets/animated_goal_overlay.dart` | `payload*`, `onDismiss*` |
| `InlineAdaptiveBanner` | `widgets/inline_adaptive_banner.dart` | `horizontalMargin=16`, `verticalMargin=12`, `maxHeight=120` |
| `KoraMatchesSection` | `widgets/kora_matches_section.dart` | section matchs live Kora (⚠️ seul widget DS modifié depuis : +`edges`/`edgeDomain`) |
| `EmptyState` | `widgets/empty_state.dart` | `icon*`, `title*`, `subtitle?`, `iconSize=84` (pastille or + titre + sous-titre) |
| `StatusBadge` | `widgets/status_badge.dart` | `label*`, `color*`, `pulsing=false` (pastille + texte, jamais couleur seule ; respecte reduce-motion) |
| `PlayerAvatar` | `widgets/player_avatar.dart` | `name*`, `imageUrl?`, `size=40` (photo cache + initiale en repli + anneau or) |

## 5b. ThemeExtension du guide UI/UX (dans `app_theme.dart`, câblées dans les 2 thèmes)

| Extension | Tokens | Accès |
|-----------|--------|-------|
| `AppSpacing` | `xs` 4, `sm` 8, `md` 12, `lg` 16 (marge écran / padding carte), `xl` 24, `xxl` 32 | `Theme.of(context).extension<AppSpacing>()!.md` |
| `AppRadii` | `sm` 8, `md` 12, `lg` 16 (carte de match), `xl` 20, `full` 999 (pill) | `...extension<AppRadii>()!.lg` |
| `MatchColors` | `liveIndicator` #E53935 (distinct de `error` B3261E), `win` 2ECC71, `loss` E74C3C, `draw`/`favorite` (or), `rankSilver` E0E0E0, `rankBronze` CD7F32 | `...extension<MatchColors>()!.liveIndicator` |

`main.dart` utilise `AppTheme.light()` / `AppTheme.dark()` (câblé le 2026-09-24,
rendu identique aux builders historiques + extensions actives).

## 6. Polices & assets (pubspec v2.0.5)

- Polices : **aucune** (système uniquement). `uses-material-design: true`.
- Assets : `matches_2022.json`, `match_details_2022.json`, `standings_2022.json`,
  `topscorers_2022.json`, `topscorers_2026_init.json`, `logo.png`, `mundialy_logo.png`,
  `trophy_watermark.png`, `trophy_pitch.png`.

## 7. Écarts constatés avec le code actuel (à refactorer — décision à toi)

**Fichiers DS intacts** : `app_colors.dart`, `app_sizes.dart`, `app_strings.dart`,
`theme_provider.dart`, builders de thème dans `main.dart` et 13/14 widgets sont
**identiques** à l'ancien commit. Le DS n'a pas régressé — ce sont les écrans qui le contournent.

**a) Écrans n'utilisant JAMAIS `AppColors.` / `AppSizes.`** (couleurs recopiées en dur
en constantes locales type `kGold`, `kMatchCardDark`) :
- `screens/home_screen.dart` (60 `Color(0x…)` en dur, 0 `AppColors.`, 0 `AppSizes.`)
- `screens/match_details_screen.dart` (24 en dur)
- `screens/competition_detail_screen.dart` (14 en dur)
- `screens/team_details_screen.dart`, `player_profile_screen.dart`, `news_detail_screen.dart`,
  `matches_list_tab.dart`, `kora_live_webview.dart`, `splash_screen.dart`, tout `screens/iptv/` (0 usage DS)

**b) Familles de couleurs hors-DS introduites par les écrans** (candidats à une extension du DS) :
- Navy sombres : `182531`, `1D2D3B`, `1A2A3A`, `0D1B2A`, `152231`, `1B3A5C`, `1A1A2E`, `1A242D`, `14202A`, `23303C`
  (le DS sombre ne connaît que `ink` + `162634` → **6+ variantes de fond sombre coexistent**)
- Rouge live : `FF4444`, `E05151`, `E74C3C`, `C62828`, `D94141` (+ `redAccent` du DS → **5 rouges live**)
- Vert : `2ECC71`, `1FAE68` (aucun vert dans le DS)
- Or : `C8973A`, `FFD700`, `CD7F32`, `B8860B`, `E9BE32`, `E38B2C` (+ `secondary` → **6 ors**)
- Gris/beige texte : `6D7F8C`, `D9E0E6`, `7E8BA0`, `6E7A89`, `F0EBE0`, `F2E5CA`, `E8DECA`

**c) Pires écarts par écran** (couleurs hors-palette dominantes) :
1. `home_screen.dart` — verts `2ECC71` (×6), rouges `E74C3C` (×3), navy `1B3A5C`/`0D1B2A` (×3 ch.)
2. `team_profile_screen.dart` — fond `182531` (×6), texte `6D7F8C`/`D9E0E6` (×12)
3. `match_details_screen.dart` — rouge `E05151` (×7, ≠ redAccent DS), vert `1FAE68` (×6)
4. `matches_tab.dart` (nouvel écran) — `1A2A3A` (×5) au lieu de `ink`/`162634`
5. `match_card.dart` (nouveau widget) — `1A1A2E`, `C62828`, `1A2A3A` en dur
6. `competition_detail_screen.dart` (nouvel écran) — `1A2A3A`, `1A242D`, `0D1B2A`
7. `player_profile_screen.dart` — `1D2D3B`/`182531`, bleu `4DA3FF` (aucun bleu clair au DS)

**d) Nouveaux fichiers sans équivalent dans l'ancien commit** (hors-DS par construction) :
`widgets/match_card.dart`, `widgets/competition_badge.dart`,
`widgets/continent_competition_picker.dart`, `screens/matches_tab.dart`,
`screens/competition_detail_screen.dart`.

## 8. Règles du guide UI/UX (spécial scores foot — appliquées depuis le 2026-09-24)

- **60-30-10** : 60 % neutre/fond, 30 % secondaire, 10 % accent (CTA, badge live).
- **Grille 8pt** : tout espacement ∈ {4, 8, 12, 16, 24, 32} (`AppSpacing`) ; padding carte
  de match 16, marge écran 16, 8 px min entre deux éléments tactiles.
- **Interdit dans `lib/screens/`** : couleur, taille ou padding en dur — uniquement
  widgets `lib/widgets/` + tokens du thème (`AppColors`, `AppSizes`, extensions).
- **Carte de match** : Logo → nom → score (le plus gros, le plus contrasté) → statut/minute ;
  le statut live n'est jamais codé par la seule couleur (texte/icône en plus).
- **États obligatoires** : chargement (skeleton, pas de spinner), vide, erreur, live, terminé.
- **Accessibilité** : contraste 4.5:1 (3:1 gros texte), zones tactiles ≥ 48dp,
  `Semantics()` sur chaque carte/ligne tactile, info jamais couleur-seule.
- **Animations** : 200–500 ms, `Curves.easeOutCubic`, jamais linéaire ;
  respecter `MediaQuery.disableAnimations` ; pull-to-refresh natif ;
  transition liste→détail en fade/scale.
- **Regroupement des Matchs (Phase/Ligue)** : Pour les compétitions à structure complexe (Nations League, etc.), les matchs sont visuellement sous-groupés par phase/ligue (ex: "LEAGUE A - GROUP 1", "SEMI-FINALS") avec un micro-header (barre latérale accent + texte majuscule) si ce n'est pas un match amical. Le `phaseLabel` est calculé dynamiquement pour inclure la Ligue et le Groupe.
- **Dark mode** : jamais une simple inversion — `secondary` reste l'or champagne
  dans les 2 thèmes ; élévation par surcouches, pas par ombres.
- **Checklist écran terminé** : 0 en-dur · clair + sombre testés · contrastes OK ·
  5 états gérés · touch ≥ 48dp espacés de 8px · widgets partagés réutilisés ·
  animations ≤ 500 ms + reduce-motion · petit écran sans débordement.
