import 'package:flutter/material.dart';
import '../models/team_player.dart';
import '../services/api_service.dart';
import '../widgets/nation_flag_badge.dart';
import '../widgets/loading_skeletons.dart';
import '../utils/country_flags.dart';
import '../models/top_scorer.dart';

const _kGold = Color(0xFFE7C16A);

class PlayerProfileScreen extends StatefulWidget {
  final dynamic entity; // TeamPlayer ou TeamCoach
  final int season;

  const PlayerProfileScreen({
    super.key,
    required this.entity,
    this.season = 2026,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? _statsData;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final id = _asInt(widget.entity.id);
    if (id > 0) {
      try {
        final data = await ApiService.fetchPlayerStats(
          playerId: id,
          season: widget.season,
        );
        if (mounted) {
          setState(() {
            _statsData = data;
            _statsLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _statsData = null;
            _statsLoading = false;
          });
        }
      }
    } else {
      setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1A24) : const Color(0xFFF7F2E8);
    final cardColor = isDark ? const Color(0xFF182531) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);

    // Extract data from new unified format
    final characteristics = _asMap(_statsData?['characteristics']);
    final attributes = _asMap(_statsData?['attributes']);

    final String name = widget.entity.name;
    final String nationality =
        (attributes['nationality']?.toString().isNotEmpty == true)
        ? attributes['nationality'].toString()
        : (widget.entity.nationality ?? '');
    final String nationalityCode = resolveCountryCode(nationality);

    // Characteristics
    final charData = _asMap(
      characteristics['playerCharacteristics'],
      fallback: characteristics,
    );
    final String preferredFoot = charData['preferredFoot']?.toString() ?? '';
    final int height = _asInt(charData['height']);
    final int weight = _asInt(charData['weight']);
    final String position =
        (charData['position']?.toString().isNotEmpty == true)
        ? charData['position'].toString()
        : (widget.entity is TeamPlayer
              ? (widget.entity as TeamPlayer).position
              : '');
    final int shirtNumber = _asInt(charData['shirtNumber']) > 0
        ? _asInt(charData['shirtNumber'])
        : (widget.entity is TeamPlayer
              ? _asInt((widget.entity as TeamPlayer).shirtNumber)
              : 0);

    // Attributes — style FIFA
    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // --- HERO APP BAR ---
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0E1A24) : Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF1D2D3B), const Color(0xFF0E1A24)]
                            : [
                                const Color(0xFFEAF0F6),
                                const Color(0xFFF7F2E8),
                              ],
                      ),
                    ),
                  ),
                  // Number watermark
                  if (shirtNumber > 0)
                    Positioned(
                      right: -10,
                      top: 10,
                      child: Text(
                        '$shirtNumber',
                        style: TextStyle(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          color: _kGold.withValues(alpha: 0.07),
                          height: 1,
                        ),
                      ),
                    ),
                  // Player photo + info
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 50),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [_kGold, Color(0xFFC8973A)],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: isDark
                                    ? const Color(0xFF1D2D3B)
                                    : Colors.white,
                                child: Center(
                                  child: Text(
                                    _getInitials(name),
                                    style: TextStyle(
                                      color: _kGold.withValues(alpha: 0.8),
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (nationalityCode.isNotEmpty)
                              NationFlagBadge(
                                countryCode: nationalityCode,
                                size: 36,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (position.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kGold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _localizePosition(position),
                              style: const TextStyle(
                                color: _kGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- CONTENT ---
          SliverToBoxAdapter(
            child: _statsLoading
                ? const PlayerStatsSkeleton()
                : _buildOverviewTab(
                    isDark,
                    textColor,
                    cardColor,
                    height,
                    weight,
                    preferredFoot,
                    shirtNumber,
                    nationality,
                    position,
                  ),
          ),
          if (widget.entity is TopScorer)
            SliverToBoxAdapter(
              child: _buildEternalStats(widget.entity as TopScorer, isDark, cardColor, textColor),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildEternalStats(TopScorer scorer, bool isDark, Color cardColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'PERFORMANCES CUMULÉES',
              style: TextStyle(
                color: _kGold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _kGold.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Buts', value: '${scorer.goals}', icon: '⚽'),
                _StatItem(label: 'Passes', value: '${scorer.assists}', icon: '🅰️'),
                _StatItem(label: 'Jaunes', value: '${scorer.yellowCards}', icon: '🟨'),
                _StatItem(label: 'Rouges', value: '${scorer.redCards}', icon: '🟥'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _StatItem({required String label, required String value, required String icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF16324A),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(
    bool isDark,
    Color textColor,
    Color cardColor,
    int height,
    int weight,
    String preferredFoot,
    int shirtNumber,
    String nationality,
    String position,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(isDark, cardColor, textColor, [
            if (shirtNumber > 0)
              _InfoRow(
                icon: Icons.tag,
                label: 'Numéro',
                value: '#$shirtNumber',
                color: _kGold,
              ),
            if (position.isNotEmpty)
              _InfoRow(
                icon: Icons.sports_soccer_rounded,
                label: 'Poste',
                value: _localizePosition(position),
                color: Colors.teal,
              ),
            if (nationality.isNotEmpty)
              _InfoRow(
                icon: Icons.flag_rounded,
                label: 'Nationalité',
                value: nationality.toUpperCase(),
                color: const Color(0xFF4DA3FF),
              ),
            if (height > 0)
              _InfoRow(
                icon: Icons.height,
                label: 'Taille',
                value: '$height cm',
                color: Colors.teal,
              ),
            if (weight > 0)
              _InfoRow(
                icon: Icons.monitor_weight_outlined,
                label: 'Poids',
                value: '$weight kg',
                color: Colors.orange,
              ),
            if (preferredFoot.isNotEmpty)
              _InfoRow(
                icon: Icons.directions_walk_rounded,
                label: 'Pied préféré',
                value: preferredFoot == 'left'
                    ? 'Gauche'
                    : preferredFoot == 'right'
                    ? 'Droit'
                    : preferredFoot,
                color: Colors.purple,
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark,
    Color cardColor,
    Color textColor,
    List<Widget> rows,
  ) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          'Informations non disponibles',
          style: TextStyle(color: textColor.withValues(alpha: 0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children:
            rows
                .expand(
                  (row) => [
                    row,
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ],
                )
                .toList()
              ..removeLast(),
      ),
    );
  }

  String _localizePosition(String pos) {
    final map = {
      'G': 'GARDIEN',
      'GK': 'GARDIEN',
      'goalkeeper': 'GARDIEN',
      'D': 'DÉFENSEUR',
      'defender': 'DÉFENSEUR',
      'M': 'MILIEU',
      'midfielder': 'MILIEU',
      'F': 'ATTAQUANT',
      'forward': 'ATTAQUANT',
    };
    return map[pos] ?? pos.toUpperCase();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  // ─────────────────────────────────────────────
  Map<String, dynamic> _asMap(
    dynamic value, {
    Map<String, dynamic> fallback = const {},
  }) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return fallback;
  }

  List<dynamic> _asList(dynamic value, {List<dynamic> fallback = const []}) {
    if (value is List) return value;
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  num _asNum(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
