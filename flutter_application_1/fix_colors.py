import re

with open('lib/widgets/competition_badge.dart', 'r') as f:
    content = f.read()

# Make the Icon fallback always use gold
content = content.replace(
    "color: isDark ? gold : const Color(0xFF16324A),",
    "color: gold,"
)

# Make the _LogoImage fallback icon always use CompetitionBadge.gold
content = content.replace(
    "color: isDark\n          ? CompetitionBadge.gold\n          : const Color(0xFF16324A),",
    "color: CompetitionBadge.gold,"
)

# Make the SvgPicture color filter always use CompetitionBadge.gold
content = content.replace(
    "colorFilter: ColorFilter.mode(\n          isDark ? CompetitionBadge.gold : const Color(0xFF16324A),\n          BlendMode.srcIn,\n        ),",
    "colorFilter: const ColorFilter.mode(\n          CompetitionBadge.gold,\n          BlendMode.srcIn,\n        ),"
)

with open('lib/widgets/competition_badge.dart', 'w') as f:
    f.write(content)

with open('lib/widgets/continent_competition_picker.dart', 'r') as f:
    content = f.read()

# Make the continent map always use _gold
content = re.sub(
    r'colorFilter:\s*ColorFilter\.mode\(\s*isDark\s*\?\s*_gold\s*:\s*const Color\(0xFF16324A\),\s*BlendMode\.srcIn\),',
    'colorFilter: const ColorFilter.mode(_gold, BlendMode.srcIn),',
    content
)

with open('lib/widgets/continent_competition_picker.dart', 'w') as f:
    f.write(content)
