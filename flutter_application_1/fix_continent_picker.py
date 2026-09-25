import re

with open('lib/widgets/continent_competition_picker.dart', 'r') as f:
    content = f.read()

# Change the hardcoded _gold to match the CompetitionBadge icon color
# colorFilter: const ColorFilter.mode(_gold, BlendMode.srcIn)
content = content.replace(
    "colorFilter: const ColorFilter.mode(\n                              _gold, BlendMode.srcIn),",
    "colorFilter: ColorFilter.mode(\n                              isDark ? _gold : const Color(0xFF16324A), BlendMode.srcIn),"
)

# Wait, the spacing might be different. Let's use re.sub
content = re.sub(
    r'colorFilter:\s*const\s*ColorFilter\.mode\(\s*_gold,\s*BlendMode\.srcIn\s*\)',
    'colorFilter: ColorFilter.mode(isDark ? _gold : const Color(0xFF16324A), BlendMode.srcIn)',
    content
)

with open('lib/widgets/continent_competition_picker.dart', 'w') as f:
    f.write(content)
