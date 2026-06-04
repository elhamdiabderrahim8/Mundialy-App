import 'dart:async' as java_timer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

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
  int _selectedYear = 2022; // Qatar 2022 by default
  int _matchFilterMode = 0; // 0=Par Date, 1=Par Équipe, 2=Par Groupe
  
  late PageController _pageController;
  java_timer.Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    ApiService.initNotifications();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE DE DONNÉES ---

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    _liveTimer?.cancel();
    setState(() => _isLoading = true);
    try {
      if (_selectedYear == -1) {
        await _fetchLiveMode();
        _liveTimer = java_timer.Timer.periodic(const Duration(seconds: 15), (_) => _fetchLiveMode());
      } else {
        await _fetchUnifiedData();
      }
    } catch (e) {
      debugPrint('💥 Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isFetchingLive = false;
  Future<void> _fetchLiveMode() async {
    if (_isFetchingLive) return;
    _isFetchingLive = true;
    try {
      final liveMatches = await ApiService.fetchLiveMatches();
      if (mounted) {
        setState(() { _matches = liveMatches; });
        
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
    } catch (e) { debugPrint('Live Fetch Error: $e'); }
    finally { _isFetchingLive = false; }
  }

  Future<void> _fetchUnifiedData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMatches(year: _selectedYear),
        ApiService.fetchStandings(year: _selectedYear),
        ApiService.fetchTopScorers(year: _selectedYear),
        ApiService.fetchNews(),
      ]);
      _matches = (results[0] as List?)?.cast<LiveMatch>() ?? [];
      _standings = (results[1] as List?)?.cast<GroupStanding>() ?? [];
      _topScorers = (results[2] as List?)?.cast<TopScorer>() ?? [];
      _newsArticles = (results[3] as List?)?.cast<dynamic>() ?? [];
      if (_matches.isEmpty && _selectedYear == 2022) _matches = getMockMatches();
    } catch (e) { debugPrint('💥 Error fetching unified data: $e'); }
  }

  // --- NAVIGATION ---
  void _onTabTap(int index) {
    if (index > 2) { setState(() => _selectedTab = index); return; }
    if (_selectedTab == index) { _showFilterBottomSheet(_selectedTab == 2 ? _matchFilterMode : 0); return; }
    setState(() { _selectedTab = index; });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

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
            Positioned(top: -40, left: -20, child: _AmbientGlow(color: _kGold.withValues(alpha: 0.1), size: 180)),
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
    if (_selectedTab == 0 && _selectedYear == 2026) return _buildModernHome2026(textColor);
    switch (_selectedTab) {
      case 0: return _buildPagedMatchView(textColor);
      case 1: return _buildPagedMatchView(textColor); // Live View
      case 2: return _buildCalendrierView(textColor);
      case 3: return _buildStandingsView(textColor);
      case 4: return _buildTopScorersView(textColor);
      case 5: return _buildBracketView(textColor);
      default: return _buildPagedMatchView(textColor);
    }
  }

  Widget _buildCalendrierView(Color textColor) {
    return Column(children: [
        _MatchFilterBar(selected: _matchFilterMode, onSelect: (i) { if (_matchFilterMode != i) { setState(() { _matchFilterMode = i; }); if (_pageController.hasClients) _pageController.jumpToPage(0); } else { _showFilterBottomSheet(i); } }),
        Expanded(child: _buildPagedMatchView(textColor)),
    ]);
  }

  Widget _buildModernHome2026(Color textColor) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const _TournamentHero(),
        const SizedBox(height: 24),
        if (_standings.isNotEmpty) ...[
          _SectionHeader(icon: Icons.leaderboard_rounded, title: 'GROUPES OFFICIELS', subtitle: 'Données en direct SofaScore', textColor: textColor),
          const SizedBox(height: 12),
          _GroupsAutoCarousel(groups: _standings, textColor: textColor),
          const SizedBox(height: 24),
        ],
        _SectionHeader(icon: Icons.rss_feed_rounded, title: 'ACTUALITÉS MONDIAL 2026', subtitle: 'Les dernières infos SofaScore', textColor: textColor),
        const SizedBox(height: 12),
        _buildNewsHorizontalList(),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.star_border_rounded, title: 'MATCHS À VENIR', subtitle: 'Calendrier officiel du tournoi', textColor: textColor),
        const SizedBox(height: 12),
        ..._buildUpcomingMatches(textColor),
      ],
    );
  }

  Widget _buildNewsHorizontalList() {
    if (_newsArticles.isEmpty) return const SizedBox(height: 280, child: _EmptyState(msg: 'Aucune actualité disponible.'));
    return SizedBox(height: 280, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _newsArticles.length, itemBuilder: (context, i) => _NewsCard(item: _newsArticles[i], onTap: () => _openUrl(_newsArticles[i]['url']))));
  }

  List<Widget> _buildUpcomingMatches(Color textColor) {
    if (_matches.isEmpty) return const [SizedBox(height: 150, child: _EmptyState(msg: 'Aucun match programmé.'))];
    return _matches.take(5).map((m) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: _MatchCard(match: m, year: _selectedYear, textColor: textColor))).toList();
  }

  Widget _buildPagedMatchView(Color textColor) {
    final List<String> Function(LiveMatch) keysOf;
    if (_selectedTab == 2) {
      switch (_matchFilterMode) {
        case 1: keysOf = (m) => [m.homeTeam, m.awayTeam]; break; // Group by Team
        case 2: keysOf = (m) {
          final s = _standings.firstWhere((st) => st.teams.any((t) => t.teamName == m.homeTeam), orElse: () => GroupStanding(groupName: 'Autre', teams: []));
          return [s.groupName];
        }; break;
        default: keysOf = (m) => [m.dateLabel];
      }
    } else { keysOf = (m) => [m.dateLabel]; }
    final grouped = <String, List<LiveMatch>>{};
    for (final m in _matches) { for (final key in keysOf(m)) { grouped.putIfAbsent(key, () => []).add(m); } }
    final keys = grouped.keys.toList();
    if (_selectedTab == 2 && (_matchFilterMode == 1 || _matchFilterMode == 2)) { keys.sort(); }
    else { keys.sort((a, b) { final mA = grouped[a]!.first.dateTime; final mB = grouped[b]!.first.dateTime; if (mA == null || mB == null) return 0; return mA.compareTo(mB); }); }
    if (keys.isEmpty) return const _EmptyState(msg: 'Aucun match disponible.');
    return PageView.builder(
      controller: _pageController, itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index]; final matches = grouped[key] ?? [];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), itemCount: matches.length + 1,
          itemBuilder: (context, mIndex) {
            if (mIndex == 0) {
              return Padding(padding: const EdgeInsets.only(top: 20, bottom: 16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (index > 0) GestureDetector(onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_back_ios_new_rounded, color: _kGold, size: 16))),
                    Flexible(child: Text(key.toUpperCase(), style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                    if (index < keys.length - 1) GestureDetector(onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_ios_rounded, color: _kGold, size: 16))),
              ]));
            }
            return _MatchCard(match: matches[mIndex - 1], year: _selectedYear, textColor: textColor);
          },
        );
      },
    );
  }

  Widget _buildStandingsView(Color textColor) {
    if (_standings.isEmpty) return const _EmptyState(msg: 'Aucun classement disponible.');
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: _standings.length, itemBuilder: (context, i) => _GroupTable(group: _standings[i], textColor: textColor, year: _selectedYear));
  }

  Widget _buildTopScorersView(Color textColor) {
    if (_topScorers.isEmpty) return const _EmptyState(msg: 'Aucun buteur disponible.');
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), itemCount: _topScorers.length, itemBuilder: (context, i) => ListTile(leading: CircleAvatar(backgroundImage: NetworkImage(_topScorers[i].playerPhoto)), title: Text(_topScorers[i].playerName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), trailing: Text('${_topScorers[i].goals} G', style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold))));
  }

  Widget _buildBracketView(Color textColor) {
    final rounds = _buildKnockoutRounds(_matches);
    if (rounds.isEmpty) return const _EmptyState(msg: 'Phase finale non disponible.');
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('PHASE FINALE',
            style: TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3)),
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
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                          color: _kGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _kGold.withValues(alpha: 0.3))),
                      child: Text(round.$1.toUpperCase(),
                          style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: ListView.builder(
                        itemCount: round.$2.length,
                        itemBuilder: (context, mIdx) => _BracketMatchCard(
                            match: round.$2[mIdx], year: _selectedYear, textColor: textColor),
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

  List<(String, List<LiveMatch>)> _buildKnockoutRounds(List<LiveMatch> matches) {
    final buckets = <String, List<LiveMatch>>{};
    for (final m in matches) { final round = _normalizeRound(m.phaseLabel); if (round != null) buckets.putIfAbsent(round, () => []).add(m); }
    const order = ['Round of 16', 'Quarter-finals', 'Semi-finals', 'Third place', 'Final'];
    return order.where(buckets.containsKey).map((k) => (k, buckets[k]!)).toList();
  }

  String? _normalizeRound(String raw) {
    final v = raw.toLowerCase().replaceAll('_', ' ');
    if (v.contains('round of 16') || v.contains('8th finals') || v.contains('huitième')) return 'Round of 16';
    if (v.contains('quarter') || v.contains('quart')) return 'Quarter-finals';
    if (v.contains('semi') || v.contains('demi')) return 'Semi-finals';
    if (v.contains('third place') || v.contains('troisième')) return 'Third place';
    if (v == 'final' || (v.contains('final') && !v.contains('semi') && !v.contains('quarter'))) return 'Final';
    return null;
  }

  Widget _buildCollapsingHeader() {
    return SliverAppBar(
      pinned: true, backgroundColor: isDark ? _kCardDark : const Color(0xFFF2E5CA), expandedHeight: 250, centerTitle: true,
      title: Text(_selectedYear == -1 ? 'Live Action' : 'Mondial $_selectedYear', style: const TextStyle(fontWeight: FontWeight.bold)),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
            Image.network('https://images.unsplash.com/photo-1517927033932-b3d18e61fb3a?auto=format&fit=crop&w=800&q=60', fit: BoxFit.cover),
            Container(color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.25)),
            Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _YearDropdownSelector(selectedYear: _selectedYear, onYearChanged: (y) { if (_selectedYear != y) { setState(() { _selectedYear = y; if (y == -1) _selectedTab = 1; }); _loadInitialData(); } }),
                    const SizedBox(height: 10),
                    Text('FIFA WORLD CUP', style: TextStyle(color: isDark ? _kGold : Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: isDark ? null : [const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))])),
            ])))),
        ]),
      ),
      actions: [Container(margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8), decoration: BoxDecoration(color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: _kGold.withValues(alpha: isDark ? 0.5 : 0.8))), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () { final themeProv = Provider.of<ThemeProvider>(context, listen: false); themeProv.toggleTheme(isDark ? ThemeMode.light : ThemeMode.dark); }, icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? _kGold : Colors.black87, size: 20), constraints: const BoxConstraints(minWidth: 40, minHeight: 40), padding: EdgeInsets.zero), Container(width: 1, height: 20, color: _kGold.withValues(alpha: isDark ? 0.3 : 0.8)), IconButton(onPressed: _loadInitialData, icon: Icon(Icons.refresh_rounded, color: isDark ? _kGold : Colors.black87, size: 20), constraints: const BoxConstraints(minWidth: 40, minHeight: 40), padding: EdgeInsets.zero)]))],
    );
  }

  Widget _buildBottomNav() { return BottomNavigationBar(backgroundColor: isDark ? const Color(0xFF1A242D) : Colors.white, selectedItemColor: _kGold, unselectedItemColor: Colors.grey, currentIndex: _selectedTab, onTap: _onTabTap, type: BottomNavigationBarType.fixed, items: const [BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'), BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Live'), BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Matchs'), BottomNavigationBarItem(icon: Icon(Icons.format_list_numbered), label: 'Groupes'), BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Buteurs'), BottomNavigationBarItem(icon: Icon(Icons.account_tree_outlined), label: 'Bracket')]); }

  void _showFilterBottomSheet(int mode) {
    if (mode == 0) {
      final currentKeyIndex = _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;
      final keys = groupedKeys((m) => [m.dateLabel]);
      final selectedDateLabel = keys.isNotEmpty && currentKeyIndex < keys.length ? keys[currentKeyIndex] : '';
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _CalendarBottomSheet(matches: _matches, selectedDateLabel: selectedDateLabel, isDark: isDark, onDateSelected: (dateLabel) { final idx = keys.indexOf(dateLabel); if (idx != -1) { _pageController.jumpToPage(idx); Navigator.pop(context); } }));
    } else {
      final keysOf = mode == 1 ? (LiveMatch m) => [m.homeTeam, m.awayTeam] : (LiveMatch m) {
        final s = _standings.firstWhere((st) => st.teams.any((t) => t.teamName == m.homeTeam), orElse: () => GroupStanding(groupName: 'Autre', teams: []));
        return [s.groupName];
      };
      final keys = groupedKeys(keysOf);
      final currentKeyIndex = _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;
      final selectedItem = keys.isNotEmpty && currentKeyIndex < keys.length ? keys[currentKeyIndex] : '';
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _ListBottomSheet(title: mode == 1 ? 'CHOISIR ÉQUIPE' : 'CHOISIR GROUPE', items: keys, selectedItem: selectedItem, isDark: isDark, onItemSelected: (idx) { _pageController.jumpToPage(idx); Navigator.pop(context); }));
    }
  }

  List<String> groupedKeys(List<String> Function(LiveMatch) keysOf) {
    final keysSet = <String>{};
    for (final m in _matches) { keysSet.addAll(keysOf(m)); }
    final keys = keysSet.toList();
    if (_selectedTab == 2 && (_matchFilterMode == 1 || _matchFilterMode == 2)) keys.sort();
    return keys;
  }

  Future<void> _openUrl(String? url) async { if (url == null || url.isEmpty) return; final uri = Uri.tryParse(url); if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }
}

