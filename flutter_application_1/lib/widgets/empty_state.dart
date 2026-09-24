// lib/widgets/empty_state.dart
// État vide générique du DS : icône vectorielle dans pastille or,
// titre + sous-titre optionnel (jamais d'emoji — règle pro-rules).
// Remplace les implémentations locales dupliquées dans les écrans.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 84,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Diamètre de la pastille (icône = ~48 %).
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final textTheme = theme.textTheme;
    final onSurface = theme.colorScheme.onSurface;
    final gold = theme.colorScheme.secondary;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: 0.1),
                border: Border.all(color: gold.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: iconSize * 0.48, color: gold),
            ),
            SizedBox(height: spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: spacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
