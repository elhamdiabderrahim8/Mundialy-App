import json
with open('data.json', 'r', encoding='utf-8-sig') as f:
    data = json.load(f)
for game in data.get('games', []):
    for side in ['homeCompetitor', 'awayCompetitor']:
        team = game.get(side, {})
        lineup = team.get('lineups', {})
        print(f"{team.get('name')} formation: {lineup.get('formation')} - type: {type(lineup.get('formation'))}")
