import json
import urllib.request

match_id = 4627866  # Mexico vs South Africa (finished)
url = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&gameId={match_id}"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

game = game_data.get('game', {})
members_list = game.get('members', [])
home = game.get('homeCompetitor', {})
away = game.get('awayCompetitor', {})

members_map = {m['id']: m for m in members_list}

# Check events for home vs away and player names
events = game.get('events', [])
print(f"Home id: {home['id']}, Away id: {away['id']}")
print()
for ev in events:
    cid = ev.get('competitorId')
    pid = ev.get('playerId')
    player_name = members_map.get(pid, {}).get('name', 'Unknown')
    is_home = cid == home['id']
    etype = ev.get('eventType', {})
    print(f"  {'HOME' if is_home else 'AWAY'} | {etype.get('name')} | {player_name} @ {ev.get('gameTimeDisplay')}")
