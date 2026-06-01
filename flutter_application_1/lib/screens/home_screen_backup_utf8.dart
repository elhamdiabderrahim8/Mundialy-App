import 'dart:async' as java_timer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/top_scorer.dart';
import '../services/api_service.dart';
import '../services/sofa_service.dart';
import '../services/theme_provider.dart';
import '../utils/country_flags.dart';
import '../utils/mock_matches_data.dart';
import '../widgets/nation_flag_badge.dart';
import 'match_details_screen.dart';
import 'team_profile_screen.dart';

/// --- CONSTANTES Ã‰LITE ---
const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);
const Color _kCardDark = Color(0xFF1D2D3B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Ã‰TAT ---
  List<LiveMatch> _matches = [];
  List<GroupStanding> _standings = [];
  List<TopScorer> _topScorers = [];
  List<dynamic> _newsArticles = [];
  
  bool _isLoading = true;
  int _selectedTab = 0;
  int _selectedYear = 2026; 
  int _currentPageIndex = 0;
  
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE DONNÃ‰ES ---

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (_selectedYear == 2026) {
        await _fetch2026Data();
      } else {
        await _fetchLegacyData();
      }
    } catch (e) {
      debugPrint('ðŸ’¥ Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetch2026Data() async {
    try {
      final results = await Future.wait([
        SofaService.fetchWorldCup2026CompleteData(),
        SofaService.fetchWorldCupNews(),
      ]);
      
      final data = (results[0] as Map?)?.cast<String, dynamic>() ?? {};
      final news = (results[1] as List?)?.cast<dynamic>() ?? [];

      _newsArticles = news;
      
      // Parsing Matchs
      if (data.containsKey('games')) {
        final List gamesList = data['games'] ?? [];
        final List competitorsList = data['competitors'] ?? [];
        final Map<int, dynamic> competitorsMap = {
          for (var c in competitorsList) (c['id'] as num).toInt() : c
        };
        _matches = gamesList.map<LiveMatch>((e) => SofaService.mapJsonToLiveMatch(e, competitorsMap)).toList();
      }
      
      // Parsing Standings (Groupes)
      if (data.containsKey('requestedCompetitions')) {
        final List comps = data['requestedCompetitions'] ?? [];
        if (comps.isNotEmpty && comps[0]['stages'] != null) {
          final List stages = comps[0]['stages'];
          _standings = stages
              .where((s) => s['name'] != null && s['name'].toString().contains('Group'))
              .map<GroupStanding>((s) {
            final List rows = s['standings']?['rows'] ?? [];
            return GroupStanding(
              groupName: s['name'] ?? 'Groupe',
              teams: rows.map<StandingTeam>((r) {
                final t = r['competitor'] ?? {};
                String? logo = t['imageURL'] ?? (t['imageRelativePath'] != null 
                    ? 'https://image.365scores.com/image/upload/${t['imageRelativePath']}' 
                    : null);
                return StandingTeam(
                  teamId: (t['id'] as num?)?.toInt() ?? 0,
                  rank: (r['position'] as num?)?.toInt() ?? 0,
                  teamName: t['name'] ?? 'TBD',
                  teamLogo: logo ?? '',
                  played: (r['gamePlayed'] as num?)?.toInt() ?? 0,
                  goalsDiff: (r['goalsDiff'] as num?)?.toInt() ?? 0,
                  points: (r['points'] as num?)?.toInt() ?? 0,
                );
              }).toList(),
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('ðŸ’¥ Error fetching 2026 data: $e');
    }
  }

  Future<void> _fetchLegacyData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMatches(year: _selectedYear),
        ApiService.fetchStandings(year: _selectedYear),
        ApiService.fetchTopScorers(year: _selectedYear),
      ]);
      
      _matches = results[0] as List<LiveMatch>;
      _standings = results[1] as List<GroupStanding>;
      _topScorers = results[2] as List<TopScorer>;
      
      if (_matches.isEmpty && _selectedYear == 2022) {
        _matches = getMockMatches();
      }
    } catch (e) {
      debugPrint('ðŸ’¥ Error fetching legacy data: $e');
    }
  }

  // --- NAVIGATION ---

  void _onTabTap(int index) {
    if (index > 2) {
      setState(() => _selectedTab = index);
      return;
    }
    if (_selectedTab == index) {
      _showSelectionPicker();
      return;
    }
    setState(() {
      _selectedTab = index;
      _currentPageIndex = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  // --- INTERFACE BUILDERS ---

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _buildBottomNav(),
      body: Container(
        color: isDark ? _kDarkBg : const Color(0xFFF7F2E8),
        child: Stack(
          children: [
            Positioned(
              top: -40, 
              left: -20, 
              child: _AmbientGlow(color: _kGold.withValues(alpha: 0.1), size: 180),
            ),
            NestedScrollView(
              headerSliverBuilder: (context, _) => [_buildCollapsingHeader()],
              body: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: _kGold))
                : _buildMainContent(textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(Color textColor) {
    // Mode Accueil 2026
    if (_selectedTab == 0 && _selectedYear == 2026) {
      return _buildModernHome2026(textColor);
    }
    
    // Autres onglets (Legacy)
    switch (_selectedTab) {
      case 3: return _buildStandingsView(textColor);
      case 4: return _buildTopScorersView(textColor);
      case 5: return _buildBracketView(textColor);
      default: return _buildPagedMatchView(textColor);
    }
  }

  Widget _buildModernHome2026(Color textColor) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const _TournamentHero(),
        const SizedBox(height: 24),
        
        // Section Groupes
        _SectionHeader(
          icon: Icons.leaderboard_rounded,
          title: 'GROUPES OFFICIELS',
          subtitle: 'DonnÃ©es en direct 365Scores',
          textColor: textColor,
        ),
        const SizedBox(height: 12),
        if (_standings.isNotEmpty)
          _GroupsAutoCarousel(groups: _standings, textColor: textColor)
        else
          const _EmptyState(msg: 'Aucun classement de groupe disponible pour le moment.'),
        const SizedBox(height: 24),

        // Section News
        _SectionHeader(
          icon: Icons.rss_feed_rounded,
          title: 'ACTUALITÃ‰S MONDIAL 2026',
          subtitle: 'Les derniÃ¨res infos en franÃ§ais',
          textColor: textColor,
        ),
        const SizedBox(height: 12),
        _buildNewsHorizontalList(),
        const SizedBox(height: 24),

        // Section Matchs
        _SectionHeader(
          icon: Icons.star_border_rounded,
          title: 'MATCHS Ã€ VENIR',
          subtitle: 'Calendrier officiel du tournoi',
          textColor: textColor,
        ),
        const SizedBox(height: 12),
        ..._buildUpcomingMatches(textColor),
      ],
    );
  }

  // --- WIDGETS PRIVÃ‰S ---

  Widget _buildNewsHorizontalList() {
    if (_newsArticles.isEmpty) {
      return const SizedBox(
        height: 280,
        child: _EmptyState(msg: 'Aucune actualitÃ© disponible pour le moment.'),
      );
    }
    
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _newsArticles.length,
        itemBuilder: (context, i) => _NewsCard(
          item: _newsArticles[i], 
          onTap: () => _openUrl(_newsArticles[i]['url']),
        ),
      ),
    );
  }

  List<Widget> _buildUpcomingMatches(Color textColor) {
    if (_matches.isEmpty) {
      return const [
        SizedBox(
          height: 150,
          child: _EmptyState(msg: 'Aucun match programmÃ© pour le moment.'),
        ),
      ];
    }
    return _matches.take(5).map((m) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _MatchCard(match: m, year: _selectedYear, textColor: textColor),
    )).toList();
  }

  Widget _buildPagedMatchView(Color textColor) {
    // Logique simplifiÃ©e de pagination de matchs par date/ville/Ã©quipe
    return const Center(child: Text('Vue Matchs PaginÃ©e'));
  }

  Widget _buildStandingsView(Color textColor) {
    if (_standings.isEmpty) {
      return const _EmptyState(msg: 'Aucun classement disponible pour le moment.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _standings.length,
      itemBuilder: (context, i) => _GroupTable(group: _standings[i], textColor: textColor),
    );
  }

  Widget _buildTopScorersView(Color textColor) {
    if (_topScorers.isEmpty) {
      return const _EmptyState(msg: 'Aucun buteur disponible pour le moment.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topScorers.length,
      itemBuilder: (context, i) => ListTile(
        leading: CircleAvatar(backgroundImage: NetworkImage(_topScorers[i].playerPhoto)),
        title: Text(
          _topScorers[i].playerName, 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${_topScorers[i].goals} G', 
          style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBracketView(Color textColor) {
    return const _EmptyState(msg: 'L\'arbre de la phase finale n\'est pas encore disponible.');
  }

  Widget _buildCollapsingHeader() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? _kCardDark : const Color(0xFFF2E5CA),
      expandedHeight: 220,
      title: const Text('Mondial 2026', style: TextStyle(fontWeight: FontWeight.bold)),
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          'https://images.unsplash.com/photo-1517927033932-b3d18e61fb3a?auto=format&fit=crop&w=800&q=60',
          fit: BoxFit.cover,
        ),
      ),
      actions: [
        IconButton(onPressed: _loadInitialData, icon: const Icon(Icons.refresh_rounded)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: isDark ? const Color(0xFF1A242D) : Colors.white,
      selectedItemColor: _kGold,
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedTab,
      onTap: _onTabTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Live'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Matchs'),
        BottomNavigationBarItem(icon: Icon(Icons.format_list_numbered), label: 'Groupes'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Buteurs'),
        BottomNavigationBarItem(icon: Icon(Icons.account_tree_outlined), label: 'Bracket'),
      ],
    );
  }

  // --- HELPERS ---

  void _showSelectionPicker() {
    // Logique de picker pour sÃ©lectionner l'annÃ©e ou l'Ã©dition
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// --- COMPOSANTS UNITAIRES SÃ‰CURISÃ‰S ---

class _TournamentHero extends StatelessWidget {
  const _TournamentHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=60', 
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, 
                  end: Alignment.bottomCenter, 
                  colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.9)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                  decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(6)), 
                  child: const Text('UNITED 2026', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'FIFA World Cup', 
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 8, 
                  runSpacing: 8,
                  children: [
                    _HeroChip(icon: Icons.calendar_month_rounded, label: 'Calendrier'),
                    _HeroChip(icon: Icons.stadium_rounded, label: 'Stades'),
                    _HeroChip(icon: Icons.public_rounded, label: 'Nations'),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(top: 60, right: 20, child: _CountdownBadge()),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon; 
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(icon, color: Colors.white, size: 14), 
          const SizedBox(width: 6), 
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: _kGold.withValues(alpha: 0.5)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('J-748', style: TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 18)), 
          Text('AVANT DÃ‰PART', style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon; 
  final String title; 
  final String subtitle; 
  final Color textColor;

  const _SectionHeader({required this.icon, required this.title, required this.subtitle, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40, 
            height: 40, 
            decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), 
            child: Icon(icon, color: _kGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  title, 
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5), 
                  overflow: TextOverflow.ellipsis,
                ), 
                Text(
                  subtitle, 
                  style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11), 
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final LiveMatch match; 
  final int year; 
  final Color textColor;

  const _MatchCard({required this.match, required this.year, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      color: isDark ? _kCardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: match))),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Flexible(
                    child: Text(
                      match.localTime, 
                      style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ), 
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      match.phaseLabel, 
                      style: const TextStyle(color: Colors.grey, fontSize: 11), 
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.homeTeam, 
                      textAlign: TextAlign.right, 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14), 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 70, 
                    alignment: Alignment.center, 
                    child: Text(
                      match.scoreHome != null ? '${match.scoreHome} - ${match.scoreAway}' : 'VS', 
                      style: const TextStyle(color: _kGold, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.awayTeam, 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14), 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item; 
  final VoidCallback onTap;

  const _NewsCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item['img'] != null && item['img'].toString().isNotEmpty) 
                Image.network(
                  item['img'], 
                  fit: BoxFit.cover, 
                  errorBuilder: (_,__,___) => Container(color: Colors.grey[900]),
                )
              else
                Container(color: Colors.grey[900]),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter, 
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), 
                      decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(6)), 
                      child: Text(
                        item['source'] ?? 'News', 
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] ?? '', 
                      maxLines: 2, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2), 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsAutoCarousel extends StatefulWidget {
  final List<GroupStanding> groups; 
  final Color textColor;

  const _GroupsAutoCarousel({required this.groups, required this.textColor});

  @override
  State<_GroupsAutoCarousel> createState() => _GroupsAutoCarouselState();
}

class _GroupsAutoCarouselState extends State<_GroupsAutoCarousel> {
  late PageController _controller; 
  int _currentIndex = 0; 
  late java_timer.Timer _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.9);
    _timer = java_timer.Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentIndex < widget.groups.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
      if (_controller.hasClients) {
        _controller.animateToPage(
          _currentIndex, 
          duration: const Duration(milliseconds: 800), 
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() { 
    _timer.cancel(); 
    _controller.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.groups.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) => _GroupCard(group: widget.groups[i]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: List.generate(
              widget.groups.length, 
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300), 
                margin: const EdgeInsets.symmetric(horizontal: 3), 
                width: i == _currentIndex ? 18 : 6, 
                height: 6, 
                decoration: BoxDecoration(
                  color: i == _currentIndex ? _kGold : Colors.white24, 
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupStanding group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A39), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            group.groupName.toUpperCase(), 
            style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
          ),
          const Divider(color: Colors.white10, height: 20),
          ...group.teams.take(4).map((t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 20, 
                  child: Text(
                    '${t.rank}', 
                    style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                NationFlagBadge(countryCode: resolveCountryCode(t.teamName), size: 20, imageUrlOverride: t.teamLogo),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.teamName, 
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), 
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${t.points} PTS', 
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _GroupTable extends StatelessWidget {
  final GroupStanding group; 
  final Color textColor;

  const _GroupTable({required this.group, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: textColor.withValues(alpha: 0.04),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            title: Text(group.groupName, style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, color: Colors.white10),
          ...group.teams.map((t) => ListTile(
            dense: true,
            leading: NationFlagBadge(countryCode: resolveCountryCode(t.teamName), size: 24, imageUrlOverride: t.teamLogo),
            title: Text(
              t.teamName, 
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${t.points} pts', style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  final Color color; 
  final double size;

  const _AmbientGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, 
      height: size, 
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;

  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.grey.withValues(alpha: 0.5), size: 48), 
              const SizedBox(height: 16), 
              Text(
                msg, 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label; 
  final VoidCallback onTap; 
  final bool selected;

  const _TabPill({required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap, 
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), 
          padding: const EdgeInsets.symmetric(vertical: 12), 
          decoration: BoxDecoration(
            color: selected ? _kGold.withValues(alpha: 0.15) : Colors.transparent, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: selected ? _kGold : Colors.transparent),
          ), 
          child: Center(
            child: Text(
              label, 
              style: TextStyle(color: selected ? _kGold : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

