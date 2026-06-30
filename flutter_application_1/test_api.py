import urllib.request
import json

url = 'https://webws.365scores.com/web/games/results/?appTypeId=5&langId=1&timezoneName=Europe/London&competitions=672&limit=50'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        for g in data.get('games', []):
            print(f"Match ID: {g['id']} - {g['homeCompetitor']['name']} vs {g['awayCompetitor']['name']} {g['homeCompetitor']['score']}-{g['awayCompetitor']['score']}")
except Exception as e:
    print(e)
