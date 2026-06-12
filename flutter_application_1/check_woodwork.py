import json
import urllib.request

match_id = 4627866 
url = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&gameId={match_id}"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

game = game_data.get('game', {})
members_list = game.get('members', [])
home = game.get('homeCompetitor', {})
away = game.get('awayCompetitor', {})

# Check some members
print('Sample members:')
for m in members_list[:3]:
    print(' ', m.get('name'), '| athleteId:', m.get('athleteId'), '| jerseyNumber:', m.get('jerseyNumber'), '| competitorId:', m.get('competitorId'))

# check woodwork event type
events = game.get('events', [])
for ev in events:
    etype = ev.get('eventType', {})
    typeid = etype.get('id', 0)
    name = etype.get('name', '')
    if name.lower() == 'woodwork' or typeid not in [1, 2, 3, 1000]:
        print(f'Unhandled event: id={typeid} name={name}')
