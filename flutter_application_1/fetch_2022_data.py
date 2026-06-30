import urllib.request
import json
import time
import os
import sys

API_KEY = 'f1c9549c4fbebba86cb1087d1175a144'
HEADERS = {'x-apisports-key': API_KEY}
BASE_URL = 'https://v3.football.api-sports.io'
DATA_DIR = 'assets/data'

def fetch_json(url):
    print(f"Fetching {url}...", flush=True)
    req = urllib.request.Request(url, headers=HEADERS)
    response = urllib.request.urlopen(req).read()
    time.sleep(6.5) # Prevent 10 requests/minute limit on free tier!
    return json.loads(response)

def main():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)

    # 1. Matches
    matches_data = fetch_json(f"{BASE_URL}/fixtures?league=1&season=2022")
    with open(f"{DATA_DIR}/matches_2022.json", 'w', encoding='utf-8') as f:
        json.dump(matches_data, f, ensure_ascii=False, indent=2)

    # 2. Standings
    standings_data = fetch_json(f"{BASE_URL}/standings?league=1&season=2022")
    with open(f"{DATA_DIR}/standings_2022.json", 'w', encoding='utf-8') as f:
        json.dump(standings_data, f, ensure_ascii=False, indent=2)

    # 3. Top Scorers
    topscorers_data = fetch_json(f"{BASE_URL}/players/topscorers?league=1&season=2022")
    with open(f"{DATA_DIR}/topscorers_2022.json", 'w', encoding='utf-8') as f:
        json.dump(topscorers_data, f, ensure_ascii=False, indent=2)

    # 4. Match Details (Lineups, Events, Stats)
    match_details = {}
    
    # Try to load existing progress to save API quota!
    details_file = f"{DATA_DIR}/match_details_2022.json"
    if os.path.exists(details_file):
        with open(details_file, 'r', encoding='utf-8') as f:
            try:
                match_details = json.load(f)
            except:
                pass

    fixtures = matches_data.get('response', [])
    print(f"Found {len(fixtures)} matches. Fetching details for each...", flush=True)
    
    for idx, match in enumerate(fixtures):
        match_id = str(match['fixture']['id'])
        if match_id in match_details:
            print(f"[{idx+1}/{len(fixtures)}] Match {match_id} already fetched. Skipping.", flush=True)
            continue
            
        print(f"[{idx+1}/{len(fixtures)}] Fetching match {match_id}...", flush=True)
        try:
            details = fetch_json(f"{BASE_URL}/fixtures?id={match_id}")
            if 'response' in details and len(details['response']) > 0:
                match_details[match_id] = details['response'][0]
                # Save progressively in case it crashes
                with open(details_file, 'w', encoding='utf-8') as f:
                    json.dump(match_details, f, ensure_ascii=False, indent=2)
            else:
                print(f"WARNING: No details found for match {match_id}")
        except Exception as e:
            print(f"Error fetching {match_id}: {e}", flush=True)
            sys.exit(1)

    print("DONE! All data saved successfully.", flush=True)

if __name__ == '__main__':
    main()
