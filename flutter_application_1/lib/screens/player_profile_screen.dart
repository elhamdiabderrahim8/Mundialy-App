import 'package:flutter/material.dart';
import '../models/team_player.dart';
import '../services/api_service.dart';
import '../widgets/nation_flag_badge.dart';
import '../utils/country_flags.dart';

class PlayerProfileScreen extends StatefulWidget {
  final dynamic entity; // Peut être TeamPlayer ou TeamCoach
  final int season;

  const PlayerProfileScreen({
    super.key,
    required this.entity,
    this.season = 2022,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  dynamic _statsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final id = widget.entity.id;
    if (id != 0) {
      final data = await ApiService.fetchPlayerStats(
        playerId: id,
        season: widget.season,
      );
      if (mounted) {
        setState(() {
          _statsData = data;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1A24) : const Color(0xFFF7F2E8);
    final cardColor = isDark ? const Color(0xFF182531) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);
    const gold = Color(0xFFE7C16A);

    final statsList = _statsData?['response'] as List? ?? [];
    final Map<String, dynamic> fullPlayer = statsList.isNotEmpty
        ? statsList[0]
        : {};
    final playerInfo = fullPlayer['player'] ?? {};
    final statistics = (fullPlayer['statistics'] as List? ?? []).isNotEmpty
        ? fullPlayer['statistics'][0]
        : {};

    final String name = playerInfo['name'] ?? widget.entity.name;
    final String? photo = playerInfo['photo'] ?? widget.entity.photoUrl;
    final String nationality =
        playerInfo['nationality'] ?? widget.entity.nationality;
    final String nationalityCode = playerInfo['id'] != null
        ? resolveCountryCode(nationality)
        : widget.entity.nationalityCode;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profil Joueur',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: gold, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: gold.withValues(alpha: 0.1),
                          backgroundImage: photo != null
                              ? NetworkImage(photo)
                              : null,
                          child: (photo == null || photo.isEmpty)
                              ? const Icon(Icons.person, size: 60, color: gold)
                              : null,
                        ),
                      ),
                      NationFlagBadge(countryCode: nationalityCode, size: 40),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    statistics['games']?['position'] ??
                        (widget.entity is TeamPlayer
                            ? (widget.entity as TeamPlayer).position
                            : 'Sélectionneur'),
                    style: const TextStyle(
                      color: gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nationality.toUpperCase(),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: gold))
            else if (statistics.isNotEmpty)
              _buildStatsGrid(statistics, isDark, textColor)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Statistiques non disponibles pour ce tournoi.',
                  style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    Map<String, dynamic> stats,
    bool isDark,
    Color textColor,
  ) {
    final games = stats['games'] ?? {};
    final goals = stats['goals'] ?? {};
    final cards = stats['cards'] ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
          'Matchs',
          '${games['appearences'] ?? 0}',
          Icons.sports_soccer,
          Colors.blue,
        ),
        _buildStatCard(
          'Minutes',
          '${games['minutes'] ?? 0}\'',
          Icons.timer,
          Colors.orange,
        ),
        _buildStatCard(
          'Buts',
          '${goals['total'] ?? 0}',
          Icons.emoji_events,
          Colors.green,
        ),
        _buildStatCard(
          'Assists',
          '${goals['assists'] ?? 0}',
          Icons.assistant,
          Colors.teal,
        ),
        _buildStatCard(
          'Note',
          '${games['rating'] ?? '-'}',
          Icons.star,
          Colors.amber,
        ),
        _buildStatCard(
          'Cartons',
          '${cards['yellow'] ?? 0}J / ${cards['red'] ?? 0}R',
          Icons.square,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2D3B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
