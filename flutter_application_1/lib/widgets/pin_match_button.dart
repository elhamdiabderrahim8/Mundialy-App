import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Or champagne = source unique Theme.colorScheme.secondary (lire dans build).
// Plus de hex en dur (Guide §3).

class PinMatchButton extends StatefulWidget {
  const PinMatchButton({super.key, required this.onTap, this.compact = false, this.initiallyPinned = false});

  final VoidCallback onTap;
  final bool compact;
  final bool initiallyPinned;

  @override
  State<PinMatchButton> createState() => _PinMatchButtonState();
}

class _PinMatchButtonState extends State<PinMatchButton> with SingleTickerProviderStateMixin {
  late bool _isPinned;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.initiallyPinned;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    widget.onTap();
    
    setState(() {
      _isPinned = !_isPinned;
    });
    
    // Guide §6 : pas d'animation si "reduce motion" système.
    if (_isPinned && !MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0.0);
      
      final prefs = await SharedPreferences.getInstance();
      final hasSeenTooltip = prefs.getBool('has_seen_pin_tooltip') ?? false;
      if (!hasSeenTooltip) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("متابعة هذه المباراة كـ Live Activity حتى لو كانت الشاشة مغلقة"),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await prefs.setBool('has_seen_pin_tooltip', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gold = theme.colorScheme.secondary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final idleColor = isDark ? Colors.white70 : Colors.black54;

    // Guide §5 : zone tactile ≥ 48×48dp. Le visuel reste compact mais la
    // zone de frappe est élargie via ConstrainedBox (centrée).
    // Guide §6 : animation 200ms désactivée si "reduce motion".
    final pill = Ink(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 12,
        vertical: widget.compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: _isPinned ? gold.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
        border: Border.all(
          color: _isPinned ? gold : gold.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            size: widget.compact ? 13 : 15,
            color: _isPinned ? gold : idleColor,
          ),
          if (!widget.compact) ...[
            const SizedBox(width: 6),
            Text(
              'Épingler',
              style: TextStyle(
                color: _isPinned ? gold : idleColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      label: _isPinned ? 'Match épinglé, toucher pour détacher' : 'Épingler ce match',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: reduceMotion
                  ? pill
                  : ScaleTransition(scale: _scaleAnimation, child: pill),
            ),
          ),
        ),
      ),
    );
  }
}
