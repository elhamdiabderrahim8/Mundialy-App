import re

with open('lib/widgets/match_card.dart', 'r') as f:
    content = f.read()

def replace_hero(match):
    tag = match.group(1)
    countryCode = match.group(2)
    teamName = match.group(3)
    size = match.group(4)
    return f"""Hero(
      tag: '{tag}',
      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) => Material(
        type: MaterialType.transparency,
        child: NationFlagBadge(
          countryCode: {countryCode},
          teamName: {teamName},
          size: {size},
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: NationFlagBadge(
          countryCode: {countryCode},
          teamName: {teamName},
          size: {size},
        ),
      ),
    )"""

new_content = re.sub(
    r"Hero\(\s*tag:\s*'([^']+)',\s*child:\s*NationFlagBadge\(\s*countryCode:\s*([^,]+),\s*teamName:\s*([^,]+),\s*size:\s*([^,]+),\s*\),\s*\)",
    replace_hero,
    content,
    flags=re.MULTILINE
)

with open('lib/widgets/match_card.dart', 'w') as f:
    f.write(new_content)
