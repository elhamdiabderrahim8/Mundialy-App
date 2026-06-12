import 'package:flutter/material.dart';

class FadeSlideEntrance extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        // value goes from 0 to 1
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}