class _YearDropdownSelector extends StatefulWidget {
  final int selectedYear; final void Function(int) onYearChanged;
  const _YearDropdownSelector({required this.selectedYear, required this.onYearChanged});
  @override
  State<_YearDropdownSelector> createState() => _YearDropdownSelectorState();
}
class _YearDropdownSelectorState extends State<_YearDropdownSelector> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor = isDark ? const Color(0xFF1E2630) : Colors.white;
    final Color accentColor = _kGold;
    return Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(onTap: () => setState(() => _open = !_open), child: Container(constraints: const BoxConstraints(maxWidth: 260), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: panelColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.5), boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 1)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(widget.selectedYear == -1 ? Icons.bolt_rounded : Icons.emoji_events_rounded, color: widget.selectedYear == -1 ? Colors.redAccent : accentColor, size: 18), const SizedBox(width: 8), Flexible(child: Text(widget.selectedYear == -1 ? 'LIVE ACTION' : 'ÉDITION ${widget.selectedYear}', style: TextStyle(color: widget.selectedYear == -1 ? Colors.redAccent : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 250), child: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor, size: 20))]))),
        AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.elasticOut, child: _open ? Container(margin: const EdgeInsets.only(top: 10), width: 220, decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: accentColor.withValues(alpha: 0.4)), boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))]), child: Column(mainAxisSize: MainAxisSize.min, children: [-1, 2022, 2026].map((y) {
                final isSel = widget.selectedYear == y; final label = y == -1 ? 'LIVE EN DIRECT' : 'Coupe du Monde $y';
                return InkWell(onTap: () { setState(() => _open = false); widget.onYearChanged(y); }, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), decoration: BoxDecoration(color: isSel ? accentColor.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(y == -1 ? Icons.bolt_rounded : (isSel ? Icons.check_circle_rounded : Icons.circle_outlined), color: y == -1 ? Colors.redAccent : (isSel ? accentColor : Colors.grey), size: 16), const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(color: y == -1 ? Colors.redAccent : (isSel ? accentColor : (isDark ? Colors.white70 : Colors.black87)), fontWeight: FontWeight.w900, fontSize: 13), overflow: TextOverflow.ellipsis))])));
        }).toList())) : const SizedBox.shrink())
    ]);
  }
}

