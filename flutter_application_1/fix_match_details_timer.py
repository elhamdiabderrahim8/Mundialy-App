import re

with open('lib/screens/match_details_screen.dart', 'r') as f:
    content = f.read()

# Add import 'dart:async';
if 'dart:async' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:async';")

# Add state variables
state_vars = """  MatchDetails? _details;
  bool _isLoading = true;
  int _selectedView = 0;
  int _selectedTeamIndex = 0;
  
  Timer? _pollTimer;
  Timer? _secondsTimer;
  int _currentSeconds = 0;"""

content = re.sub(
    r'  MatchDetails\? _details;.*?(?=  final GlobalKey _headerKey)',
    state_vars + '\n\n',
    content,
    flags=re.DOTALL
)

# Add timer logic to initState
init_state_logic = """  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
    
    if (widget.match.isLive) {
      _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _loadMatchDetails(silent: true);
      });
      _secondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _currentSeconds = (_currentSeconds + 1) % 60;
          });
        }
      });
    }"""

content = re.sub(
    r'  @override\n  void initState\(\) \{\n    super\.initState\(\);\n    _loadMatchDetails\(\);',
    init_state_logic,
    content
)

# Replace _loadMatchDetails to accept silent parameter
load_match_logic = """  Future<void> _loadMatchDetails({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final details = await ApiService.fetchMatchDetails(widget.match);

      if (!mounted) return;
      setState(() {
        _details = details ?? getMockMatchDetails(widget.match);
        if (!silent) _isLoading = false;
        
        if (!widget.match.isLive) {
          _pollTimer?.cancel();
          _secondsTimer?.cancel();
        }
      });
    } catch (e) {
      debugPrint('💥 Erreur chargement détails : $e');
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _secondsTimer?.cancel();
    super.dispose();
  }
  
  String _getLiveTimeWithSeconds() {
    final status = widget.match.statusDisplay;
    if (widget.match.isLive && status.endsWith("'")) {
      final min = status.substring(0, status.length - 1);
      final sec = _currentSeconds.toString().padLeft(2, '0');
      return "$min:$sec";
    }
    return status;
  }"""

content = re.sub(
    r'  Future<void> _loadMatchDetails\(\) async \{.*?(?=  Future<void> _pinMatch)',
    load_match_logic + '\n\n',
    content,
    flags=re.DOTALL
)

# Only replace the specific Text widget string
content = content.replace(
    "match.isLive ? 'EN DIRECT • ${match.statusDisplay}' : match.statusDisplay,",
    "match.isLive ? 'EN DIRECT • ${_getLiveTimeWithSeconds()}' : match.statusDisplay,"
)

with open('lib/screens/match_details_screen.dart', 'w') as f:
    f.write(content)
