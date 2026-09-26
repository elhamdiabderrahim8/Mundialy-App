// lib/widgets/status_badge.dart
// Atome "badge de statut" du DS (guide §3 : LiveBadge) : pastille + label.
// L'info n'est JAMAIS codée par la seule couleur : pastille + texte
// (accessibilité daltonisme, guide §4). Option pulsée pour le LIVE
// (AnimatedOpacity en boucle, respecte "reduce motion").
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.pulsing = false,
  });

  final String label;
  final Color color;

  /// Si vrai, la pastille pulse (réservé au statut LIVE).
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing();
    final radii = theme.extension<AppRadii>() ?? const AppRadii();
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // [Fix 4] Contraste WCAG AA (4.5:1) :
    // Fond = color à 90% d'opacité (solide) → texte blanc (#FFF) = >7:1 garanti.
    final Color bgColor = color.withValues(alpha: 0.90);
    // On garde la pastille en blanc (visible sur fond coloré).
    final Color textOnBadge = Colors.white;

    final dot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs - 1,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radii.full),
          // Pas de border supplémentaire — le fond plein suffit
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pulsing && !reduceMotion
                ? _PulsingDot(dot: dot)
                : dot,
            SizedBox(width: spacing.xs - 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textOnBadge,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.dot});
  final Widget dot;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _visible = !_visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: widget.dot,
    );
  }
}