class _MatchCard extends StatelessWidget {
  final LiveMatch match; final int year; final Color textColor;
  const _MatchCard({required this.match, required this.year, required this.textColor});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(elevation: 0, color: isDark ? _kCardDark : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))), child: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: match))), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [Text(match.localTime, style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis), if (match.isLive) ...[const SizedBox(width: 8), const _LiveDot()]])),
                    const SizedBox(width: 8),
                    if (match.isLive) GestureDetector(onTap: () => _pinMatch(context, match), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.push_pin_rounded, color: _kGold, size: 12), SizedBox(width: 4), Text('ÉPINGLER', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 9))])))
                    else Flexible(flex: 2, child: Text(match.phaseLabel, style: const TextStyle(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right))
                ]),
                const SizedBox(height: 16),
                Row(children: [Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: Text(match.homeTeam, textAlign: TextAlign.right, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), NationFlagBadge(countryCode: match.homeCode, size: 24, imageUrlOverride: match.homeLogoUrl)])), Container(width: 70, alignment: Alignment.center, child: Text(match.scoreHome != null ? '${match.scoreHome} - ${match.scoreAway}' : 'VS', style: const TextStyle(color: _kGold, fontSize: 20, fontWeight: FontWeight.w900))), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [NationFlagBadge(countryCode: match.awayCode, size: 24, imageUrlOverride: match.awayLogoUrl), const SizedBox(width: 8), Flexible(child: Text(match.awayTeam, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis))]))])
    ]))));
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
      'score': '${match.scoreHome ?? 0} - ${match.scoreAway ?? 0}',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Match ${match.homeTeam} épinglé sur l\'écran d\'accueil !'), backgroundColor: _kGold),
      );
    }
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}
class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return FadeTransition(opacity: _ctrl, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))); }
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({required this.match, required this.year, required this.textColor});
  final LiveMatch match; final int year; final Color textColor;
  @override
  Widget build(BuildContext context) { return Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: textColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(22), border: Border.all(color: textColor.withValues(alpha: 0.08)), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('${match.dateLabel} • ${match.localTime}', style: const TextStyle(color: _kGold, fontSize: 12, fontWeight: FontWeight.bold)), const Spacer(), Icon(Icons.bar_chart, color: textColor.withValues(alpha: 0.38), size: 16)]), const SizedBox(height: 14), _BracketTeamRow(name: match.homeTeam, code: match.homeCode, teamId: match.homeTeamId, year: year, score: match.scoreHome, penalty: match.penaltyHome, isWinner: match.scoreHome != null && match.scoreAway != null && (match.scoreHome! > match.scoreAway! || (match.penaltyHome ?? 0) > (match.penaltyAway ?? 0)), textColor: textColor, logo: match.homeLogoUrl), const SizedBox(height: 10), _BracketTeamRow(name: match.awayTeam, code: match.awayCode, teamId: match.awayTeamId, year: year, score: match.scoreAway, penalty: match.penaltyAway, isWinner: match.scoreHome != null && match.scoreAway != null && (match.scoreAway! > match.scoreHome! || (match.penaltyAway ?? 0) > (match.penaltyHome ?? 0)), textColor: textColor, logo: match.awayLogoUrl), const SizedBox(height: 12), Text(match.city, style: TextStyle(color: textColor.withValues(alpha: 0.54), fontSize: 11, fontStyle: FontStyle.italic))])); }
}

