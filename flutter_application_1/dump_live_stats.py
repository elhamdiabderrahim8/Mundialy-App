import urllib.request, json
url = 'https://webws.365scores.com/web/games/current/?appTypeId=5&langId=29'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())

game_id = None
for game in data.get('games', []):
    if game.get('statusText') != 'Terminé' and game.get('gameTime', 0) > 0:
        game_id = game.get('id')
        break

if not game_id:
    # Just get any recent game that might have stats
    for game in data.get('games', []):
        if game.get('statusText') == 'Terminé':
            game_id = game.get('id')
            break

if game_id:
    stats_url = f'https://webws.365scores.com/web/game/stats/?games={game_id}'
    req = urllib.request.Request(stats_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        stats_data = json.loads(response.read().decode())
    
    with open('live_game_stats.json', 'w', encoding='utf-8') as f:
        json.dump(stats_data, f, indent=2)
    print(f"Dumped stats for game {game_id}")
else:
    print("No games found")
