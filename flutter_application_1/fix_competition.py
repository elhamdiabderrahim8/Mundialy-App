import re

with open('lib/screens/competition_detail_screen.dart', 'r') as f:
    content = f.read()

# Add import 'dart:async'
if 'dart:async' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:async';")

# Add timer
state_vars = """
  Timer? _liveTimer;
"""
content = re.sub(
    r'  bool _loadingMatches = true;.*?  bool _loadingScorers = true;',
    r'  bool _loadingMatches = true;\n  bool _loadingScorers = true;\n  Timer? _liveTimer;',
    content,
    flags=re.DOTALL
)

# initState & dispose
init_state_logic = """  @override
  void initState() {
    super.initState();
    _loadAll();
    _liveTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) _loadMatches(silent: true);
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }"""

content = re.sub(
    r'  @override\n  void initState\(\) \{\n    super\.initState\(\);\n    _loadAll\(\);\n  \}',
    init_state_logic,
    content
)

# _loadMatches
load_matches_logic = """  Future<void> _loadMatches({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingMatches = true;
        _error = null;
      });
    }
    try {
      final matches = await Scores365Service.fetchAllMatchesForCompetition(
        competitionId: widget.competitionId,
        competitionName: _competition?.name ?? widget.overrideName,
      );
      if (mounted) {
        setState(() {
          _matches = matches;
          // Sort logic: LIVE matches first, then unplayed matches nearest to today, then finished matches nearest to today.
          _matches.sort((a, b) {
            if (a.isLive && !b.isLive) return -1;
            if (!a.isLive && b.isLive) return 1;
            
            // Si les deux sont à venir
            if (!a.isFinished && !b.isFinished) {
              return (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0));
            }
            
            // Si les deux sont terminés
            if (a.isFinished && b.isFinished) {
              return (b.dateTime ?? DateTime(0)).compareTo(a.dateTime ?? DateTime(0));
            }
            
            // Un terminé, l'autre à venir -> Le terminé en bas
            if (a.isFinished && !b.isFinished) return 1;
            if (!a.isFinished && b.isFinished) return -1;
            
            return 0;
          });
          if (!silent) _loadingMatches = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loadingMatches = false;
        });
      }
    }
  }"""

content = re.sub(
    r'  Future<void> _loadMatches\(\) async \{.*?(?=  Future<void> _loadStandings)',
    load_matches_logic + '\n\n',
    content,
    flags=re.DOTALL
)

with open('lib/screens/competition_detail_screen.dart', 'w') as f:
    f.write(content)