class _BracketTeamRow extends StatelessWidget {
  const _BracketTeamRow({required this.name, required this.code, required this.teamId, required this.year, required this.score, this.penalty, required this.isWinner, required this.textColor, this.logo});
  final String name; final String code; final int? teamId; final int year; final int? score; final int? penalty; final bool isWinner; final Color textColor; final String? logo;
  @override
  Widget build(BuildContext context) { final color = isWinner ? _kGold : textColor; return Row(children: [NationFlagBadge(countryCode: code, size: 28, imageUrlOverride: logo), const SizedBox(width: 12), Expanded(child: Text(name, style: TextStyle(color: color, fontWeight: isWinner ? FontWeight.w900 : FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)), if (penalty != null) Text('($penalty)', style: TextStyle(color: isWinner ? _kGold.withValues(alpha: 0.8) : textColor.withValues(alpha: 0.38), fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(width: 6), Text(score?.toString() ?? '-', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900))]); }
}

class _GroupTable extends StatelessWidget {
  final GroupStanding group; final Color textColor; final int year;
  const _GroupTable({required this.group, required this.textColor, required this.year});
  @override
  Widget build(BuildContext context) { return Container(margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: textColor.withValues(alpha: 0.1))), child: Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Center(child: Text(group.groupName.toUpperCase(), style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, letterSpacing: 2)))), Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [Expanded(flex: 1, child: Text('Pos', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold))), Expanded(flex: 4, child: Text('Équipe', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold))), Expanded(child: Text('MJ', textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold))), Expanded(child: Text('GD', textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold))), Expanded(child: Text('PTS', textAlign: TextAlign.center, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold)))]), const Divider(color: Colors.white10, height: 20), ...group.teams.map((t) { final isQualif = t.rank <= 2; return InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamProfileScreen(teamId: t.teamId, teamName: t.teamName, year: year))), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(border: Border(left: BorderSide(color: isQualif ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5), width: 3))), child: Row(children: [Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text('${t.rank}', style: TextStyle(color: isQualif ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900)))), Expanded(flex: 4, child: Row(children: [NationFlagBadge(countryCode: resolveCountryCode(t.teamName), size: 24, imageUrlOverride: t.teamLogo), const SizedBox(width: 10), Expanded(child: Text(t.teamName, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis))])), Expanded(child: Text('${t.played}', textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 12))), Expanded(child: Text('${t.goalsDiff}', textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 12))), Expanded(child: Text('${t.points}', textAlign: TextAlign.center, style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 14)))]))); }), const SizedBox(height: 16), Row(children: [_buildLegendItem(Colors.greenAccent, 'Qualifié'), const SizedBox(width: 16), _buildLegendItem(Colors.redAccent, 'Éliminé')])]))])); }
  Widget _buildLegendItem(Color color, String label) { return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))]); }
}

