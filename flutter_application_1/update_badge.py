import re

with open('lib/widgets/competition_badge.dart', 'r') as f:
    content = f.read()

# Make all backgrounds the same (remove the dark blue check)
content = content.replace(
    "color: logoAsset != null\n            ? const Color(0xFF0D1B2A)\n            : gold.withValues(alpha: isDark ? 0.12 : 0.18),",
    "color: gold.withValues(alpha: isDark ? 0.12 : 0.18),"
)

# Update the SvgPicture color filter to match the Icon color
content = content.replace(
    "colorFilter: ColorFilter.mode(\n          isDark ? CompetitionBadge.gold : const Color(0xFF8A6D2B),\n          BlendMode.srcIn,\n        ),",
    "colorFilter: ColorFilter.mode(\n          isDark ? CompetitionBadge.gold : const Color(0xFF16324A),\n          BlendMode.srcIn,\n        ),"
)

with open('lib/widgets/competition_badge.dart', 'w') as f:
    f.write(content)
