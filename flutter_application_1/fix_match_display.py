import re

with open('lib/screens/match_details_screen.dart', 'r') as f:
    content = f.read()

helper = """
  String _getLiveTimeWithSeconds() {
    final status = widget.match.statusDisplay;
    if (widget.match.isLive && status.endsWith("'")) {
      final min = status.substring(0, status.length - 1);
      final sec = _currentSeconds.toString().padLeft(2, '0');
      return "$min:$sec";
    }
    return status;
  }
"""

content = content.replace("Widget build(BuildContext context) {", helper + "\n  @override\n  Widget build(BuildContext context) {")
content = content.replace("match.isLive ? 'EN DIRECT • ${match.statusDisplay}' : match.statusDisplay,", "match.isLive ? 'EN DIRECT • ${_getLiveTimeWithSeconds()}' : match.statusDisplay,")

with open('lib/screens/match_details_screen.dart', 'w') as f:
    f.write(content)