class _TournamentHero extends StatelessWidget {
  const _TournamentHero();
  @override
  Widget build(BuildContext context) { return SizedBox(height: 360, width: double.infinity, child: Stack(children: [Positioned.fill(child: Image.network('https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=800&q=60', fit: BoxFit.cover)), Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.9)])))), Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(6)), child: const Text('UNITED 2026', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900))), const SizedBox(height: 12), const Text('FIFA World Cup', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1), overflow: TextOverflow.ellipsis, maxLines: 1), const SizedBox(height: 16), const Wrap(spacing: 8, runSpacing: 8, children: [_HeroChip(icon: Icons.calendar_month_rounded, label: 'Calendrier'), _HeroChip(icon: Icons.stadium_rounded, label: 'Stades'), _HeroChip(icon: Icons.public_rounded, label: 'Nations')])])), const Positioned(top: 60, right: 20, child: _CountdownBadge())])); }
}
class _HeroChip extends StatelessWidget {
  final IconData icon; final String label; const _HeroChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))])); }
}
class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge();
  @override
  Widget build(BuildContext context) { return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16), border: Border.all(color: _kGold.withValues(alpha: 0.5))), child: const Column(mainAxisSize: MainAxisSize.min, children: [Text('J-748', style: TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 18)), Text('AVANT DÉPART', style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold))])); }
}
class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Color textColor; const _SectionHeader({required this.icon, required this.title, required this.subtitle, required this.textColor});
  @override
  Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _kGold, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5), overflow: TextOverflow.ellipsis), Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11), overflow: TextOverflow.ellipsis)]))])); }
}
class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item; final VoidCallback onTap; const _NewsCard({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) { return Container(width: 280, margin: const EdgeInsets.only(right: 14), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Stack(fit: StackFit.expand, children: [if (item['img'] != null) Image.network(item['img'], fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[900])), Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)]))), Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(6)), child: Text(item['source'] ?? 'News', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), const SizedBox(height: 8), Text(item['title'] ?? '', maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2), overflow: TextOverflow.ellipsis)]))])))); }
}
class _GroupsAutoCarousel extends StatefulWidget {
  final List<GroupStanding> groups; final Color textColor; const _GroupsAutoCarousel({required this.groups, required this.textColor});
  @override
  State<_GroupsAutoCarousel> createState() => _GroupsAutoCarouselState();
}
class _GroupsAutoCarouselState extends State<_GroupsAutoCarousel> {
  late PageController _controller; int _currentIndex = 0; late java_timer.Timer _timer;
  @override
  void initState() { super.initState(); _controller = PageController(viewportFraction: 0.9); _timer = java_timer.Timer.periodic(const Duration(seconds: 5), (_) { if (_currentIndex < widget.groups.length - 1) { _currentIndex++; } else { _currentIndex = 0; } if (_controller.hasClients) { _controller.animateToPage(_currentIndex, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic); } }); }
  @override
  void dispose() { _timer.cancel(); _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return SizedBox(height: 240, child: Column(children: [Expanded(child: PageView.builder(controller: _controller, itemCount: widget.groups.length, onPageChanged: (i) => setState(() => _currentIndex = i), itemBuilder: (context, i) => _GroupCard(group: widget.groups[i]))), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(widget.groups.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == _currentIndex ? 18 : 6, height: 6, decoration: BoxDecoration(color: i == _currentIndex ? _kGold : Colors.white24, borderRadius: BorderRadius.circular(10)))))])); }
}
class _GroupCard extends StatelessWidget {
  final GroupStanding group; const _GroupCard({required this.group});
  @override
  Widget build(BuildContext context) { return Container(margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1B2A39), borderRadius: BorderRadius.circular(20), border: Border.all(color: _kGold.withValues(alpha: 0.2))), child: Column(children: [Text(group.groupName.toUpperCase(), style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)), const Divider(color: Colors.white10, height: 20), ...group.teams.take(4).map((t) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 20, child: Text('${t.rank}', style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 12))), NationFlagBadge(countryCode: resolveCountryCode(t.teamName), size: 20, imageUrlOverride: t.teamLogo), const SizedBox(width: 12), Expanded(child: Text(t.teamName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)), Text('${t.points} PTS', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))])))])); }
}
class _AmbientGlow extends StatelessWidget {
  final Color color; final double size; const _AmbientGlow({required this.color, required this.size});
  @override
  Widget build(BuildContext context) { return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]))); }
}
class _EmptyState extends StatelessWidget {
  final String msg; const _EmptyState({required this.msg});
  @override
  Widget build(BuildContext context) { return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [Icon(Icons.info_outline_rounded, color: Colors.grey.withValues(alpha: 0.5), size: 48), const SizedBox(height: 16), Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 16))])))); }
}
class _MatchFilterBar extends StatelessWidget {
  final int selected; final void Function(int) onSelect; const _MatchFilterBar({required this.selected, required this.onSelect});
  static const _labels = ['Par Date', 'Par Équipe', 'Par Groupe']; static const _icons = [Icons.calendar_month_rounded, Icons.groups_rounded, Icons.group_rounded];
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.fromLTRB(16, 14, 16, 6), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: isDark ? const Color(0xFF1A2530) : const Color(0xFFE8DCC6), borderRadius: BorderRadius.circular(18), border: Border.all(color: _kGold.withValues(alpha: 0.25)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]), child: Row(children: List.generate(_labels.length, (i) { final isSelected = selected == i; return Expanded(child: GestureDetector(onTap: () => onSelect(i), child: AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeInOut, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSelected ? _kGold : Colors.transparent, borderRadius: BorderRadius.circular(14), boxShadow: isSelected ? [BoxShadow(color: _kGold.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : []), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_icons[i], size: 13, color: isSelected ? Colors.black87 : (isDark ? Colors.white60 : Colors.black54)), const SizedBox(width: 5), Text(_labels[i], style: TextStyle(color: isSelected ? Colors.black87 : (isDark ? Colors.white60 : Colors.black54), fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, fontSize: 12, letterSpacing: 0.3))])))); })));
  }
}
class _CalendarBottomSheet extends StatelessWidget {
  final List<LiveMatch> matches; final String selectedDateLabel; final void Function(String) onDateSelected; final bool isDark; const _CalendarBottomSheet({required this.matches, required this.selectedDateLabel, required this.onDateSelected, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF23303C) : Colors.white; final textColor = isDark ? Colors.white : Colors.black87; final keysSet = <String>{}; for (var m in matches) { keysSet.add(m.dateLabel); } final keys = keysSet.toList();
    return Container(decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))), padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16), const Text('CHOISIR DATE', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Wrap(spacing: 10, runSpacing: 10, children: keys.map((k) { final isSel = k == selectedDateLabel; return ChoiceChip(label: Text(k), selected: isSel, onSelected: (_) => onDateSelected(k), selectedColor: _kGold, backgroundColor: textColor.withValues(alpha: 0.05), labelStyle: TextStyle(color: isSel ? Colors.black : textColor)); }).toList())])));
  }
}
class _ListBottomSheet extends StatelessWidget {
  final String title; final List<String> items; final String selectedItem; final void Function(int) onItemSelected; final bool isDark; const _ListBottomSheet({required this.title, required this.items, required this.selectedItem, required this.onItemSelected, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF23303C) : Colors.white; final textColor = isDark ? Colors.white : Colors.black87;
    return Container(decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))), padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))), const SizedBox(height: 16), Text(title, style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (context, i) { final isSel = items[i] == selectedItem; return ListTile(title: Text(items[i], style: TextStyle(color: isSel ? _kGold : textColor, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)), trailing: isSel ? const Icon(Icons.check, color: _kGold) : null, onTap: () => onItemSelected(i)); }))] ));
  }
}
