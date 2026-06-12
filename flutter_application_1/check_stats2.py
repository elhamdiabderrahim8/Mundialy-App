import json
import urllib.request

url_stats = "https://webws.365scores.com/web/game/stats/?appTypeId=5&langId=1&games=4697696"

req = urllib.request.Request(url_stats, headers={'User-Agent': 'Mozilla/5.0'})
stats_data = json.loads(urllib.request.urlopen(req).read())

print("statsData keys:", stats_data.keys())
if 'games' in stats_data and len(stats_data['games']) > 0:
    game_stat = stats_data['games'][0]
    print("statsData['games'][0] keys:", game_stat.keys())
    if 'homeCompetitor' in game_stat:
        print("home keys in stats:", game_stat['homeCompetitor'].keys())
        print("has lineups in home?", 'lineups' in game_stat['homeCompetitor'])
else:
    print("NO games in statsData")

print("members in statsData?", 'members' in stats_data)
