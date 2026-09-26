// lib/widgets/match_card.dart
// Carte match UNIQUE de l'app — respecte 100% le design system Mundialy.
// Règles appliquées :
//  - Rouge LIVE unifié (#E53935) pour border + minute + score (point 1)
//  - Hiérarchie typographique claire (point 2)
//  - Badge TERMINÉ même position/format que la minute live (point 3)
//  - Carte terminée avec border neutre 1px (point 3)
//  - Grille 8px pour tous les paddings (point 5)
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/live_match.dart';
import '../services/api_service.dart';
import '../utils/app_routes.dart';
import '../utils/lang_utils.dart';
import '../utils/team_navigation.dart';
import '../screens/match_details_screen.dart';
import 'bouncing_card.dart';
import 'fade_slide_entrance.dart';
import 'nation_flag_badge.dart';
import 'pin_match_button.dart';

/// ─── Design tokens ───────────────────────────────────────────────────────────
/// Or champagne (identité Mundialy)
const Color kMatchCardGold = Color(0xFFE7C16A);
/// Fond carte dark
const Color kMatchCardDark = Color(0xFF1D2D3B);
/// Rouge LIVE — unifié border + minute + score (WCAG AA sur fonds sombres).
/// Ancienne valeur : Colors.redAccent (#FF5252). Nouvelle : #E53935.
const Color kLiveRed = Color(0xFFE53935);

