import sys

path = 'lib/screens/home_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Since PowerShell read the UTF-8 file as windows-1252 and then saved it as UTF-8,
# we have a double-encoding issue. The current content is UTF-8 decoded text,
# but the characters are actually windows-1252 interpretations of the original UTF-8 bytes.

try:
    # Encode as windows-1252 to get the original UTF-8 bytes
    original_bytes = content.encode('windows-1252')
    # Decode those bytes as UTF-8
    fixed_content = original_bytes.decode('utf-8')
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(fixed_content)
    print("Fixed via windows-1252 reversal.")
except Exception as e:
    print(f"Direct reversal failed: {e}")
    # Fallback: manually replace common patterns
    replacements = {
        'Ã‰': 'É', 'Ã©': 'é', 'Ã¨': 'è', 'Ã ': 'à', 'Ã¢': 'â',
        'Ãª': 'ê', 'Ã¯': 'ï', 'Ã´': 'ô', 'Ã»': 'û', 'Ã§': 'ç',
        'Ã€': 'À', 'Ã·': '•', 'â€“': '–', 'â€”': '—', 'â€™': '’',
        'Â°': '°', 'Â«': '«', 'Â»': '»', 'Ã®': 'î'
    }
    count = 0
    for bad, good in replacements.items():
        if bad in content:
            count += content.count(bad)
            content = content.replace(bad, good)
    # clean up standalone Â which is often used for non-breaking space mapping
    content = content.replace('Â', '')
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Fixed {count} characters via manual replacement.")
