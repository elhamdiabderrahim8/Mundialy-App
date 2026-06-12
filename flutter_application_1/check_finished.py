import json
import urllib.request

match_id = 4627866  # Mexico vs South Africa (finished)
url = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&gameId={match_id}"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

game = game_data.get('game', {})
home = game.get('homeCompetitor', {})
away = game.get('awayCompetitor', {})
members_list = game.get('members', [])

print(f"Home: {home['name']}, Away: {away['name']}")
print(f"Score: {home['score']} - {away['score']}")
print(f"Members: {len(members_list)}")
print(f"Events: {len(game.get('events', []))}")
print()

# Check if coaches are present in members
for m in members_list:
    if 'coach' in str(m.get('name', '')).lower():
        print('Coach member:', m)
        break

# Check lineups formation
home_lineups = home.get('lineups', {})
print("Home formation:", home_lineups.get('formation'))
print("Home color:", home.get('color'))

# Events
events = game.get('events', [])
if events:
    print("\nFirst event:", events[0])
else:
    print("No events found (try checking keys):", list(game.keys()))
