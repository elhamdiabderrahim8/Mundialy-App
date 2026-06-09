import requests
import json

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Origin': 'https://www.sofascore.com',
    'Referer': 'https://www.sofascore.com/',
}

url = 'https://api.sofascore.com/api/v1/team/4481/players'
response = requests.get(url, headers=headers)
print(f"Status: {response.status_code}")
try:
    data = response.json()
    print("Keys in response:", data.keys())
    if 'players' in data:
        print(f"Number of players: {len(data['players'])}")
        if len(data['players']) > 0:
            print("First player keys:", data['players'][0].keys())
            if 'player' in data['players'][0]:
                print("First player inner keys:", data['players'][0]['player'].keys())
except Exception as e:
    print("Error parsing JSON:", e)
    print("Response text:", response.text[:200])
