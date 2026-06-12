import json
import urllib.request

match_id = 4697696
url = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&gameId={match_id}"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

game = game_data.get('game', {})
home = game.get('homeCompetitor', {})
lineups = home.get('lineups', {})

print("formation:", lineups.get('formation'))
print("home color:", home.get('color'))
print("home nameCode:", home.get('nameCode'))
print()

# Check events structure
events = game.get('events', [])
print("events count:", len(events))
if events:
    print("First event:", events[0])
    for ev in events[:5]:
        print("type:", ev.get('eventType'), "playerId:", ev.get('playerId'), "competitorId:", ev.get('competitorId'))
