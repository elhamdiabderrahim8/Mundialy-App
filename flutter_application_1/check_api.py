import json
import urllib.request

match_id = 4697696
url_game = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=29&timezoneName=Europe/Paris&gameId={match_id}"
url_lineups = f"https://webws.365scores.com/web/game/lineups/?appTypeId=5&langId=29&timezoneName=Europe/Paris&games={match_id}"

req = urllib.request.Request(url_game, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

req = urllib.request.Request(url_lineups, headers={'User-Agent': 'Mozilla/5.0'})
lineups_data = json.loads(urllib.request.urlopen(req).read())

print("gameData keys:", game_data.keys())
print("gameData['game'] keys:", game_data.get('game', {}).keys())

print("lineupsData keys:", lineups_data.keys())
if 'games' in lineups_data and len(lineups_data['games']) > 0:
    game_lineup = lineups_data['games'][0]
    print("lineupsData['games'][0] keys:", game_lineup.keys())
    home = game_lineup.get('homeCompetitor', {})
    print("home keys in lineups:", home.keys())
    print("has lineups in home?", 'lineups' in home)

print("members in lineupsData?", 'members' in lineups_data)
