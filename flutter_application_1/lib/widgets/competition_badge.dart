// lib/widgets/competition_badge.dart
// Badge vectoriel d'une compétition : remplace les emojis (règle pro-rules :
// pas d'emoji comme icône structurelle). Même langage que le reste de l'app :
// pastille or champagne + Material rounded icon selon la catégorie.
import 'package:flutter/material.dart';
import '../models/competition.dart';

/// Icône vectorielle associée à la catégorie de compétition.
IconData competitionIcon(CompetitionCategory category) {
  switch (category) {
    case CompetitionCategory.worldCup:
      return Icons.emoji_events_rounded;
    case CompetitionCategory.continental:
    case CompetitionCategory.continentalQualification:
    case CompetitionCategory.wcQualification:
      return Icons.public_rounded;
    case CompetitionCategory.youth:
      return Icons.sports_soccer_rounded;
    case CompetitionCategory.olympic:
      return Icons.workspace_premium_rounded;
    case CompetitionCategory.friendly:
      return Icons.handshake_rounded;
  }
}

class CompetitionBadge extends StatelessWidget {
  const CompetitionBadge({
    super.key,
    required this.competition,
    this.size = 36,
    this.iconSize,
  });

  final Competition? competition;
  final double size;
  final double? iconSize;

  static const Color gold = Color(0xFFE7C16A);

  /// Logos officiels par confédération (assets natifs, pas d'images externes
  /// collées : rendus en médaillon circulaire, anneau or, même géométrie que
  /// les badges vectoriels).
  static const Map<Confederation, String> _confederationLogos = {
    Confederation.caf: 'assets/competitions/caf.png',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = competition == null
        ? null
        : _confederationLogos[competition!.confederation];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: logoAsset != null
            ? const Color(0xFF0D1B2A)
            : gold.withValues(alpha: isDark ? 0.12 : 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: logoAsset != null
          ? Image.asset(
              logoAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                competitionIcon(
                    competition?.category ?? CompetitionCategory.continental),
                size: iconSize ?? size * 0.5,
                color: isDark ? gold : const Color(0xFF16324A),
              ),
            )
          : Icon(
              competitionIcon(
                  competition?.category ?? CompetitionCategory.continental),
              size: iconSize ?? size * 0.5,
              color: isDark ? gold : const Color(0xFF16324A),
            ),
    );
  }
}
