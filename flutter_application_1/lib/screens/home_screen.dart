import 'dart:async' as java_timer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../main.dart';
import '../models/live_match.dart';
import '../models/standings.dart';
import '../models/top_scorer.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../utils/country_flags.dart';
import '../utils/mock_matches_data.dart';
import '../widgets/nation_flag_badge.dart';
import 'match_details_screen.dart';
import 'team_profile_screen.dart';
import 'news_detail_screen.dart';
import 'iptv/iptv_main_screen.dart';

/// --- CONSTANTES ÉLITE ---
const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);
const Color _kCardDark = Color(0xFF1D2D3B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- ÉTAT ---
  List<LiveMatch> _matches = [];
  List<GroupStanding> _standings = [];
  List<TopScorer> _topScorers = [];
  List<dynamic> _newsArticles = [];

  bool _isLoading = true;
  int _selectedTab = 0;
  int _selectedYear = 2026; // World Cup 2026 par défaut (tournoi en cours)
  int _matchFilterMode = 0; // 0=Par Date, 1=Par Équipe, 2=Par Groupe

  late PageController _pageController;
  java_timer.Timer? _liveTimer;
  java_timer.StreamSubscription<void>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    ApiService.initNotifications();
    _loadInitialData();

    // Écouter les notifications FCM pour rafraîchir brusquement
    _refreshSubscription = refreshStreamController.stream.listen((_) {
      debugPrint('🔄 FCM déclenche un rafraîchissement brusque !');
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _pageController.dispose();
    _liveTimer?.cancel();
    _silentRefreshTimer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE DE DONNÉES ---

  // State for news team filter
  String _selectedNewsTeam = '';

  // Charge les news uniquement (pour le filtre pays)
  Future<void> _loadNews() async {
    if (!mounted) return;
    try {
      final articles = await ApiService.fetchNews(team: _selectedNewsTeam);
      if (mounted) {
        setState(() {
          _newsArticles = (articles as List?)?.cast<dynamic>() ?? [];
        });
      }
    } catch (e) {
      // Ignorer l'erreur silencieusement
    }
  }

  // Updated fetch method to include optional team filter for news
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    _liveTimer?.cancel();
    setState(() => _isLoading = true);
    try {
      if (_selectedYear == -1) {
        await _fetchLiveMode();
        _liveTimer = java_timer.Timer.periodic(
          const Duration(seconds: 5),
          (_) => _fetchLiveMode(),
        );
      } else {
        // Fetch unified data including news with optional team filter
        final results = await Future.wait([
          ApiService.fetchMatches(year: _selectedYear),
          ApiService.fetchStandings(year: _selectedYear),
          ApiService.fetchTopScorers(year: _selectedYear),
          ApiService.fetchNews(team: _selectedNewsTeam),
        ]);
        _matches = (results[0] as List?)?.cast<LiveMatch>() ?? [];
        _standings = (results[1] as List?)?.cast<GroupStanding>() ?? [];
        _topScorers = (results[2] as List?)?.cast<TopScorer>() ?? [];
        _newsArticles = (results[3] as List?)?.cast<dynamic>() ?? [];
        if (_matches.isEmpty && _selectedYear == 2022)
          _matches = getMockMatches();

        // Auto-refresh silencieux des scores (30s) si matchs en cours aujourd'hui
        _startSilentScoreRefresh();
      }
    } catch (e) {
      debugPrint('💥 Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  java_timer.Timer? _silentRefreshTimer;

  void _startSilentScoreRefresh() {
    _silentRefreshTimer?.cancel();
    final now = DateTime.now();
    final hasLiveOrTodayMatches = _matches.any((m) {
      if (m.isLive) return true;
      final dt = m.dateTime;
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    });
    if (!hasLiveOrTodayMatches || _selectedYear == 2022) return;
    // Refresh silencieux toutes les 30 secondes (sans spinner)
    _silentRefreshTimer = java_timer.Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (!mounted) return;
        try {
          final freshMatches = await ApiService.fetchMatches(year: _selectedYear, forceRefresh: true);
          if (mounted && freshMatches.isNotEmpty) {
            setState(() => _matches = freshMatches);
          }
        } catch (_) {}
      },
    );
  }

  bool _isFetchingLive = false;
  Future<void> _fetchLiveMode() async {
    if (_isFetchingLive) return;
    _isFetchingLive = true;
    try {
      final liveMatches = await ApiService.fetchLiveMatches();
      if (mounted) {
        setState(() {
          _matches = liveMatches;
        });

        // Mettre à jour l'Overlay si un match est épinglé
        if (liveMatches.isNotEmpty && await FlutterOverlayWindow.isActive()) {
          // On cherche si un de nos matchs live est celui de l'overlay (exemple simplifié)
          final m = liveMatches.first;
          FlutterOverlayWindow.shareData({
            'home': m.homeTeam,
            'away': m.awayTeam,
            'score': '${m.scoreHome ?? 0} - ${m.scoreAway ?? 0}',
          });
        }
      }
    } catch (e) {
      debugPrint('Live Fetch Error: $e');
    } finally {
      _isFetchingLive = false;
    }
  }

  // --- NAVIGATION ---
  void _onTabTap(int index) {
    if (index > 2) {
      setState(() => _selectedTab = index);
      return;
    }
    if (_selectedTab == index) {
      _showFilterBottomSheet(_selectedTab == 2 ? _matchFilterMode : 0);
      return;
    }
    setState(() {
      _selectedTab = index;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : Colors.black87;

    if (_selectedTab == 1) {
      return Scaffold(
        bottomNavigationBar: _buildBottomNav(),
        body: const IptvMainScreen(),
      );
    }

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
              child: _AmbientGlow(
                color: _kGold.withValues(alpha: 0.1),
                size: 180,
              ),
            ),
            NestedScrollView(
              headerSliverBuilder: (context, _) => [_buildCollapsingHeader()],
              body: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kGold),
                    )
                  : _buildMainContent(textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(Color textColor) {
    if (_selectedTab == 0 && _selectedYear == 2026)
      return _buildModernHome2026(textColor);
    switch (_selectedTab) {
      case 0:
        return _buildPagedMatchView(textColor);
      case 1:
        return _buildPagedMatchView(textColor); // Live View
      case 2:
        return _buildCalendrierView(textColor);
      case 3:
        return _buildStandingsView(textColor);
      case 4:
        return _buildTopScorersView(textColor);
      case 5:
        return _buildBracketView(textColor);
      default:
        return _buildPagedMatchView(textColor);
    }
  }

  Widget _buildCalendrierView(Color textColor) {
    return Column(
      children: [
        _MatchFilterBar(
          selected: _matchFilterMode,
          onSelect: (i) {
            if (_matchFilterMode != i) {
              setState(() {
                _matchFilterMode = i;
              });
              if (_pageController.hasClients) _pageController.jumpToPage(0);
            } else {
              _showFilterBottomSheet(i);
            }
          },
        ),
        Expanded(child: _buildPagedMatchView(textColor)),
      ],
    );
  }

  Widget _buildModernHome2026(Color textColor) {
    return RefreshIndicator(
      color: _kGold,
      backgroundColor: isDark ? _kCardDark : Colors.white,
      onRefresh: _loadInitialData,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── HERO BANNER ──
          const _TournamentHero2026(),
          const SizedBox(height: 20),

          // ── LIVE / IN-PROGRESS MATCHES ──
          if (_matches.any((m) => m.isLive)) ...[
            _SectionHeader(
              icon: Icons.bolt_rounded,
              title: 'EN DIRECT',
              subtitle: 'Matchs en cours maintenant',
              textColor: textColor,
            ),
            const SizedBox(height: 12),
            ..._matches
                .where((m) => m.isLive)
                .map(
                  (m) => _AnimatedEntrance(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _LiveMatchCard2026(match: m, textColor: textColor),
                    ),
                  ),
                ),
            const SizedBox(height: 24),
          ],

          // ── NEWS SECTION ──
          _SectionHeader(
            icon: Icons.newspaper_rounded,
            title: 'ACTUALITÉS FIFA',
            subtitle: 'Les dernières nouvelles du Mondial',
            textColor: textColor,
          ),
          const SizedBox(height: 10),
          // Team filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip2026(
                  label: 'TOUT',
                  isSelected: _selectedNewsTeam.isEmpty,
                  onTap: () {
                    if (_selectedNewsTeam.isNotEmpty) {
                      setState(() => _selectedNewsTeam = '');
                      _loadNews(); // Refresh news UNIQUEMENT
                    }
                  },
                ),
                ...[
                  'France',
                  'Argentina',
                  'Brazil',
                  'England',
                  'Germany',
                  'Spain',
                  'Mexico',
                  'USA',
                  'Morocco',
                  'Japan',
                ].map((name) {
                  final isSelected =
                      _selectedNewsTeam.toLowerCase() == name.toLowerCase();
                  return _FilterChip2026(
                    label: name.toUpperCase(),
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedNewsTeam = isSelected ? '' : name;
                      });
                      _loadNews(); // Refresh news UNIQUEMENT
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildNewsCarousel2026(),
          const SizedBox(height: 28),

          // ── STANDINGS / GROUPS ──
          if (_standings.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.leaderboard_rounded,
              title: 'CLASSEMENTS',
              subtitle: 'Phase de groupes – Données en direct',
              textColor: textColor,
            ),
            const SizedBox(height: 12),
            _GroupsAutoCarousel(groups: _standings, textColor: textColor),
            const SizedBox(height: 28),
          ],

          // ── UPCOMING MATCHES ──
          _SectionHeader(
            icon: Icons.calendar_month_rounded,
            title: 'PROGRAMME',
            subtitle: 'Prochains matchs du tournoi',
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          ..._buildUpcomingMatchCards2026(textColor),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildNewsCarousel2026() {
    if (_newsArticles.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: Colors.grey.withValues(alpha: 0.4),
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Actualités indisponibles',
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _newsArticles.length,
        itemBuilder: (context, i) => _AnimatedEntrance(
          delay: Duration(milliseconds: 80 * i),
          child: _NewsCard2026(
            item: _newsArticles[i],
            onTap: () {
              // Naviguer vers l'écran détail de l'article
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) => FadeTransition(
                    opacity: animation,
                    child: NewsDetailScreen(
                      article: Map<String, dynamic>.from(
                          _newsArticles[i] as Map),
                    ),
                  ),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUpcomingMatchCards2026(Color textColor) {
    final upcoming = _matches.where((m) => !m.isLive).toList();
    if (upcoming.isEmpty) {
      return [
        const SizedBox(
          height: 120,
          child: _EmptyState(msg: 'Aucun match programmé pour le moment.'),
        ),
      ];
    }
    // Group by date
    final grouped = <String, List<LiveMatch>>{};
    for (final m in upcoming) {
      grouped.putIfAbsent(m.dateLabel, () => []).add(m);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = grouped[a]!.first.dateTime;
        final dateB = grouped[b]!.first.dateTime;
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

    final widgets = <Widget>[];
    for (final key in sortedKeys.take(5)) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: _kGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                key.toUpperCase(),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );
      for (final m in grouped[key]!) {
        widgets.add(
          _AnimatedEntrance(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _MatchCard(
                match: m,
                year: _selectedYear,
                textColor: textColor,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildPagedMatchView(Color textColor) {
    final List<String> Function(LiveMatch) keysOf;
    if (_selectedTab == 2) {
      switch (_matchFilterMode) {
        case 1:
          keysOf = (m) => [m.homeTeam, m.awayTeam];
          break; // Group by Team
        case 2:
          keysOf = (m) {
            final s = _standings.firstWhere(
              (st) => st.teams.any((t) => t.teamName == m.homeTeam),
              orElse: () => GroupStanding(groupName: 'Autre', teams: []),
            );
            return [s.groupName];
          };
          break;
        default:
          keysOf = (m) => [m.dateLabel];
      }
    } else {
      keysOf = (m) => [m.dateLabel];
    }
    final grouped = <String, List<LiveMatch>>{};
    for (final m in _matches) {
      for (final key in keysOf(m)) {
        grouped.putIfAbsent(key, () => []).add(m);
      }
    }
    final keys = grouped.keys.toList();
    if (_selectedTab == 2 && (_matchFilterMode == 1 || _matchFilterMode == 2)) {
      keys.sort();
    } else {
      keys.sort((a, b) {
        final mA = grouped[a]!.first.dateTime;
        final mB = grouped[b]!.first.dateTime;
        if (mA == null || mB == null) return 0;
        return mA.compareTo(mB);
      });
    }
    if (keys.isEmpty) return const _EmptyState(msg: 'Aucun match disponible.');
    return PageView.builder(
      controller: _pageController,
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final matches = grouped[key] ?? [];
        // Separate into live, upcoming, finished
        final liveMatches = matches.where((m) => m.isLive).toList();
        final upcomingMatches = matches
            .where((m) => !m.isLive && !m.isFinished)
            .toList();
        final finishedMatches = matches.where((m) => m.isFinished).toList();

        final List<Widget> items = [];
        // Page header with navigation
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (index > 0)
                  GestureDetector(
                    onTap: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _kGold,
                        size: 16,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    key.toUpperCase(),
                    style: const TextStyle(
                      color: _kGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (index < keys.length - 1)
                  GestureDetector(
                    onTap: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _kGold,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        // Live matches section
        if (liveMatches.isNotEmpty) {
          items.add(
            _StatusSectionHeader(
              icon: Icons.bolt_rounded,
              label: 'EN DIRECT',
              color: Colors.redAccent,
            ),
          );
          for (final m in liveMatches) {
            items.add(
              _MatchCard(match: m, year: _selectedYear, textColor: textColor),
            );
          }
        }
        // Upcoming matches section
        if (upcomingMatches.isNotEmpty) {
          items.add(
            _StatusSectionHeader(
              icon: Icons.schedule_rounded,
              label: 'À VENIR',
              color: _kGold,
            ),
          );
          for (final m in upcomingMatches) {
            items.add(
              _MatchCard(match: m, year: _selectedYear, textColor: textColor),
            );
          }
        }
        // Finished matches section
        if (finishedMatches.isNotEmpty) {
          items.add(
            _StatusSectionHeader(
              icon: Icons.check_circle_outline_rounded,
              label: 'TERMINÉS',
              color: Colors.grey,
            ),
          );
          for (final m in finishedMatches) {
            items.add(
              _MatchCard(match: m, year: _selectedYear, textColor: textColor),
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: items,
        );
      },
    );
  }

  Widget _buildStandingsView(Color textColor) {
    if (_standings.isEmpty)
      return const _EmptyState(msg: 'Aucun classement disponible.');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _standings.length,
      itemBuilder: (context, i) => _GroupTable(
        group: _standings[i],
        textColor: textColor,
        year: _selectedYear,
      ),
    );
  }

  Widget _buildTopScorersView(Color textColor) {
    if (_topScorers.isEmpty)
      return const _EmptyState(msg: 'Aucun buteur disponible.');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _topScorers.length,
      itemBuilder: (context, i) => ListTile(
        leading: CircleAvatar(
          backgroundImage: _topScorers[i].playerPhoto.isNotEmpty
              ? NetworkImage(_topScorers[i].playerPhoto)
              : null,
        ),
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
    final rounds = _buildKnockoutRounds(_matches);
    if (rounds.isEmpty)
      return const _EmptyState(msg: 'Phase finale non disponible.');
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'PHASE FINALE',
          style: TextStyle(
            color: _kGold,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 3,
          ),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(20),
            itemCount: rounds.length,
            itemBuilder: (context, i) {
              final round = rounds[i];
              return Container(
                width: 300,
                margin: const EdgeInsets.only(right: 30),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _kGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        round.$1.toUpperCase(),
                        style: const TextStyle(
                          color: _kGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: ListView.builder(
                        itemCount: round.$2.length,
                        itemBuilder: (context, mIdx) => _BracketMatchCard(
                          match: round.$2[mIdx],
                          year: _selectedYear,
                          textColor: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<(String, List<LiveMatch>)> _buildKnockoutRounds(
    List<LiveMatch> matches,
  ) {
    final buckets = <String, List<LiveMatch>>{};
    for (final m in matches) {
      final round = _normalizeRound(m.phaseLabel);
      if (round != null) buckets.putIfAbsent(round, () => []).add(m);
    }
    const order = [
      'Round of 16',
      'Quarter-finals',
      'Semi-finals',
      'Third place',
      'Final',
    ];
    return order
        .where(buckets.containsKey)
        .map((k) => (k, buckets[k]!))
        .toList();
  }

  String? _normalizeRound(String raw) {
    final v = raw.toLowerCase().replaceAll('_', ' ');
    if (v.contains('round of 16') ||
        v.contains('8th finals') ||
        v.contains('huitième'))
      return 'Round of 16';
    if (v.contains('quarter') || v.contains('quart')) return 'Quarter-finals';
    if (v.contains('semi') || v.contains('demi')) return 'Semi-finals';
    if (v.contains('third place') || v.contains('troisième'))
      return 'Third place';
    if (v == 'final' ||
        (v.contains('final') && !v.contains('semi') && !v.contains('quarter')))
      return 'Final';
    return null;
  }

  Widget _buildCollapsingHeader() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? _kCardDark : const Color(0xFFF2E5CA),
      expandedHeight: 250,
      centerTitle: true,
      title: Text(
        _selectedYear == -1 ? 'Live Action' : 'Mondial $_selectedYear',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1517927033932-b3d18e61fb3a?auto=format&fit=crop&w=800&q=60',
              fit: BoxFit.cover,
            ),
            Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.25),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _YearDropdownSelector(
                        selectedYear: _selectedYear,
                        onYearChanged: (y) {
                          if (_selectedYear != y) {
                            setState(() {
                              _selectedYear = y;
                              if (y == -1) _selectedTab = 1;
                            });
                            _loadInitialData();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'FIFA WORLD CUP',
                        style: TextStyle(
                          color: isDark ? _kGold : const Color(0xFF16324A),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: isDark
                              ? null
                              : [
                                  const Shadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _kGold.withValues(alpha: isDark ? 0.5 : 0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  final themeProv = Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  );
                  themeProv.toggleTheme(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: isDark ? _kGold : Colors.black87,
                  size: 20,
                ),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
              Container(
                width: 1,
                height: 20,
                color: _kGold.withValues(alpha: isDark ? 0.3 : 0.8),
              ),
              IconButton(
                onPressed: _loadInitialData,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? _kGold : Colors.black87,
                  size: 20,
                ),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: isDark ? const Color(0xFF1A242D) : Colors.white,
      selectedItemColor: isDark ? _kGold : const Color(0xFF16324A),
      unselectedItemColor: isDark ? Colors.white54 : const Color(0xFF516574),
      currentIndex: _selectedTab,
      onTap: _onTabTap,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Live'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Matchs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.format_list_numbered),
          label: 'Groupes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.emoji_events_outlined),
          label: 'Buteurs',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_tree_outlined),
          label: 'Bracket',
        ),
      ],
    );
  }

  void _showFilterBottomSheet(int mode) {
    if (mode == 0) {
      final currentKeyIndex = _pageController.hasClients
          ? _pageController.page?.round() ?? 0
          : 0;
      final keys = groupedKeys((m) => [m.dateLabel]);
      final selectedDateLabel = keys.isNotEmpty && currentKeyIndex < keys.length
          ? keys[currentKeyIndex]
          : '';
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _CalendarBottomSheet(
          matches: _matches,
          selectedDateLabel: selectedDateLabel,
          isDark: isDark,
          onDateSelected: (dateLabel) {
            final idx = keys.indexOf(dateLabel);
            if (idx != -1) {
              _pageController.jumpToPage(idx);
              Navigator.pop(context);
            }
          },
        ),
      );
    } else {
      final keysOf = mode == 1
          ? (LiveMatch m) => [m.homeTeam, m.awayTeam]
          : (LiveMatch m) {
              final s = _standings.firstWhere(
                (st) => st.teams.any((t) => t.teamName == m.homeTeam),
                orElse: () => GroupStanding(groupName: 'Autre', teams: []),
              );
              return [s.groupName];
            };
      final keys = groupedKeys(keysOf);
      final currentKeyIndex = _pageController.hasClients
          ? _pageController.page?.round() ?? 0
          : 0;
      final selectedItem = keys.isNotEmpty && currentKeyIndex < keys.length
          ? keys[currentKeyIndex]
          : '';
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ListBottomSheet(
          title: mode == 1 ? 'CHOISIR ÉQUIPE' : 'CHOISIR GROUPE',
          items: keys,
          selectedItem: selectedItem,
          isDark: isDark,
          onItemSelected: (idx) {
            _pageController.jumpToPage(idx);
            Navigator.pop(context);
          },
        ),
      );
    }
  }

  List<String> groupedKeys(List<String> Function(LiveMatch) keysOf) {
    final keysSet = <String>{};
    for (final m in _matches) {
      keysSet.addAll(keysOf(m));
    }
    final keys = keysSet.toList();
    if (_selectedTab == 2 && (_matchFilterMode == 1 || _matchFilterMode == 2))
      keys.sort();
    return keys;
  }
}

class _YearDropdownSelector extends StatelessWidget {
  final int selectedYear;
  final void Function(int) onYearChanged;
  const _YearDropdownSelector({
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor = isDark ? const Color(0xFF1E2630) : Colors.white;
    final Color accentColor = _kGold;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: panelColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
          ),
          elevation: 8,
        ),
      ),
      child: PopupMenuButton<int>(
        initialValue: selectedYear,
        onSelected: onYearChanged,
        offset: const Offset(0, 50),
        itemBuilder: (context) {
          return [-1, 2022, 2026].map((y) {
            final isSel = selectedYear == y;
            final label = y == -1 ? 'LIVE EN DIRECT' : 'Coupe du Monde $y';
            return PopupMenuItem<int>(
              value: y,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSel ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      y == -1 ? Icons.bolt_rounded : Icons.check_circle_outline,
                      color: isSel ? accentColor : (isDark ? Colors.white54 : Colors.black54),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSel ? accentColor : (isDark ? Colors.white : Colors.black87),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: panelColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selectedYear == -1 ? Icons.bolt_rounded : Icons.emoji_events_rounded,
                color: selectedYear == -1 ? Colors.redAccent : accentColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  selectedYear == -1 ? 'LIVE ACTION' : 'ÉDITION $selectedYear',
                  style: TextStyle(
                    color: selectedYear == -1
                        ? Colors.redAccent
                        : (isDark ? Colors.white : Colors.black87),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: accentColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusSectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.15)),
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
  const _MatchCard({
    required this.match,
    required this.year,
    required this.textColor,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String centerText = match.scoreHome != null
        ? '${match.scoreHome} - ${match.scoreAway}'
        : 'VS';
    final String? penaltyText =
        (match.penaltyHome != null && match.penaltyAway != null)
        ? '(${match.penaltyHome} - ${match.penaltyAway} TAB)'
        : null;

    return Card(
      elevation: 0,
      color: isDark ? _kCardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: match.isLive
              ? Colors.redAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: match.isLive ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: match)),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // Top row: status + phase
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (match.isLive) ...[
                          const _LiveDot(),
                          const SizedBox(width: 6),
                          Text(
                            match.statusDisplay,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ] else if (match.isFinished) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TERMINÉ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            match.localTime,
                            style: const TextStyle(
                              color: _kGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (match.isLive)
                    GestureDetector(
                      onTap: () => _pinMatch(context, match),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              color: Colors.redAccent,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'ÉPINGLER',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      flex: 2,
                      child: Text(
                        match.phaseLabel,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Teams + Score row
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              match.homeTeam,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        NationFlagBadge(
                          countryCode: match.homeCode,
                          size: 24,
                          imageUrlOverride: match.homeLogoUrl,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          centerText,
                          style: TextStyle(
                            color: match.isLive ? Colors.redAccent : _kGold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (penaltyText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              penaltyText,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        NationFlagBadge(
                          countryCode: match.awayCode,
                          size: 24,
                          imageUrlOverride: match.awayLogoUrl,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              match.awayTeam,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _pinMatch(BuildContext context, LiveMatch match) async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (await FlutterOverlayWindow.isActive()) {
      FlutterOverlayWindow.closeOverlay();
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Live Score",
      overlayContent: "Match en cours",
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.centerLeft,
      visibility: NotificationVisibility.visibilityPublic,
      width: WindowSize.matchParent,
      height: 120,
    );

    FlutterOverlayWindow.shareData({
      'home': match.homeTeam,
      'away': match.awayTeam,
      'homeCode': match.homeCode,
      'awayCode': match.awayCode,
      'score': '${match.scoreHome ?? 0} - ${match.scoreAway ?? 0}',
      'minute': match.matchMinute ?? '',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Match ${match.homeTeam} épinglé sur l\'écran d\'accueil !',
          ),
          backgroundColor: _kGold,
        ),
      );
    }
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({
    required this.match,
    required this.year,
    required this.textColor,
  });
  final LiveMatch match;
  final int year;
  final Color textColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${match.dateLabel} • ${match.localTime}',
                style: const TextStyle(
                  color: _kGold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.bar_chart,
                color: textColor.withValues(alpha: 0.38),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BracketTeamRow(
            name: match.homeTeam,
            code: match.homeCode,
            teamId: match.homeTeamId,
            year: year,
            score: match.scoreHome,
            penalty: match.penaltyHome,
            isWinner:
                match.scoreHome != null &&
                match.scoreAway != null &&
                (match.scoreHome! > match.scoreAway! ||
                    (match.penaltyHome ?? 0) > (match.penaltyAway ?? 0)),
            textColor: textColor,
            logo: match.homeLogoUrl,
          ),
          const SizedBox(height: 10),
          _BracketTeamRow(
            name: match.awayTeam,
            code: match.awayCode,
            teamId: match.awayTeamId,
            year: year,
            score: match.scoreAway,
            penalty: match.penaltyAway,
            isWinner:
                match.scoreHome != null &&
                match.scoreAway != null &&
                (match.scoreAway! > match.scoreHome! ||
                    (match.penaltyAway ?? 0) > (match.penaltyHome ?? 0)),
            textColor: textColor,
            logo: match.awayLogoUrl,
          ),
          const SizedBox(height: 12),
          Text(
            match.city,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.54),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketTeamRow extends StatelessWidget {
  const _BracketTeamRow({
    required this.name,
    required this.code,
    required this.teamId,
    required this.year,
    required this.score,
    this.penalty,
    required this.isWinner,
    required this.textColor,
    this.logo,
  });
  final String name;
  final String code;
  final int? teamId;
  final int year;
  final int? score;
  final int? penalty;
  final bool isWinner;
  final Color textColor;
  final String? logo;
  @override
  Widget build(BuildContext context) {
    final color = isWinner ? _kGold : textColor;
    return Row(
      children: [
        NationFlagBadge(countryCode: code, size: 28, imageUrlOverride: logo),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w500,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (penalty != null)
          Text(
            '($penalty)',
            style: TextStyle(
              color: isWinner
                  ? _kGold.withValues(alpha: 0.8)
                  : textColor.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(width: 6),
        Text(
          score?.toString() ?? '-',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _GroupTable extends StatelessWidget {
  final GroupStanding group;
  final Color textColor;
  final int year;
  const _GroupTable({
    required this.group,
    required this.textColor,
    required this.year,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Center(
              child: Text(
                group.groupName.toUpperCase(),
                style: const TextStyle(
                  color: _kGold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Pos',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Équipe',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'MJ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'GD',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PTS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(color: textColor.withValues(alpha: 0.10), height: 20),
                ...group.teams.map((t) {
                  final isQualif = t.rank <= 2;
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamProfileScreen(
                          teamId: t.teamId,
                          teamName: t.teamName,
                          year: year,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isQualif
                                ? Colors.greenAccent.withValues(alpha: 0.5)
                                : Colors.redAccent.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '${t.rank}',
                                style: TextStyle(
                                  color: isQualif
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                NationFlagBadge(
                                  countryCode: resolveCountryCode(t.teamName),
                                  size: 24,
                                  imageUrlOverride: t.teamLogo,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    t.teamName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${t.played}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${t.goalsDiff}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${t.points}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _kGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildLegendItem(Colors.greenAccent, 'Qualifié'),
                    const SizedBox(width: 16),
                    _buildLegendItem(Colors.redAccent, 'Éliminé'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// ── PREMIUM 2026 WIDGETS ──
// ═══════════════════════════════════════════════════════

/// Entrance animation wrapper – fade + slide up
class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedEntrance({required this.child, this.delay = Duration.zero});
  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Premium hero banner for 2026 with dynamic countdown
class _TournamentHero2026 extends StatelessWidget {
  const _TournamentHero2026();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Calculate real countdown to June 11, 2026
    final now = DateTime.now();
    final kickoff = DateTime(2026, 6, 11);
    final diff = kickoff.difference(now);
    final daysLeft = diff.isNegative ? 0 : diff.inDays;
    final isTournamentLive = diff.isNegative || daysLeft == 0;

    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=60',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C)],
                  ),
                ),
              ),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.5),
                    (isDark ? _kDarkBg : const Color(0xFFF7F2E8)).withValues(
                      alpha: 0.95,
                    ),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE7C16A), Color(0xFFD4A843)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_soccer_rounded,
                            color: Colors.black,
                            size: 12,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'UNITED 2026',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isTournamentLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 6),
                            SizedBox(width: 5),
                            Text(
                              'EN COURS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  'FIFA World Cup',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'USA · MEX · CAN',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black87).withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats row
                Row(
                  children: [
                    _HeroStat(
                      value: isTournamentLive ? 'LIVE' : 'J-$daysLeft',
                      label: isTournamentLive ? 'TOURNOI' : 'COUP D\'ENVOI',
                      highlight: true,
                    ),
                    const SizedBox(width: 20),
                    const _HeroStat(value: '48', label: 'NATIONS'),
                    const SizedBox(width: 20),
                    const _HeroStat(value: '104', label: 'MATCHS'),
                    const SizedBox(width: 20),
                    const _HeroStat(value: '16', label: 'STADES'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;
  const _HeroStat({
    required this.value,
    required this.label,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight ? _kGold : textColor,
            fontSize: highlight ? 20 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.45),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Filter chip for news team filtering
class _FilterChip2026 extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip2026({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? _kGold
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? _kGold : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kGold.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.black
                  : (isDark ? Colors.white70 : Colors.black54),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium news card with glassmorphism
class _NewsCard2026 extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _NewsCard2026({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (item['img'] != null)
                Image.network(
                  item['img'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B3A5C), Color(0xFF0D1B2A)],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B3A5C), Color(0xFF0D1B2A)],
                    ),
                  ),
                ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        item['source'] ?? 'FIFA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Title + date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          maxLines: 3,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 2,
                              decoration: BoxDecoration(
                                color: _kGold,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatNewsDate(item['date']),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  String _formatNewsDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

/// Live match card with pulsing border for in-progress matches
class _LiveMatchCard2026 extends StatefulWidget {
  final LiveMatch match;
  final Color textColor;
  const _LiveMatchCard2026({required this.match, required this.textColor});
  @override
  State<_LiveMatchCard2026> createState() => _LiveMatchCard2026State();
}

class _LiveMatchCard2026State extends State<_LiveMatchCard2026>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_pulseCtrl.value * 0.25);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.redAccent.withValues(
                alpha: 0.4 + _pulseCtrl.value * 0.3,
              ),
              width: 1.5,
            ),
            color: isDark ? _kCardDark : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: glowOpacity),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: m)),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Status row
                  Row(
                    children: [
                      const _LiveDot(),
                      const SizedBox(width: 6),
                      Text(
                        m.statusDisplay,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.phaseLabel,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Teams + Score
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                m.homeTeam,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            NationFlagBadge(
                              countryCode: m.homeCode,
                              size: 28,
                              imageUrlOverride: m.homeLogoUrl,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        alignment: Alignment.center,
                        child: Text(
                          '${m.scoreHome ?? 0} - ${m.scoreAway ?? 0}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            NationFlagBadge(
                              countryCode: m.awayCode,
                              size: 28,
                              imageUrlOverride: m.awayLogoUrl,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                m.awayTeam,
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kGold.withValues(alpha: 0.2),
                  _kGold.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _kGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
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

// Keep old _NewsCard for backward compat with _buildNewsHorizontalList

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2A39) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            group.groupName.toUpperCase(),
            style: const TextStyle(
              color: _kGold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 13,
            ),
          ),
          Divider(
            color: (isDark ? Colors.white : Colors.black87)
                .withValues(alpha: 0.10),
            height: 20,
          ),
          ...group.teams
              .take(4)
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${t.rank}',
                          style: TextStyle(
                            color: _kGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      NationFlagBadge(
                        countryCode: resolveCountryCode(t.teamName),
                        size: 20,
                        imageUrlOverride: t.teamLogo,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.teamName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${t.points} PTS',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
              Icon(
                Icons.info_outline_rounded,
                color: Colors.grey.withValues(alpha: 0.5),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchFilterBar extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  const _MatchFilterBar({required this.selected, required this.onSelect});
  static const _labels = ['Par Date', 'Par Équipe', 'Par Groupe'];
  static const _icons = [
    Icons.calendar_month_rounded,
    Icons.groups_rounded,
    Icons.group_rounded,
  ];
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2530) : const Color(0xFFE8DCC6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _kGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _icons[i],
                      size: 13,
                      color: isSelected
                          ? Colors.black87
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black87
                            : (isDark ? Colors.white60 : Colors.black54),
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CalendarBottomSheet extends StatelessWidget {
  final List<LiveMatch> matches;
  final String selectedDateLabel;
  final void Function(String) onDateSelected;
  final bool isDark;
  const _CalendarBottomSheet({
    required this.matches,
    required this.selectedDateLabel,
    required this.onDateSelected,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF23303C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final keysSet = <String>{};
    for (var m in matches) {
      keysSet.add(m.dateLabel);
    }
    final keys = keysSet.toList();
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CHOISIR DATE',
              style: TextStyle(color: _kGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: keys.map((k) {
                final isSel = k == selectedDateLabel;
                return ChoiceChip(
                  label: Text(k),
                  selected: isSel,
                  onSelected: (_) => onDateSelected(k),
                  selectedColor: _kGold,
                  backgroundColor: textColor.withValues(alpha: 0.05),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.black : textColor,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListBottomSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final String selectedItem;
  final void Function(int) onItemSelected;
  final bool isDark;
  const _ListBottomSheet({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.onItemSelected,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF23303C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final isSel = items[i] == selectedItem;
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(
                      items[i],
                      style: TextStyle(
                        color: isSel ? _kGold : textColor,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check, color: _kGold)
                        : null,
                    onTap: () => onItemSelected(i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
