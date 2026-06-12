import 'dart:ui';
import 'package:flutter/material.dart';
import 'nation_flag_badge.dart';
import '../utils/country_flags.dart';

class InAppNotification {
  static void show(
    BuildContext context,
    String homeTeam,
    String awayTeam,
    String? matchMinute,
    String title,
    String message, {
    bool isGoal = true,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _AnimatedBanner(
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          matchMinute: matchMinute,
          title: title,
          message: message,
          isGoal: isGoal,
          onDismiss: () => entry.remove(),
        );
      },
    );

    overlay.insert(entry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}

class _AnimatedBanner extends StatefulWidget {
  final String homeTeam;
  final String awayTeam;
  final String? matchMinute;
  final String title;
  final String message;
  final bool isGoal;
  final VoidCallback onDismiss;

  const _AnimatedBanner({
    required this.homeTeam,
    required this.awayTeam,
    this.matchMinute,
    required this.title,
    required this.message,
    required this.isGoal,
    required this.onDismiss,
  });

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    // Premium Gold color for Goals, vibrant Blue for other notifications
    final accentColor = widget.isGoal
        ? const Color(0xFFE7C16A) // Gold
        : const Color(0xFF3498DB); // Blue

    final pulseColor = widget.isGoal
        ? const Color(0xFFD4AF37)
        : const Color(0xFF2980B9);

    final homeCode = resolveCountryCode(widget.homeTeam);
    final awayCode = resolveCountryCode(widget.awayTeam);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: _dismiss,
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < 0) {
                      _dismiss();
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0A121A,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.25),
                              blurRadius: 25,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Home Team Logo (using NationFlagBadge)
                            NationFlagBadge(countryCode: homeCode, size: 42),
                            const SizedBox(width: 16),

                            // Match Info
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Optional glowing icon effect
                                      Icon(
                                        widget.isGoal
                                            ? Icons.sports_soccer_rounded
                                            : Icons
                                                  .notifications_active_rounded,
                                        color: accentColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.title.toUpperCase(),
                                        style: TextStyle(
                                          color: accentColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 2.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (widget.matchMinute != null &&
                                      widget.matchMinute!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: accentColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '${widget.matchMinute}\'',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),
                            // Away Team Logo (using NationFlagBadge)
                            NationFlagBadge(countryCode: awayCode, size: 42),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
