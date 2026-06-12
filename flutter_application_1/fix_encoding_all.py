import sys
import os

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    replacements = {
        'Ã‰': 'É', 'Ã©': 'é', 'Ã¨': 'è', 'Ã ': 'à', 'Ã¢': 'â',
        'Ãª': 'ê', 'Ã¯': 'ï', 'Ã´': 'ô', 'Ã»': 'û', 'Ã§': 'ç',
        'Ã€': 'À', 'Ã·': '•', 'â€“': '–', 'â€”': '—', 'â€™': '’',
        'Â°': '°', 'Â«': '«', 'Â»': '»', 'Ã®': 'î'
    }
    count = 0
    original_content = content
    for bad, good in replacements.items():
        if bad in content:
            count += content.count(bad)
            content = content.replace(bad, good)
    
    content = content.replace('Â', '')

    if count > 0:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed {count} characters in {path}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            try:
                fix_file(os.path.join(root, file))
            except Exception as e:
                print(f"Failed to process {file}: {e}")
