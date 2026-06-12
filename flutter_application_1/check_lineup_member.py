import json
import urllib.request

match_id = 4697696
url_game = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=29&timezoneName=Europe/Paris&gameId={match_id}"

req = urllib.request.Request(url_game, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

game = game_data.get('game', {})
home = game.get('homeCompetitor', {})
lineups = home.get('lineups', {})
members = lineups.get('members', [])
print("First member in lineups keys:", members[0].keys())
print("First member in lineups:", members[0])
