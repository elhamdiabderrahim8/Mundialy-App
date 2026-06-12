import 'package:flutter/material.dart';

class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PremiumPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Un fondu (Fade) combiné avec un léger effet de zoom (Scale)
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}
