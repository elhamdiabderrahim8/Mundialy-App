// lib/widgets/competition_badge.dart
// Badge vectoriel d'une compétition : remplace les emojis (règle pro-rules :
// pas d'emoji comme icône structurelle). Même langage que le reste de l'app :
// pastille or champagne + Material rounded icon selon la catégorie.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    Confederation.caf: 'assets/competitions/caf_flat.png',
  };

  /// Logos par compétition (prioritaires sur la confédération) : une
  /// compétition a sa marque propre, distincte de sa confédération
  /// (ex: Nations League ≠ UEFA, CAN ≠ CAF).
  /// Assets retraités natifs (médaillon circulaire bleu nuit, 512px).
  static const Map<int, String> _competitionLogos = {
    5930: 'assets/competitions/worldcup.png', // FIFA World Cup
    5582: 'assets/competitions/wcu17.png', // U17 World Cup
    167: 'assets/competitions/afcon2025.svg', // CAN 2025 (logo officiel, trophée seul)
    588: 'assets/competitions/afcon2025.svg', // Qualifs CAN (marque CAN)
    605: 'assets/competitions/afc_road26.svg', // Qualifs CDM AFC
    6071: 'assets/competitions/euro_qualifiers.png', // European Qualifiers
    591: 'assets/competitions/euro_u21.png', // Euro U21
    328: 'assets/competitions/euro_u17.svg', // Euro U17
    467: 'assets/competitions/euro_u19.svg', // Euro U19
    595: 'assets/competitions/copaamerica.svg', // Copa América
    589: 'assets/competitions/goldcup.svg', // CONCACAF Gold Cup
    5471: 'assets/competitions/copacentro.svg', // Copa Centroamericana
    6196: 'assets/competitions/asiancup.svg', // Asian Cup
    5472: 'assets/competitions/asian_qualifiers.png', // Asian Cup Qual.
    6332: 'assets/competitions/afc_u23.png', // AFC U23 Asian Cup
    7960: 'assets/competitions/afc_u17.png', // AFC U17 Asian Cup
    7674: 'assets/competitions/arabcup.png', // FIFA Arab Cup
    5452: 'assets/competitions/gulfcup.svg', // Arabian Gulf Cup
    8814: 'assets/competitions/agcff_u20.png', // Gulf Cup U20
    8950: 'assets/competitions/gulf_u23.svg', // Gulf Cup U23
    7957: 'assets/competitions/waff.svg', // WAFF U23
    6370: 'assets/competitions/olympics.svg', // Olympics Football Men
    6316: 'assets/competitions/euro.png', // UEFA Euro
    7016: 'assets/competitions/unl.svg', // UEFA Nations League
    7165: 'assets/competitions/cnl.svg', // CONCACAF Nations League
    611: 'assets/competitions/concacaf_qualifiers.svg', // CONCACAF WC Qual.
    613: 'assets/competitions/conmebol.svg', // CONMEBOL WC Qual.
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? logoAsset;
    if (competition != null) {
      logoAsset = _competitionLogos[competition!.id] ??
          _confederationLogos[competition!.confederation];
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gold.withValues(alpha: isDark ? 0.12 : 0.18),
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
          ? _LogoImage(
              asset: logoAsset,
              size: size,
              iconSize: iconSize,
              isDark: isDark,
              category:
                  competition?.category ?? CompetitionCategory.continental,
            )
          : Icon(
              competitionIcon(
                  competition?.category ?? CompetitionCategory.continental),
              size: iconSize ?? size * 0.5,
              color: gold,
            ),
    );
  }
}

/// Image de logo : SVG officiel (couleurs d'origine, ex: trophée CAN) ou
/// PNG médaillon, avec repli icône vectorielle si l'asset est absent.
class _LogoImage extends StatelessWidget {
  const _LogoImage({
    required this.asset,
    required this.size,
    required this.iconSize,
    required this.isDark,
    required this.category,
  });

  final String asset;
  final double size;
  final double? iconSize;
  final bool isDark;
  final CompetitionCategory category;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      competitionIcon(category),
      size: iconSize ?? size * 0.5,
      color: CompetitionBadge.gold,
    );
    if (asset.endsWith('.svg')) {
      // SVG monochromes (currentColor) teintés or champagne, exactement
      // comme les icônes de continents : pièce native de l'app.
      return SvgPicture.asset(
        asset,
        width: size * 0.72,
        height: size * 0.72,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          CompetitionBadge.gold,
          BlendMode.srcIn,
        ),
        placeholderBuilder: (_) => fallback,
      );
    }
    return Image.asset(
      asset,
      width: size * 0.72,
      height: size * 0.72,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
