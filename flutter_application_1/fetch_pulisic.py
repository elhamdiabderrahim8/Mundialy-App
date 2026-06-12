import urllib.request, json
player_id = 15478
url = f'https://webws.365scores.com/web/athletes/?appTypeId=5&langId=29&athletes={player_id}'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
    
    with open('pulisic_athlete.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print(f"Error fetching: {e}")
