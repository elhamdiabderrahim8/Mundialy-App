import re

with open('lib/screens/matches_tab.dart', 'r') as f:
    content = f.read()

missing = """
  void _onScroll() {
    if (!mounted) return;
    final show = _scrollController.hasClients && _scrollController.offset > 120;
    if (show != _showTodayFab) {
      setState(() => _showTodayFab = show);
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMatches() async {"""

content = content.replace("  Future<void> _loadAllMatches() async {", missing)

with open('lib/screens/matches_tab.dart', 'w') as f:
    f.write(content)
