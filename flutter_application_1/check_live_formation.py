import urllib.request, json
url = 'https://webws.365scores.com/web/games/current/?appTypeId=5&langId=29'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())

game_id = None
games = data.get('games', [])
for game in games:
    if game.get('statusText') == 'Terminé' or game.get('gameTime') > 0:
        game_id = game.get('id')
        break

if game_id:
    stats_url = f'https://webws.365scores.com/web/game/stats/?games={game_id}'
    req = urllib.request.Request(stats_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        stats_data = json.loads(response.read().decode())
    
    for game in stats_data.get('games', []):
        home = game.get('homeCompetitor', {})
        lineups = home.get('lineups')
        if lineups and lineups.get('members'):
            print(f"Game ID: {game.get('id')} - Formation: {lineups.get('formation')}")
        else:
            print(f"Game ID: {game.get('id')} - No lineups found")
else:
    print("No recent games found")
