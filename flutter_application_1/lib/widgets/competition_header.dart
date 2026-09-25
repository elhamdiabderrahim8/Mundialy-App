import 'package:flutter/material.dart';
import '../data/competitions_catalog.dart';
import '../theme/app_theme.dart';
import '../constants/app_colors.dart';
import 'competition_badge.dart';

class CompetitionHeader extends StatelessWidget {
  const CompetitionHeader({
    super.key,
    required this.name,
    required this.competitionId,
    required this.matchCount,
    this.onTap,
  });

  final String name;
  final int? competitionId;
  final int matchCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final isDark = theme.brightness == Brightness.dark;
    
    final comp = competitionId != null
        ? CompetitionsCatalog.findById(competitionId!)
        : null;

    return Semantics(
      button: onTap != null,
      label: 'Compétition $name, $matchCount matchs. ${onTap != null ? 'Voir les détails' : ''}',
      child: Container(
        margin: EdgeInsets.only(top: spacing.md, bottom: spacing.sm),
        child: Material(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.05) 
              : Colors.white,
          borderRadius: BorderRadius.circular(radii.md),
          elevation: isDark ? 0 : 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.transparent,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(radii.md),
              ),
              child: Row(
                children: [
                  CompetitionBadge(competition: comp, size: 28, iconSize: 16),
                  SizedBox(width: spacing.md),
                  
                  // Name
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Match Count Badge
                  Container(
                    margin: EdgeInsets.only(right: spacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(radii.full),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '$matchCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  
                  // Chevron indicator for interactivity
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.4),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
