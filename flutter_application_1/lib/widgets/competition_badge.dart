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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gold.withValues(alpha: isDark ? 0.12 : 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: gold.withValues(alpha: 0.35)),
      ),
      child: Icon(
        competitionIcon(
            competition?.category ?? CompetitionCategory.continental),
        size: iconSize ?? size * 0.5,
        color: isDark ? gold : const Color(0xFF16324A),
      ),
    );
  }
}
