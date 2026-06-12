import json
import urllib.request

# Try to get a FINISHED match to see events
url = "https://webws.365scores.com/web/games/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&competitions=5930&startDate=11/06/2026&endDate=19/07/2026"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
games_data = json.loads(urllib.request.urlopen(req).read())

games = games_data.get('games', [])
finished = [g for g in games if g.get('statusGroup') == 4]
print(f"Total games: {len(games)}, Finished: {len(finished)}")
if finished:
    g = finished[0]
    print("Finished game id:", g['id'])
    print("Home:", g['homeCompetitor']['name'], "Away:", g['awayCompetitor']['name'])
