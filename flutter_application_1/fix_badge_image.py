import re

with open('lib/widgets/competition_badge.dart', 'r') as f:
    content = f.read()

# Add alignment: Alignment.center to the Container
content = content.replace(
    "decoration: BoxDecoration(",
    "alignment: Alignment.center,\n      decoration: BoxDecoration("
)

# Update Image.asset to use BoxFit.contain and restricted size
image_asset_replacement = """return Image.asset(
      asset,
      width: size * 0.72,
      height: size * 0.72,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
    );"""

content = re.sub(
    r'return Image\.asset\(\s*asset,\s*fit:\s*BoxFit\.cover,\s*errorBuilder:\s*\(context, error, stackTrace\)\s*=>\s*fallback,\s*\);',
    image_asset_replacement,
    content
)

with open('lib/widgets/competition_badge.dart', 'w') as f:
    f.write(content)
