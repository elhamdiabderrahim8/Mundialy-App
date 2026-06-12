import urllib.request, json
team_id = 5961
url = f'https://webws.365scores.com/web/squads/?competitors={team_id}&appTypeId=5&langId=29'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
    
    with open('squad_response.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print(f"Error fetching: {e}")
