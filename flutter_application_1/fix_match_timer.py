import re

with open('lib/screens/match_details_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("Timer.periodic(const Duration(seconds: 25)", "Timer.periodic(const Duration(seconds: 15)")

with open('lib/screens/match_details_screen.dart', 'w') as f:
    f.write(content)
