import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kGold = Color(0xFFE7C16A);

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
    
    if (_isPinned) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: widget.compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              color: _isPinned ? _kGold.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
              border: Border.all(
                color: _isPinned ? _kGold : _kGold.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: widget.compact ? 13 : 15,
                  color: _isPinned ? _kGold : (isDark ? Colors.white70 : Colors.black54),
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Épingler',
                    style: TextStyle(
                      color: _isPinned ? _kGold : (isDark ? Colors.white70 : Colors.black54),
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
      ),
    );
  }
}
