import json
import urllib.request

player_id = 771
url_player = f"https://webws.365scores.com/web/player/?appTypeId=5&langId=29&timezoneName=Europe/Paris&players={player_id}"

req = urllib.request.Request(url_player, headers={'User-Agent': 'Mozilla/5.0'})
try:
    player_data = json.loads(urllib.request.urlopen(req).read())
    print("player data keys:", player_data.keys())
except Exception as e:
    print(e)
