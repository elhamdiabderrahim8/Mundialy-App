import json
import urllib.request

match_id = 4697696
url_game = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=29&timezoneName=Europe/Paris&gameId={match_id}"
url_stats = f"https://webws.365scores.com/web/game/stats/?appTypeId=5&langId=29&timezoneName=Europe/Paris&games={match_id}"

req = urllib.request.Request(url_game, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

req = urllib.request.Request(url_stats, headers={'User-Agent': 'Mozilla/5.0'})
stats_data = json.loads(urllib.request.urlopen(req).read())

print("gameData keys:", game_data.keys())
print("gameData['game'] keys:", game_data.get('game', {}).keys())

print("\nstatsData keys:", stats_data.keys())
if 'games' in stats_data and len(stats_data['games']) > 0:
    game_stat = stats_data['games'][0]
    print("statsData['games'][0] keys:", game_stat.keys())
    home = game_stat.get('homeCompetitor', {})
    print("home keys in stats:", home.keys())
    print("has lineups in home?", 'lineups' in home)

print("members in statsData?", 'members' in stats_data)
