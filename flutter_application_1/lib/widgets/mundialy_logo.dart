import 'package:flutter/material.dart';

class MundialyLogo extends StatelessWidget {
  const MundialyLogo({super.key, this.size = 28, this.showLabel = false});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            'assets/logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.live_tv_rounded,
              size: size,
              color: isDark ? const Color(0xFFE7C16A) : const Color(0xFF16324A),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            'Mundialy',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF16324A),
              fontWeight: FontWeight.w800,
              fontSize: size * 0.55,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
