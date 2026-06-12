import json
with open('data.json', 'r', encoding='utf-8-sig') as f:
    data = json.load(f)
for game in data.get('games', []):
    for side in ['homeCompetitor', 'awayCompetitor']:
        team = game.get(side, {})
        print(f"{team.get('name')} lineup:")
        for member in team.get('lineups', {}).get('members', []):
            print(f"  {member.get('athleteId')} - status: {member.get('status')} - {member.get('name', '')}")
