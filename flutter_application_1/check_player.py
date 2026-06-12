import json
import urllib.request

player_id = 455623
url_player = f"https://webws.365scores.com/web/player/?appTypeId=5&langId=29&timezoneName=Europe/Paris&playerId={player_id}"

req = urllib.request.Request(url_player, headers={'User-Agent': 'Mozilla/5.0'})
try:
    player_data = json.loads(urllib.request.urlopen(req).read())
    print("player keys:", player_data.get('player', {}).keys())
    print("player name:", player_data.get('player', {}).get('name'))
    print("player team:", player_data.get('player', {}).get('competitorId'))
    print("has stats?", 'statistics' in player_data)
except Exception as e:
    print(e)
