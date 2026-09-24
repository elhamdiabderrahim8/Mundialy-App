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
    final reduceMotion =
        MediaQuery.of(context).disableAnimations;

    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs - 1,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(radii.full),
          border: Border.all(color: color.withValues(alpha: 0.5)),
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
                    color: color,
                    fontWeight: FontWeight.w700,
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
