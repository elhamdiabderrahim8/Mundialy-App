import urllib.request
import json
import time

url = "https://webws.365scores.com/web/games/current/?appTypeId=5&langId=29&timezoneName=Africa/Casablanca&userCountryId=38"

start = time.time()
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        print(f"Time taken: {time.time() - start:.2f}s")
        games = data.get('games', [])
        print(f"Total games returned: {len(games)}")
        
        comps = {}
        for g in games:
            cid = g.get('competitionId')
            comps[cid] = comps.get(cid, 0) + 1
        print(f"Total unique competitions: {len(comps)}")
except Exception as e:
    print(e)
