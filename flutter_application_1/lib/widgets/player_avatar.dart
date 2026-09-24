// lib/widgets/player_avatar.dart
// Avatar joueur du DS (guide §4 : TeamCrest) : photo réseau + cache,
// repli sur initiale (jamais de case vide), anneau or.
// Remplace les implémentations locales dupliquées (buteurs, profils...).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String get _initial =>
      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;
    final onSurface = theme.colorScheme.onSurface;

    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gold.withValues(alpha: 0.12),
          border: Border.all(color: gold.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.hardEdge,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: Text(
                    _initial,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.4,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Text(
                    _initial,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.4,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
      ),
    );
  }
}
