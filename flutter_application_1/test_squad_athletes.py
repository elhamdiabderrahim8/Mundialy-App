import urllib.request, json
team_id = 5961
url = f'https://webws.365scores.com/web/squads/?competitors={team_id}&appTypeId=5&langId=29'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
    
    squads = data.get('squads', [])
    if squads:
        athletes = squads[0].get('athletes', [])
        positions = squads[0].get('positions', [])
        print(f"Positions: {positions}")
        if athletes:
            print(f"Sample athlete: {json.dumps(athletes[0], indent=2)}")
except Exception as e:
    print(f"Error fetching: {e}")
