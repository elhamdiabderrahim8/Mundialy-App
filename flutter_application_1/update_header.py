import re

with open('lib/widgets/competition_header.dart', 'r') as f:
    content = f.read()

# Replace the Container wrapping the CompetitionBadge using a simpler regex
content = re.sub(
    r'// Logo with subtle background\s+Container\([^;]+CompetitionBadge\(competition: comp, size: 24, iconSize: 14\),\s+\),',
    'CompetitionBadge(competition: comp, size: 28, iconSize: 16),',
    content,
    flags=re.DOTALL
)

with open('lib/widgets/competition_header.dart', 'w') as f:
    f.write(content)
