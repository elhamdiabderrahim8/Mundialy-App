import 'package:flutter/material.dart';

import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/team_player.dart';
import '../models/team_profile.dart';
import '../services/world_cup_repository.dart';
import '../widgets/nation_flag_badge.dart';
import 'match_details_screen.dart';

const Color kTeamGold = Color(0xFFE7C16A);

class TeamDetailsScreen extends StatefulWidget {
  const TeamDetailsScreen({
    super.key,
    required this.teamName,
    required this.teamCode,
    required this.teamId,
    required this.logoUrl,
    required this.matches,
    required this.standing,
    required this.edition,
  });

  final String teamName;
  final String teamCode;
  final int? teamId;
  final String? logoUrl;
  final List<LiveMatch> matches;
  final StandingTeam? standing;
  final WorldCupEdition edition;

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  TeamProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.teamId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final profile = await WorldCupRepository.fetchTeamProfile(
      edition: widget.edition,
      teamId: widget.teamId!,
      teamName: widget.teamName,
    );
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final players = _profile?.players ?? const <TeamPlayer>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0E1A24),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kTeamGold))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 14),
                    _buildHeaderCard(),
                    const SizedBox(height: 14),
                    _buildStandingCard(),
                    const SizedBox(height: 14),
                    _buildMatchesCard(),
                    const SizedBox(height: 14),
                    _buildPlayersCard(players),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
        ),
        Expanded(
          child: Text(
            widget.teamName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF182531),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _DiamondFlag(countryCode: widget.teamCode, size: 82, imageUrlOverride: widget.logoUrl ?? _profile?.logoUrl),
          const SizedBox(height: 14),
          Text(widget.teamName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          if ((_profile?.coach?.name ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Coach: ${_profile!.coach!.name}', style: const TextStyle(color: Colors.white70)),
          ],
          if ((_profile?.venue ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_profile!.venue, style: const TextStyle(color: Colors.white54)),
          ],
        ],
      ),
    );
  }

  Widget _buildStandingCard() {
    final standing = widget.standing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF182531),
        borderRadius: BorderRadius.circular(22),
      ),
      child: standing == null
          ? const Text('Classement indisponible', style: TextStyle(color: Colors.white70))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(label: 'Rang', value: '${standing.rank}'),
                _StatChip(label: 'Points', value: '${standing.points}'),
                _StatChip(label: 'Joues', value: '${standing.played}'),
                _StatChip(label: 'Diff', value: '${standing.goalsDiff}'),
              ],
            ),
    );
  }

  Widget _buildMatchesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF182531),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Matchs de l’equipe', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (widget.matches.isEmpty)
            const Text('Aucun match trouve', style: TextStyle(color: Colors.white70))
          else
            ...widget.matches.map(
              (match) => InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: match))),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${match.homeTeam} vs ${match.awayTeam}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${match.scoreHome ?? '-'} - ${match.scoreAway ?? '-'}',
                        style: const TextStyle(color: kTeamGold, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard(List<TeamPlayer> players) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF182531),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            players.isEmpty ? 'Joueurs indisponibles' : 'Liste des joueurs',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (players.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...players.map(
              (player) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kTeamGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        player.shirtNumber?.toString() ?? '-',
                        style: const TextStyle(color: kTeamGold, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            [player.position, player.nationality, player.ageLabel].where((e) => e.isNotEmpty).join(' • '),
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: kTeamGold, fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _LegacyDiamondFlag extends StatelessWidget {
  const _LegacyDiamondFlag({
    required this.countryCode,
    required this.size,
  }) : imageUrlOverride = null;

  final String countryCode;
  final double size;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final bool isUrl = imageUrlOverride?.startsWith('http') == true || countryCode.startsWith('http');
    final String imageUrl = imageUrlOverride?.isNotEmpty == true
        ? imageUrlOverride!
        : (isUrl ? countryCode : 'https://flagcdn.com/w160/${countryCode.toLowerCase()}.png');

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipPath(
            clipper: _DiamondClipper(),
            child: Container(
              width: size,
              height: size,
              color: const Color(0xFF2A3A48),
              child: OverflowBox(
                maxWidth: size * 1.15,
                maxHeight: size * 1.15,
                child: Image.network(
                  imageUrl,
                  width: size * 1.15,
                  height: size * 1.15,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF2A3A48),
                    alignment: Alignment.center,
                    child: Text(countryCode, style: TextStyle(color: Colors.white, fontSize: size * 0.2)),
                  ),
                ),
              ),
            ),
          ),
          CustomPaint(size: Size(size, size), painter: _DiamondBorderPainter()),
        ],
      ),
    );
  }
}

class _DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiamondBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiamondFlag extends StatelessWidget {
  const _DiamondFlag({
    required this.countryCode,
    required this.size,
    this.imageUrlOverride,
  });

  final String countryCode;
  final double size;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    return NationFlagBadge(
      countryCode: countryCode,
      size: size,
      imageUrlOverride: imageUrlOverride,
    );
  }
}
