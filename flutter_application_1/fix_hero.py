import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

# Replace all Hero widgets that match this pattern
def replacer(m):
    # m.group(1) is the spaces before Hero
    # m.group(2) is the tag string
    # m.group(3) is the countryCode
    # m.group(4) is the teamName
    # m.group(5) is the size
    spaces = m.group(1)
    tag = m.group(2)
    cc = m.group(3)
    tn = m.group(4)
    size = m.group(5)
    
    return f"""{spaces}Hero(
{spaces}  tag: {tag},
{spaces}  flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) => Material(
{spaces}    type: MaterialType.transparency,
{spaces}    child: NationFlagBadge(
{spaces}      countryCode: {cc},
{spaces}      teamName: {tn},
{spaces}      size: {size},
{spaces}    ),
{spaces}  ),
{spaces}  child: NationFlagBadge(
{spaces}    countryCode: {cc},
{spaces}    teamName: {tn},
{spaces}    size: {size},
{spaces}  ),
{spaces})"""

content = re.sub(
    r'([ \t]+)Hero\(\s*tag:\s*([^,]+),\s*child:\s*NationFlagBadge\(\s*countryCode:\s*([^,]+),\s*teamName:\s*([^,]+),\s*size:\s*([0-9]+),\s*\),\s*\)',
    replacer,
    content
)

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
