import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const Color _skeletonGold = Color(0xFFE7C16A);
const Color _skeletonDarkBg = Color(0xFF0E1A24);
const Color _skeletonDarkCard = Color(0xFF182531);

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
    this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.white12 : Colors.black12),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? _skeletonDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _skeletonGold.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer({super.key, required this.child, this.isDark});

  final Widget child;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final resolvedDark =
        isDark ?? Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: resolvedDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
      highlightColor: resolvedDark
          ? Colors.white.withValues(alpha: 0.20)
          : Colors.white.withValues(alpha: 0.95),
      child: child,
    );
  }
}

class MatchListSkeleton extends StatelessWidget {
  const MatchListSkeleton({
    super.key,
    required this.isDark,
    this.itemCount = 6,
  });

  final bool isDark;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDark: isDark,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: itemCount,
        itemBuilder: (context, index) => const SkeletonCard(
          margin: EdgeInsets.only(bottom: 16),
          child: SizedBox(height: 88),
        ),
      ),
    );
  }
}

class MatchDetailsSkeleton extends StatelessWidget {
  const MatchDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _skeletonDarkBg : Colors.white;
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SkeletonShimmer(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const SkeletonBlock(width: 40, height: 40, radius: 20),
                    const Spacer(),
                    SkeletonBlock(
                      width: MediaQuery.sizeOf(context).width * 0.34,
                      height: 18,
                    ),
                    const Spacer(),
                    const SkeletonBlock(width: 40, height: 40, radius: 20),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SkeletonCard(
                        child: Column(
                          children: [
                            const SkeletonBlock(width: 120, height: 14),
                            const SizedBox(height: 18),
                            Row(
                              children: const [
                                Expanded(child: _TeamScoreSkeleton()),
                                SkeletonBlock(
                                  width: 74,
                                  height: 44,
                                  radius: 12,
                                ),
                                Expanded(child: _TeamScoreSkeleton()),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const SkeletonBlock(width: 180, height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: const [
                          Expanded(
                            child: SkeletonBlock(height: 44, radius: 14),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: SkeletonBlock(height: 44, radius: 14),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: SkeletonBlock(height: 44, radius: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _LinesCardSkeleton(lines: 5),
                      const SizedBox(height: 14),
                      const _LinesCardSkeleton(lines: 7),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamProfileSkeleton extends StatelessWidget {
  const TeamProfileSkeleton({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? _skeletonDarkBg : const Color(0xFFF7F2E8);
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SkeletonShimmer(
          isDark: isDark,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: const [
              _HeaderSkeleton(),
              SizedBox(height: 16),
              _LinesCardSkeleton(lines: 4),
              SizedBox(height: 16),
              _LinesCardSkeleton(lines: 3),
              SizedBox(height: 16),
              _ListRowsSkeleton(rows: 4),
              SizedBox(height: 16),
              _ListRowsSkeleton(rows: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamDetailsSkeleton extends StatelessWidget {
  const TeamDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDark: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _TopBarSkeleton(),
            SizedBox(height: 14),
            _HeaderSkeleton(),
            SizedBox(height: 14),
            _LinesCardSkeleton(lines: 4),
            SizedBox(height: 14),
            _ListRowsSkeleton(rows: 3),
            SizedBox(height: 14),
            _ListRowsSkeleton(rows: 7),
          ],
        ),
      ),
    );
  }
}

class PlayerStatsSkeleton extends StatelessWidget {
  const PlayerStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SkeletonShimmer(
        isDark: isDark,
        child: Column(
          children: const [
            _LinesCardSkeleton(lines: 5),
            SizedBox(height: 14),
            _LinesCardSkeleton(lines: 4),
            SizedBox(height: 14),
            _ListRowsSkeleton(rows: 4),
          ],
        ),
      ),
    );
  }
}

class IptvInitSkeleton extends StatelessWidget {
  const IptvInitSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _skeletonDarkBg : const Color(0xFFF7F2E8),
      body: SafeArea(
        child: SkeletonShimmer(
          isDark: isDark,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: const [
              _HeaderSkeleton(),
              SizedBox(height: 20),
              SkeletonBlock(height: 48, radius: 14),
              SizedBox(height: 18),
              _GridSkeleton(),
            ],
          ),
        ),
      ),
    );
  }
}

class IptvCategoryGridSkeleton extends StatelessWidget {
  const IptvCategoryGridSkeleton({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDark: isDark,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: _GridSkeleton(),
      ),
    );
  }
}

class IptvChannelListSkeleton extends StatelessWidget {
  const IptvChannelListSkeleton({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDark: isDark,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: 8,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => SkeletonCard(
          radius: 16,
          child: Row(
            children: const [
              SkeletonBlock(width: 44, height: 44, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(height: 14),
                    SizedBox(height: 8),
                    SkeletonBlock(width: 120, height: 10),
                  ],
                ),
              ),
              SkeletonBlock(width: 28, height: 28, radius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPlayerSkeleton extends StatelessWidget {
  const VideoPlayerSkeleton({super.key, required this.channelName});

  final String channelName;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      isDark: true,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          margin: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _skeletonGold.withValues(alpha: 0.16)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBlock(width: 76, height: 76, radius: 38),
                const SizedBox(height: 18),
                const SkeletonBlock(width: 180, height: 14),
                const SizedBox(height: 10),
                SkeletonBlock(
                  width: (channelName.length * 7.0).clamp(90.0, 220.0),
                  height: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarSkeleton extends StatelessWidget {
  const _TopBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SkeletonBlock(width: 40, height: 40, radius: 20),
        Spacer(),
        SkeletonBlock(width: 150, height: 18),
        Spacer(),
        SizedBox(width: 40),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        children: const [
          SkeletonBlock(width: 78, height: 78, radius: 39),
          SizedBox(height: 14),
          SkeletonBlock(width: 180, height: 18),
          SizedBox(height: 10),
          SkeletonBlock(width: 120, height: 12),
        ],
      ),
    );
  }
}

class _TeamScoreSkeleton extends StatelessWidget {
  const _TeamScoreSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonBlock(width: 54, height: 54, radius: 27),
        SizedBox(height: 10),
        SkeletonBlock(width: 76, height: 12),
      ],
    );
  }
}

class _LinesCardSkeleton extends StatelessWidget {
  const _LinesCardSkeleton({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        children: List.generate(lines, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 12),
            child: Row(
              children: [
                const SkeletonBlock(width: 34, height: 34, radius: 17),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonBlock(
                    height: 12,
                    width: index.isEven ? double.infinity : 150,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ListRowsSkeleton extends StatelessWidget {
  const _ListRowsSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        children: List.generate(rows, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 14),
            child: Row(
              children: [
                const SkeletonBlock(width: 40, height: 40, radius: 20),
                const SizedBox(width: 12),
                const Expanded(child: SkeletonBlock(height: 13)),
                const SizedBox(width: 16),
                SkeletonBlock(width: 36 + (index % 3) * 12, height: 12),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => const SkeletonCard(
        radius: 16,
        child: Row(
          children: [
            SkeletonBlock(width: 36, height: 36, radius: 10),
            SizedBox(width: 12),
            Expanded(child: SkeletonBlock(height: 13)),
          ],
        ),
      ),
    );
  }
}
