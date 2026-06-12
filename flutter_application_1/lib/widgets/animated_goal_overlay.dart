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
        entry?.remove();
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

    // Staggered "GOAL"
    _letterScales = [];
    _letterFades = [];
    for (int i = 0; i < 4; i++) {
      final start = i * 0.15;
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
    await Future.delayed(const Duration(milliseconds: 800));

    // 2. Transition to Score
    await _transitionController.forward();

    // 3. Pulse Score
    _scorePulseController.forward();

    // 4. Wait and Dismiss
    await Future.delayed(const Duration(seconds: 4));
    widget.onDismiss();
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
      return const SizedBox.shrink(); // Wait silently
    }

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _transitionController,
              builder: (context, child) {
                final isGoalPhase = _transitionController.value < 0.5;
                if (isGoalPhase) {
                  return Opacity(
                    opacity: 1.0 - (_transitionController.value * 2),
                    child: _buildGoalText(),
                  );
                } else {
                  return Opacity(
                    opacity: (_transitionController.value - 0.5) * 2,
                    child: _buildScoreBanner(),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalText() {
    final letters = ['G', 'O', 'A', 'L'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(letters.length, (index) {
        return AnimatedBuilder(
          animation: _goalTextController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _letterFades[index],
              child: ScaleTransition(
                scale: _letterScales[index],
                child: _flagImage != null
                    ? ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          final matrix = Matrix4.diagonal3Values(
                            bounds.width / _flagImage!.width,
                            bounds.height / _flagImage!.height,
                            1.0,
                          );
                          return ImageShader(
                            _flagImage!,
                            TileMode.clamp,
                            TileMode.clamp,
                            matrix.storage,
                          );
                        },
                        child: Text(
                          letters[index],
                          style: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      )
                    : Text(
                        letters[index],
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildScoreBanner() {
    final homeTeam = widget.payload['homeTeamName'] ?? 'Home';
    final awayTeam = widget.payload['awayTeamName'] ?? 'Away';
    final homeScore = widget.payload['homeScore'] ?? '0';
    final awayScore = widget.payload['awayScore'] ?? '0';
    final scorer = widget.payload['scorerName'] ?? '';
    final minute = widget.payload['minute'] ?? '';
    final isPenalty = widget.payload['isPenalty'] == 'true';
    final scoringTeam = widget.payload['scoringTeam'] ?? '';

    final homeScored = scoringTeam == 'home';
    final awayScored = scoringTeam == 'away';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              homeTeam,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            _buildScoreNumber(homeScore, homeScored),
            const Text(
              ' - ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            _buildScoreNumber(awayScore, awayScored),
            const SizedBox(width: 16),
            Text(
              awayTeam,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        if (scorer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  color: AppColors.secondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  "$scorer ${minute.isNotEmpty ? "$minute'" : ""}${isPenalty ? " (P)" : ""}",
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScoreNumber(String score, bool didScore) {
    if (!didScore) {
      return Text(
        score,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _scorePulseController,
      builder: (context, child) {
        final scale = 1.0 + (_scorePulseController.value * 0.3);
        return Transform.scale(
          scale: scale,
          child: Text(
            score,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
        );
      },
    );
  }
}
