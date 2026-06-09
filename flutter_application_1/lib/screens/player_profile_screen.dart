import 'package:flutter/material.dart';
import '../models/team_player.dart';
import '../services/api_service.dart';
import '../widgets/nation_flag_badge.dart';
import '../utils/country_flags.dart';

const _kGold = Color(0xFFE7C16A);

class PlayerProfileScreen extends StatefulWidget {
  final dynamic entity; // TeamPlayer ou TeamCoach
  final int season;

  const PlayerProfileScreen({
    super.key,
    required this.entity,
    this.season = 2022,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _statsData;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    final String name = widget.entity.name;
    final String? photo = widget.entity.photoUrl;
    final String nationality = widget.entity.nationality ?? '';
    final String nationalityCode = widget.entity is TeamPlayer
        ? (widget.entity as TeamPlayer).nationalityCode
        : resolveCountryCode(nationality);

    // Extract data from new unified format
    final characteristics = (_statsData?['characteristics'] ?? {}) as Map<String, dynamic>;
    final attributes = (_statsData?['attributes'] ?? {}) as Map<String, dynamic>;
    final nationalStats = (_statsData?['nationalStats'] ?? {}) as Map<String, dynamic>;
    final tournamentStats =
        (_statsData?['tournamentStats'] ?? {}) as Map<String, dynamic>;

    // Characteristics
    final charData = characteristics['playerCharacteristics'] ?? characteristics;
    final String preferredFoot = charData['preferredFoot']?.toString() ?? '';
    final int height = charData['height'] ?? 0;
    final int weight = charData['weight'] ?? 0;
    final String position = charData['position'] ?? (widget.entity is TeamPlayer ? (widget.entity as TeamPlayer).position : '');
    final int shirtNumber = widget.entity is TeamPlayer ? ((widget.entity as TeamPlayer).shirtNumber ?? 0) : 0;

    // Attributes — style FIFA
    final List<dynamic> attrCategories = attributes['averageAttributeOverviews'] ?? [];

    // National team stats
    final List<dynamic> natStatsList = (nationalStats['statistics'] as List?) ?? 
        (nationalStats['response'] as List?) ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // --- HERO APP BAR ---
          SliverAppBar(
            expandedHeight: 280,
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
                            : [const Color(0xFFEAF0F6), const Color(0xFFF7F2E8)],
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
                                backgroundImage: (photo != null && photo.isNotEmpty)
                                    ? NetworkImage(photo)
                                    : null,
                                child: (photo == null || photo.isEmpty)
                                    ? Icon(
                                        Icons.person,
                                        size: 55,
                                        color: _kGold.withValues(alpha: 0.5),
                                      )
                                    : null,
                              ),
                            ),
                            if (nationalityCode.isNotEmpty)
                              NationFlagBadge(countryCode: nationalityCode, size: 36),
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
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: _kGold.withValues(alpha: 0.4)),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: cardColor,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: _kGold,
                  labelColor: _kGold,
                  unselectedLabelColor:
                      isDark ? Colors.white54 : Colors.black54,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'PROFIL'),
                    Tab(text: 'ATTRIBUTS'),
                    Tab(text: 'STATS'),
                  ],
                ),
              ),
            ),
          ),

          // --- CONTENT ---
          SliverFillRemaining(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kGold))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1 — PROFIL
                      _buildProfileTab(
                          isDark, textColor, cardColor,
                          height, weight, preferredFoot, shirtNumber, nationality),
                      // Tab 2 — ATTRIBUTS FIFA
                      _buildAttributesTab(
                          isDark, textColor, cardColor, attrCategories),
                      // Tab 3 — STATS tournoi + équipe nationale
                      _buildNationalStatsTab(
                        isDark,
                        textColor,
                        cardColor,
                        natStatsList,
                        tournamentStats,
                        widget.season,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildProfileTab(bool isDark, Color textColor, Color cardColor,
      int height, int weight, String preferredFoot, int shirtNumber, String nationality) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoCard(isDark, cardColor, textColor, [
            if (shirtNumber > 0)
              _InfoRow(icon: Icons.tag, label: 'Numéro', value: '#$shirtNumber', color: _kGold),
            if (nationality.isNotEmpty)
              _InfoRow(icon: Icons.flag_rounded, label: 'Nationalité', value: nationality.toUpperCase(), color: Colors.blue),
            if (height > 0)
              _InfoRow(icon: Icons.height, label: 'Taille', value: '${height} cm', color: Colors.teal),
            if (weight > 0)
              _InfoRow(icon: Icons.monitor_weight_outlined, label: 'Poids', value: '${weight} kg', color: Colors.orange),
            if (preferredFoot.isNotEmpty)
              _InfoRow(
                icon: Icons.sports_soccer_rounded,
                label: 'Pied préféré',
                value: preferredFoot == 'left' ? '🦶 Gauche' : preferredFoot == 'right' ? '🦶 Droit' : preferredFoot,
                color: Colors.purple,
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, Color cardColor, Color textColor, List<Widget> rows) {
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
        children: rows
            .expand((row) => [row, Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))])
            .toList()
          ..removeLast(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildAttributesTab(bool isDark, Color textColor, Color cardColor,
      List<dynamic> attrCategories) {
    if (attrCategories.isEmpty) {
      return Center(
        child: Text(
          'Attributs non disponibles',
          style: TextStyle(color: textColor.withValues(alpha: 0.5)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: attrCategories.map<Widget>((cat) {
          final String catName = cat['name']?.toString() ?? '';
          final List<dynamic> items = cat['averageAttributes'] ?? cat['items'] ?? [];
          return _buildAttributeCategory(isDark, cardColor, textColor, catName, items);
        }).toList(),
      ),
    );
  }

  Widget _buildAttributeCategory(bool isDark, Color cardColor, Color textColor,
      String name, List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) ...[
            Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: _kGold,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...items.map((item) {
            final String attrName = item['name']?.toString() ?? '';
            final num value = item['value'] ?? item['average'] ?? 0;
            return _buildAttributeBar(textColor, attrName, value.toDouble());
          }),
        ],
      ),
    );
  }

  Widget _buildAttributeBar(Color textColor, String label, double value) {
    final Color barColor = value >= 80
        ? Colors.green
        : value >= 65
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (value / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor.withValues(alpha: 0.7), barColor],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              color: barColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildNationalStatsTab(
    bool isDark,
    Color textColor,
    Color cardColor,
    List<dynamic> statsList,
    Map<String, dynamic> tournamentStats,
    int season,
  ) {
    final wcStats = tournamentStats['statistics'] as Map<String, dynamic>? ??
        tournamentStats['stats'] as Map<String, dynamic>?;

    if (statsList.isEmpty && (wcStats == null || wcStats.isEmpty)) {
      return Center(
        child: Text(
          'Statistiques non disponibles',
          style: TextStyle(color: textColor.withValues(alpha: 0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (wcStats != null && wcStats.isNotEmpty) ...[
          _buildTournamentStatsCard(
            isDark,
            textColor,
            cardColor,
            wcStats,
            season,
          ),
          const SizedBox(height: 12),
        ],
        ...List.generate(statsList.length, (i) {
          return _buildNationalStatItem(
            isDark,
            textColor,
            cardColor,
            statsList[i] as Map<String, dynamic>,
          );
        }),
      ],
    );
  }

  Widget _buildTournamentStatsCard(
    bool isDark,
    Color textColor,
    Color cardColor,
    Map<String, dynamic> stats,
    int season,
  ) {
    final entries = <String, dynamic>{
      'Matchs': stats['appearances'] ?? stats['matches'],
      'Buts': stats['goals'],
      'Passes': stats['assists'],
      'Minutes': stats['minutesPlayed'] ?? stats['minutes'],
      'Cartons jaunes': stats['yellowCards'],
      'Cartons rouges': stats['redCards'],
    }..removeWhere((_, v) => v == null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coupe du Monde $season',
            style: const TextStyle(
              color: _kGold,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalStatItem(
    bool isDark,
    Color textColor,
    Color cardColor,
    Map<String, dynamic> stat,
  ) {
    final team = stat['team'] as Map<String, dynamic>? ?? {};
    final stats = stat['statistics'] as Map<String, dynamic>? ?? {};
    final season = stat['tournament']?['season']?['name'] ??
        stat['season']?['name'] ??
        stat['uniqueTournament']?['name'] ??
        'Tournoi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if ((team['id'] as int?) != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    'https://api.sofascore.app/api/v1/team/${team['id']}/image',
                    width: 28,
                    height: 28,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.flag, size: 28, color: _kGold),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team['name']?.toString() ?? 'Équipe Nationale',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      season,
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNatStatsGrid(stats, textColor),
        ],
      ),
    );
  }

  Widget _buildNatStatsGrid(Map<String, dynamic> stats, Color textColor) {
    final items = <Map<String, String>>[];
    if (stats['appearances'] != null)
      items.add({'label': 'Matchs', 'value': '${stats['appearances']}'});
    if (stats['goals'] != null)
      items.add({'label': 'Buts', 'value': '${stats['goals']}'});
    if (stats['goalAssists'] != null)
      items.add({'label': 'Passes D.', 'value': '${stats['goalAssists']}'});
    if (stats['minutesPlayed'] != null)
      items.add({'label': 'Minutes', 'value': "${stats['minutesPlayed']}'"});
    if (stats['yellowCards'] != null)
      items.add({'label': 'Cartons J.', 'value': '${stats['yellowCards']}'});
    if (stats['rating'] != null)
      items.add({'label': 'Note', 'value': (stats['rating'] as num).toStringAsFixed(2)});

    if (items.isEmpty) {
      return Text(
        'Aucune statistique disponible',
        style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGold.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                item['value']!,
                style: const TextStyle(
                  color: _kGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                item['label']!,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _localizePosition(String pos) {
    final map = {
      'G': 'GARDIEN', 'GK': 'GARDIEN', 'goalkeeper': 'GARDIEN',
      'D': 'DÉFENSEUR', 'defender': 'DÉFENSEUR',
      'M': 'MILIEU', 'midfielder': 'MILIEU',
      'F': 'ATTAQUANT', 'forward': 'ATTAQUANT',
    };
    return map[pos] ?? pos.toUpperCase();
  }
}

// ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.color});

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
