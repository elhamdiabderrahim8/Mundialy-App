import urllib.request, json
team_id = 100 # PSG
url = f'https://webws.365scores.com/web/squads/?competitors={team_id}&appTypeId=5&langId=29'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())
print(json.dumps(data.get('squads', [])[0].get('athletes', [])[0], indent=2))
