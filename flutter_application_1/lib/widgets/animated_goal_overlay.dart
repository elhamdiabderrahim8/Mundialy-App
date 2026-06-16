import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'nation_flag_badge.dart';

void showGoalOverlay(BuildContext context, Map<String, dynamic> payload) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (context) => AnimatedGoalOverlay(
      payload: payload,
      onDismiss: () {
        if (entry != null && entry!.mounted) {
          entry!.remove();
        }
      },
    ),
  );
  Overlay.of(context).insert(entry);
}

class AnimatedGoalOverlay extends StatefulWidget {
  final Map<String, dynamic> payload;
  final VoidCallback onDismiss;

  const AnimatedGoalOverlay({
    super.key,
    required this.payload,
    required this.onDismiss,
  });

  @override
  State<AnimatedGoalOverlay> createState() => _AnimatedGoalOverlayState();
}

class _AnimatedGoalOverlayState extends State<AnimatedGoalOverlay>
    with TickerProviderStateMixin {
  ui.Image? _flagImage;
  bool _isLoadingImage = true;

  // Animations
  late AnimationController _goalTextController;
  late AnimationController _transitionController;
  late AnimationController _scorePulseController;

  // Staggered letters
  late List<Animation<double>> _letterScales;
  late List<Animation<double>> _letterFades;

  @override
  void initState() {
    super.initState();
    _loadFlagImage();
    _setupAnimations();
  }

  void _setupAnimations() {
    _goalTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scorePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Staggered "GOAL!" (5 items: G, O, A, L, !)
    _letterScales = [];
    _letterFades = [];
    for (int i = 0; i < 5; i++) {
      final start = i * 0.12;
      final end = start + 0.3;
      _letterScales.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _goalTextController,
            curve: Interval(start, end, curve: Curves.elasticOut),
          ),
        ),
      );
      _letterFades.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _goalTextController,
            curve: Interval(start, end, curve: Curves.easeIn),
          ),
        ),
      );
    }

    _scorePulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scorePulseController.reverse();
      }
    });
  }

  Future<void> _loadFlagImage() async {
    final teamCode = widget.payload['scoringTeamCode'] ?? '';
    final flagUrl = NationFlagBadge.resolveFlagUrl(teamCode);

    if (flagUrl != null) {
      try {
        final ImageStream stream = NetworkImage(
          flagUrl,
        ).resolve(ImageConfiguration.empty);
        final Completer<ui.Image> completer = Completer<ui.Image>();
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
            if (!completer.isCompleted) completer.complete(info.image);
            stream.removeListener(listener);
          },
          onError: (e, s) {
            if (!completer.isCompleted) completer.completeError(e);
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        _flagImage = await completer.future;
      } catch (e) {
        debugPrint('Error loading flag image for shader: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingImage = false;
      });
      _startAnimationSequence();
    }
  }

  Future<void> _startAnimationSequence() async {
    // 1. Show GOAL
    await _goalTextController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));

    // 2. Transition to Score
    await _transitionController.forward();

    // 3. Pulse Score
    _scorePulseController.forward();

    // 4. Wait and Dismiss
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _goalTextController.dispose();
    _transitionController.dispose();
    _scorePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingImage) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black45,
      child: Stack(
        children: [
          // Dismiss on tap
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _transitionController,
                builder: (context, child) {
                  return Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    constraints: const BoxConstraints(minHeight: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1116), // Dark background like image
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // GOAL! Layer
                        Opacity(
                          opacity: (1.0 - _transitionController.value * 2).clamp(0.0, 1.0),
                          child: Visibility(
                            visible: _transitionController.value < 0.6,
                            child: _buildGoalText(),
                          ),
                        ),
                        // SCORE Layer
                        Opacity(
                          opacity: ((_transitionController.value - 0.4) * 2).clamp(0.0, 1.0),
                          child: Visibility(
                            visible: _transitionController.value > 0.4,
                            child: _buildScoreBanner(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalText() {
    final letters = ['G', 'O', 'A', 'L', '!'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (index) {
        return AnimatedBuilder(
          animation: _goalTextController,
          builder: (context, child) {
            final isExclamation = letters[index] == '!';
            
            // For the exclamation mark, we might want a different style or just the dot in yellow
            // But let's follow the image: the yellow dot
            
            return FadeTransition(
              opacity: _letterFades[index],
              child: ScaleTransition(
                scale: _letterScales[index],
                child: _buildAnimatedLetter(letters[index], isExclamation),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildAnimatedLetter(String letter, bool isExclamation) {
    if (isExclamation) {
      return Text(
        letter,
        style: const TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFD700), // Golden yellow for the !
          height: 1,
        ),
      );
    }

    if (_flagImage == null) {
      return Text(
        letter,
        style: const TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
        ),
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final matrix = Matrix4.identity();
        // Scale and shift flag to be visible in each letter
        final scaleX = bounds.width / _flagImage!.width;
        final scaleY = bounds.height / _flagImage!.height;
        matrix.scale(scaleX * 1.5, scaleY * 1.5); 
        
        return ImageShader(
          _flagImage!,
          TileMode.mirror,
          TileMode.mirror,
          matrix.storage,
        );
      },
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildScoreBanner() {
    final homeTeam = (widget.payload['homeTeamName'] ?? '').toString().toUpperCase();
    final awayTeam = (widget.payload['awayTeamName'] ?? '').toString().toUpperCase();
    final homeCode = widget.payload['homeCode'] ?? '';
    final awayCode = widget.payload['awayCode'] ?? '';
    final homeScore = widget.payload['homeScore'] ?? '0';
    final awayScore = widget.payload['awayScore'] ?? '0';
    final scorer = widget.payload['scorerName'] ?? widget.payload['scorer'] ?? '';
    final minute = widget.payload['minute'] ?? '';
    final isPenalty = widget.payload['isPenalty'] == true || widget.payload['isPenalty'] == 'true';
    final scoringTeam = widget.payload['scoringTeam'] ?? '';

    final homeScored = scoringTeam == 'home';
    final awayScored = scoringTeam == 'away';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Home Team
            Expanded(
              child: Column(
                children: [
                  NationFlagBadge(countryCode: homeCode, size: 50),
                  const SizedBox(height: 8),
                  Text(
                    homeTeam,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Score Center
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildScoreNumber(homeScore, homeScored),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                    _buildScoreNumber(awayScore, awayScored),
                  ],
                ),
                
                // Scorer Info
                if (scorer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports_soccer, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        scorer,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (minute.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$minute'",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isPenalty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          "PENALTY",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Away Team
            Expanded(
              child: Column(
                children: [
                  NationFlagBadge(countryCode: awayCode, size: 50),
                  const SizedBox(height: 8),
                  Text(
                    awayTeam,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreNumber(String score, bool didScore) {
    final style = TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      color: didScore ? const Color(0xFFFF4B4B) : Colors.white70,
    );

    if (!didScore) return Text(score, style: style);

    return AnimatedBuilder(
      animation: _scorePulseController,
      builder: (context, child) {
        final scale = 1.0 + (_scorePulseController.value * 0.2);
        return Transform.scale(
          scale: scale,
          child: Text(score, style: style),
        );
      },
    );
  }
}
