import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Add import if missing
if "import '../widgets/competition_header.dart';" not in content:
    content = content.replace("import '../widgets/match_card.dart';", "import '../widgets/match_card.dart';\nimport '../widgets/competition_header.dart';")

# Replace calls to _CompetitionGroupHeader with CompetitionHeader
content = content.replace("_CompetitionGroupHeader(", "CompetitionHeader(")

# Remove the _CompetitionGroupHeader class definition
content = re.sub(
    r'class _CompetitionGroupHeader extends StatelessWidget \{.*?\n\}\n',
    '',
    content,
    flags=re.DOTALL
)

# Remove the huge commented out block for the old match card
content = re.sub(
    r'/\* ── Code déplacé dans widgets/match_card\.dart.*?// ── Fin du bloc déplacé vers widgets/match_card\.dart ── \*/\n?',
    '',
    content,
    flags=re.DOTALL
)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
