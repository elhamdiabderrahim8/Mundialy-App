import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Add import if missing
if "import '../widgets/competition_header.dart';" not in content:
    content = content.replace("import '../widgets/match_card.dart';", "import '../widgets/match_card.dart';\nimport '../widgets/competition_header.dart';")

# Replace calls to _CompetitionGroupHeader with CompetitionHeader
content = content.replace("_CompetitionGroupHeader(", "CompetitionHeader(")

# Remove the _CompetitionGroupHeader class definition entirely
content = re.sub(
    r'/// Header de groupe compétition.*?(?=class _CompetitionMatchList)',
    '',
    content,
    flags=re.DOTALL
)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