class MatchCard extends StatelessWidget {
  final LiveMatch match;
  final int year;
  final Color textColor;
  const MatchCard({
    super.key,
    required this.match,
    required this.year,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (match.isLive) {
      return FadeSlideEntrance(child: _buildLiveCard(context, isDark));
    }
    return FadeSlideEntrance(child: _buildStandardCard(context, isDark));
  }

  // ─── CARTE LIVE ──────────────────────────────────────────────────────────────
  Widget _buildLiveCard(BuildContext context, bool isDark) {
    final String scoreText = match.scoreHome != null
        ? '${match.scoreHome} - ${match.scoreAway}'
        : '– –';
    final String? penaltyText =
        (match.penaltyHome != null && match.penaltyAway != null)
            ? '(${match.penaltyHome}-${match.penaltyAway} tab)'
            : null;

    final Color cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final Color teamColor = isDark ? Colors.white : const Color(0xFF1A2A3A);

    return Container(
      // Grille 8px : margin bottom = 12 (8+4, arrondi à 12 pour respirer)
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        // [Fix 1] Border LIVE unifié — même couleur que score + minute
        border: Border.all(color: kLiveRed.withValues(alpha: 0.65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kLiveRed.withValues(alpha: isDark ? 0.14 : 0.09),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: BouncingCard(
          onTap: () => Navigator.of(context).push(
            PremiumPageRoute(page: MatchDetailsScreen(match: match)),
          ),
          child: Padding(
            // Grille 8px : 16/8/16/12
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1 : Pulse + minute + épingler ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingLiveDot(),
                        const SizedBox(width: 6),
                        // [Fix 1] Rouge unifié pour la minute
                        Text(
                          match.statusDisplay,
                          style: const TextStyle(
                            color: kLiveRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    PinMatchButton(
                      compact: true,
                      onTap: () => _pinMatch(context, match),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Row 2 : équipes + score ─────────────────────────────────
                Row(
                  children: [
                    // Équipe domicile (droite)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: match.homeTeamId == null
                                  ? null
                                  : () => openTeamProfile(
                                        context,
                                        teamName: match.homeTeam,
                                        teamId: match.homeTeamId,
                                        year: match.dateTime?.year ?? 2026,
                                        competitionId: match.competitionId,
                                      ),
                              child: Text(
                                match.homeTeam,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: teamColor,
                                  // [Fix 2] Bold uniforme pour les 2 équipes live
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Hero(
                            tag: 'logo_home_${match.id}',
                            flightShuttleBuilder: (_, __, ___, ____, _____) =>
                                Material(
                              type: MaterialType.transparency,
                              child: NationFlagBadge(
                                countryCode: match.homeCode,
                                teamName: match.homeTeam,
                                size: 24,
                              ),
                            ),
                            child: NationFlagBadge(
                              countryCode: match.homeCode,
                              teamName: match.homeTeam,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score centré
                    SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(scale: anim, child: child),
                            ),
                            child: Text(
                              scoreText,
                              key: ValueKey(scoreText),
                              style: const TextStyle(
                                // [Fix 1] Rouge unifié pour le score live
                                color: kLiveRed,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (penaltyText != null)
                            Text(
                              penaltyText,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : Colors.black.withValues(alpha: 0.45),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Équipe extérieure (gauche)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'logo_away_${match.id}',
                            flightShuttleBuilder: (_, __, ___, ____, _____) =>
                                Material(
                              type: MaterialType.transparency,
                              child: NationFlagBadge(
                                countryCode: match.awayCode,
                                teamName: match.awayTeam,
                                size: 24,
                              ),
                            ),
                            child: NationFlagBadge(
                              countryCode: match.awayCode,
                              teamName: match.awayTeam,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: GestureDetector(
                              onTap: match.awayTeamId == null
                                  ? null
                                  : () => openTeamProfile(
                                        context,
                                        teamName: match.awayTeam,
                                        teamId: match.awayTeamId,
                                        year: match.dateTime?.year ?? 2026,
                                        competitionId: match.competitionId,
                                      ),
                              child: Text(
                                match.awayTeam,
                                style: TextStyle(
                                  color: teamColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── CARTE STANDARD (upcoming + terminé) ────────────────────────────────────
  Widget _buildStandardCard(BuildContext context, bool isDark) {
    final String centerText = match.scoreHome != null
        ? '${match.scoreHome} - ${match.scoreAway}'
        : 'VS';
    final String? penaltyText =
        (match.penaltyHome != null && match.penaltyAway != null)
            ? '(${match.penaltyHome} - ${match.penaltyAway} TAB)'
            : null;

    // [Fix 2] Déterminer le vainqueur pour la règle "gagnant en bold"
    final bool homeWon = match.isFinished &&
        match.scoreHome != null &&
        match.scoreAway != null &&
        match.scoreHome! > match.scoreAway!;
    final bool awayWon = match.isFinished &&
        match.scoreHome != null &&
        match.scoreAway != null &&
        match.scoreAway! > match.scoreHome!;

    return Container(
      // Grille 8px
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? kMatchCardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        // [Fix 3] Border TOUJOURS présent — neutre pour terminé, transparent pour à venir
        border: Border.all(
          color: match.isFinished
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.10))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
          width: 1,
        ),
        boxShadow: [
          if (!match.isFinished)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: BouncingCard(
          onTap: () => Navigator.of(context).push(
            PremiumPageRoute(page: MatchDetailsScreen(match: match)),
          ),
          child: Opacity(
            // [Fix 3] Terminé → 75% d'opacité (lisible mais distinct du live/upcoming)
            opacity: match.isFinished ? 0.75 : 1.0,
            child: Padding(
              // Grille 8px : 16 sur tous les côtés
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // ── Row 1 : statut + phase ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // [Fix 3] Badge TERMINÉ même taille/position que la minute live
                      Flexible(
                        child: match.isFinished
                            ? _TermineBadge(isDark: isDark)
                            : Text(
                                match.localTime,
                                style: const TextStyle(
                                  color: kMatchCardGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const SizedBox(width: 8),
                      // Phase label (groupe, round...)
                      Flexible(
                        flex: 2,
                        child: Text(
                          LangUtils.getTranslatedPhase(match.phaseLabel, context),
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.38),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Grille 8px : 16px entre header et équipes
                  const SizedBox(height: 16),
                  // ── Row 2 : équipes + score ──────────────────────────────
                  Row(
                    children: [
                      // Domicile
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: match.homeTeamId == null
                                    ? null
                                    : () => openTeamProfile(
                                          context,
                                          teamName: match.homeTeam,
                                          teamId: match.homeTeamId,
                                          year: match.dateTime?.year ?? 2026,
                                          competitionId: match.competitionId,
                                        ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    match.homeTeam,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: textColor,
                                      // [Fix 2] Gagnant en w800, autre en w500
                                      fontWeight: homeWon
                                          ? FontWeight.w800
                                          : (awayWon
                                              ? FontWeight.w500
                                              : FontWeight.w700),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Hero(
                              tag: 'logo_home_${match.id}',
                              flightShuttleBuilder:
                                  (_, __, ___, ____, _____) => Material(
                                type: MaterialType.transparency,
                                child: NationFlagBadge(
                                  countryCode: match.homeCode,
                                  teamName: match.homeTeam,
                                  size: 24,
                                ),
                              ),
                              child: NationFlagBadge(
                                countryCode: match.homeCode,
                                teamName: match.homeTeam,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Score / VS
                      Container(
                        width: 80,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, -0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                              child: Text(
                                centerText,
                                key: ValueKey<String>(centerText),
                                style: const TextStyle(
                                  color: kMatchCardGold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (penaltyText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  penaltyText,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Extérieur
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'logo_away_${match.id}',
                              flightShuttleBuilder:
                                  (_, __, ___, ____, _____) => Material(
                                type: MaterialType.transparency,
                                child: NationFlagBadge(
                                  countryCode: match.awayCode,
                                  teamName: match.awayTeam,
                                  size: 24,
                                ),
                              ),
                              child: NationFlagBadge(
                                countryCode: match.awayCode,
                                teamName: match.awayTeam,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: GestureDetector(
                                onTap: match.awayTeamId == null
                                    ? null
                                    : () => openTeamProfile(
                                          context,
                                          teamName: match.awayTeam,
                                          teamId: match.awayTeamId,
                                          year: match.dateTime?.year ?? 2026,
                                          competitionId: match.competitionId,
                                        ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    match.awayTeam,
                                    style: TextStyle(
                                      color: textColor,
                                      // [Fix 2] Gagnant en w800, autre en w500
                                      fontWeight: awayWon
                                          ? FontWeight.w800
                                          : (homeWon
                                              ? FontWeight.w500
                                              : FontWeight.w700),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pinMatch(BuildContext context, LiveMatch match) async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (await FlutterOverlayWindow.isActive()) {
      FlutterOverlayWindow.closeOverlay();
    }

    ApiService.pinnedMatchId = match.id;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'Live Score',
      overlayContent: 'Match en cours',
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.centerLeft,
      visibility: NotificationVisibility.visibilityPublic,
      width: WindowSize.matchParent,
      height: 120,
    );

    FlutterOverlayWindow.shareData({
      'home': match.homeTeam,
      'away': match.awayTeam,
      'homeCode': match.homeCode,
      'awayCode': match.awayCode,
      'score': '${match.scoreHome ?? 0} - ${match.scoreAway ?? 0}',
      'minute': match.matchMinute ?? '',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Match ${match.homeTeam} épinglé sur l\'écran d\'accueil !',
          ),
          backgroundColor: kMatchCardGold,
        ),
      );
    }
  }
}

// ─── Badge "TERMINÉ" ──────────────────────────────────────────────────────────
// [Fix 3] Même hauteur/format que le bloc minute pour homogénéité.
class _TermineBadge extends StatelessWidget {
  const _TermineBadge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Fond gris subtil — distinguable mais discret
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'TERMINÉ',
        style: TextStyle(
          // Couleur plus contrastée que l'ancien Colors.grey (WCAG AA)
          color: isDark
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.5),
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Point pulsant LIVE ───────────────────────────────────────────────────────
class PulsingLiveDot extends StatefulWidget {
  const PulsingLiveDot({super.key});

  @override
  State<PulsingLiveDot> createState() => _PulsingLiveDotState();
}

class _PulsingLiveDotState extends State<PulsingLiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          // [Fix 1] Rouge unifié kLiveRed
          color: kLiveRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
