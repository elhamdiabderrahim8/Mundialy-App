import 'package:flutter/material.dart';

const _kGold = Color(0xFFE7C16A);

class PinMatchButton extends StatelessWidget {
  const PinMatchButton({super.key, required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      _kGold.withValues(alpha: 0.18),
                      _kGold.withValues(alpha: 0.08),
                    ]
                  : [
                      const Color(0xFF16324A).withValues(alpha: 0.06),
                      _kGold.withValues(alpha: 0.14),
                    ],
            ),
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            border: Border.all(
              color: _kGold.withValues(alpha: isDark ? 0.45 : 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.push_pin_rounded,
                size: compact ? 13 : 15,
                color: isDark ? _kGold : const Color(0xFF16324A),
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  'Épingler',
                  style: TextStyle(
                    color: isDark ? _kGold : const Color(0xFF16324A),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
