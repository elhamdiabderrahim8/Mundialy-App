import json
import urllib.request

match_id = 4627866 
url = f"https://webws.365scores.com/web/game/?appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135&gameId={match_id}"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
game_data = json.loads(urllib.request.urlopen(req).read())

game = game_data.get('game', {})
officials = game.get('officials', [])
print("Officials:")
for o in officials:
    print(" ", o)

home_lineups = game['homeCompetitor'].get('lineups', {})
print()
print("Home lineups status:", home_lineups.get('status'))
print("Home formation:", home_lineups.get('formation'))
print("Home has field positions:", home_lineups.get('hasFieldPositions'))
print()
print("First home lineup member:", home_lineups.get('members', [{}])[0])
