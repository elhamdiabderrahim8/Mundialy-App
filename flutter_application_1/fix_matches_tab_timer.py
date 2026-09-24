import re

with open('lib/screens/matches_tab.dart', 'r') as f:
    content = f.read()

repl = """
      if (mounted) {
        setState(() {
          // Merge updates silently
          for (final newMatch in results) {
            final index = _allMatches.indexWhere((m) => m.id == newMatch.id);
            if (index != -1) {
              _allMatches[index] = newMatch;
            } else {
              _allMatches.add(newMatch);
            }
          }
        });
      }
      
      // Update Pinned Match Overlay if active
      ApiService.updatePinnedMatch(results);
    } catch (_) {}
"""

content = re.sub(r'      if \(mounted\) \{\n        setState\(\(\) \{\n          // Merge updates silently[\s\S]*?\n        \}\);\n      \}\n    \} catch \(\_\) \{\}', repl, content)

with open('lib/screens/matches_tab.dart', 'w') as f:
    f.write(content)
