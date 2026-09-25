import re

with open('lib/screens/home_screen.dart', 'r') as f:
    content = f.read()

content = content.replace('  bool _scorePollBusy = false;', '  bool _scorePollBusy = false;\n  bool _isFetchingLive = false;')

with open('lib/screens/home_screen.dart', 'w') as f:
    f.write(content)
