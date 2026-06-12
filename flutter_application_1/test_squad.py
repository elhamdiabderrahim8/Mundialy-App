import urllib.request, json
# Trying to fetch squad for competitor 5961 (France)
team_id = 5961
url = f'https://webws.365scores.com/web/squads/?competitors={team_id}&appTypeId=5&langId=29'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
    
    squads = data.get('squads', [])
    print(f"Found {len(squads)} squads")
    if squads:
        print(squads[0].keys())
except Exception as e:
    print(f"Error fetching: {e}")

