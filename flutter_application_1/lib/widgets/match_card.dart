// lib/widgets/match_card.dart
// Carte match UNIQUE de l'app : strictement la même sur l'accueil et les
// pages compétitions (extrait de home_screen _MatchCard, 1:1).
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

/// Or champagne + fond carte sombre (identité Mundialy).
const Color kMatchCardGold = Color(0xFFE7C16A);
const Color kMatchCardDark = Color(0xFF1D2D3B);

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

    // ── LIVE MATCH: exact style from reference ──
    if (match.isLive) {
      return FadeSlideEntrance(
        child: _buildLiveCard(context, isDark),
      );
    }

    // ── NON-LIVE MATCH ──
    return FadeSlideEntrance(
      child: _buildStandardCard(context, isDark),
    );
  }

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
    final Color scoreColor = isDark ? Colors.redAccent : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: isDark ? 0.12 : 0.08),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section: Pulse + minute + épingler ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingLiveDot(),
                        const SizedBox(width: 6),
                        Text(
                          match.statusDisplay,
                          style: const TextStyle(
                            color: Colors.redAccent,
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
                // ── Teams + Score Row (même densité que la carte terminée) ──
                Row(
                  children: [
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
                                  fontWeight: FontWeight.w800,
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
                            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) => Material(
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
                              style: TextStyle(
                                color: scoreColor,
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
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'logo_away_${match.id}',
                            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) => Material(
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
                                  fontWeight: FontWeight.w800,
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

  Widget _buildStandardCard(BuildContext context, bool isDark) {
    final String centerText = match.scoreHome != null
        ? '${match.scoreHome} - ${match.scoreAway}'
        : 'VS';
    final String? penaltyText =
        (match.penaltyHome != null && match.penaltyAway != null)
        ? '(${match.penaltyHome} - ${match.penaltyAway} TAB)'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? kMatchCardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
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
            opacity: match.isFinished ? 0.65 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Top row: status + phase
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (match.isFinished) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'TERMINÉ',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                match.localTime,
                                style: const TextStyle(
                                  color: kMatchCardGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Text(
                          LangUtils.getTranslatedPhase(match.phaseLabel, context),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Teams + Score row
                  Row(
                    children: [
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
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Hero(
                              tag: 'logo_home_${match.id}',
                              flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) => Material(
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
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'logo_away_${match.id}',
                              flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) => Material(
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
                                      fontWeight: FontWeight.w800,
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
      overlayTitle: "Live Score",
      overlayContent: "Match en cours",
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
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
