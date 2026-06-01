import os
import time
import json
import datetime
from flask import Flask, jsonify, request
from selenium import webdriver

app = Flask(__name__)

# --- CONFIGURATION ---
IPTV_STREAM_URL = "https://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8"
SOFA_BASE_URL = 'https://api.sofascore.com/api/v1'
S_ID = 58210  # Season 2026 ID
DEFAULT_GROUP_ID = 3954 # Group A ID

# Dossier pour le cache
DATA_DIR = "data"
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

def init_selenium_driver():
    options = webdriver.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_experimental_option('excludeSwitches', ['enable-logging'])
    return webdriver.Chrome(options=options)

def fetch_via_selenium(url):
    """Helper standard pour extraire le JSON via Selenium."""
    driver = None
    try:
        driver = init_selenium_driver()
        driver.get(url)
        raw_text = driver.find_element("xpath", "//body").text
        return json.loads(raw_text)
    except Exception as e:
        print(f"💥 Erreur Selenium sur {url}: {e}")
        return None
    finally:
        if driver: driver.quit()

# ==========================================
# GESTION DYNAMIQUE DES FIXTURES PAR GROUPE
# ==========================================

@app.route('/api/fixtures', methods=['GET'])
def get_fixtures():
    season = request.args.get('season', '2026')
    group_id = request.args.get('groupId', str(DEFAULT_GROUP_ID))

    if season != '2026':
        # Fallback 2022
        path2022 = os.path.join(DATA_DIR, 'fixtures.json')
        if os.path.exists(path2022):
            with open(path2022, 'r', encoding='utf-8') as f: return jsonify(json.load(f))
        return jsonify({"response": []})

    filepath = os.path.join(DATA_DIR, f"wc2026_events_{group_id}.json")

    # 1. Vérification du cache intelligent
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            cached_data = json.load(f)

        # Déterminer la durée de validité du cache
        any_live = any(
            m['fixture']['status']['short'] in ['1H', '2H', 'HT', 'ET', 'P', 'LIVE']
            for m in cached_data
        )
        cache_limit = 60 if any_live else 3600 # 1 min si live, 1h sinon

        if (time.time() - os.path.getmtime(filepath)) < cache_limit:
            return jsonify({"response": cached_data})

    # 2. Scraping dynamique via SofaScore
    print(f"🌐 Scraping dynamique des matchs pour le groupe/tournoi ID : {group_id}")
    url = f"{SOFA_BASE_URL}/tournament/{group_id}/season/{S_ID}/events"
    raw_data = fetch_via_selenium(url)

    if not raw_data or 'events' not in raw_data:
        return jsonify({"response": []})

    # 3. Parsing et Traduction pour Flutter (Compatibilité API-Sports)
    formatted_fixtures = []
    for event in raw_data['events']:
        fixture_id = event.get('id', 0)
        ts = event.get('startTimestamp', 0)
        status_desc = event.get('status', {}).get('description', 'Not Started')
        status_type = event.get('status', {}).get('type', 'notstarted')

        home = event.get('homeTeam', {})
        away = event.get('awayTeam', {})

        # Mappage des statuts pour l'UI Flutter
        short_status = "NS"
        if status_type == "inprogress": short_status = "1H"
        elif status_type == "finished": short_status = "FT"

        formatted_fixtures.append({
            "fixture": {
                "id": int(fixture_id),
                "timestamp": int(ts),
                "date": datetime.datetime.fromtimestamp(ts).isoformat(),
                "status": {
                    "long": status_desc,
                    "short": short_status,
                    "elapsed": 0
                }
            },
            "teams": {
                "home": {
                    "id": int(home.get('id', 0)),
                    "name": home.get('name', 'TBD'),
                    "logo": f"https://api.sofascore.app/api/v1/team/{home.get('id', 0)}/image"
                },
                "away": {
                    "id": int(away.get('id', 0)),
                    "name": away.get('name', 'TBD'),
                    "logo": f"https://api.sofascore.app/api/v1/team/{away.get('id', 0)}/image"
                }
            },
            "goals": {
                "home": event.get('homeScore', {}).get('current', 0),
                "away": event.get('awayScore', {}).get('current', 0)
            },
            "stream_url": IPTV_STREAM_URL
        })

    # 4. Sauvegarde dans le cache
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(formatted_fixtures, f, indent=4)

    return jsonify({"response": formatted_fixtures})

# ==========================================
# AUTRES ROUTES (STANDINGS, VENUES, LIVE)
# ==========================================

@app.route('/api/standings', methods=['GET'])
def get_standings():
    season = request.args.get('season', '2026')
    if season == '2026':
        filepath = os.path.join(DATA_DIR, "wc2026_true_standings.json")
        if os.path.exists(filepath) and (time.time() - os.path.getmtime(filepath) < 3600):
            with open(filepath, 'r', encoding='utf-8') as f: return jsonify(json.load(f))

        # UT_ID = 16 pour la compétition globale
        url = f"{SOFA_BASE_URL}/unique-tournament/16/season/{S_ID}/standings/total"
        raw_data = fetch_via_selenium(url)
        if not raw_data or 'standings' not in raw_data: return jsonify({"response": []})

        formatted = []
        for group in raw_data['standings']:
            teams = []
            group_name = group.get('name', 'Group')
            for row in group.get('rows', []):
                t = row.get('team', {})
                teams.append({
                    "rank": row.get('position'),
                    "group": group_name,
                    "team": {"id": t.get('id'), "name": t.get('name'), "logo": f"https://api.sofascore.app/api/v1/team/{t.get('id')}/image"},
                    "points": row.get('points'),
                    "goalsDiff": row.get('goalsFor', 0) - row.get('goalsAgainst', 0),
                    "all": {"played": row.get('matches'), "win": row.get('wins'), "draw": row.get('draws'), "lose": row.get('losses')}
                })
            formatted.append({"league": {"id": 16, "name": "World Cup 2026", "standings": [teams]}})
        with open(filepath, 'w', encoding='utf-8') as f: json.dump(formatted, f, indent=4)
        return jsonify({"response": formatted})
    return jsonify({"response": []})

@app.route('/api/worldcup/venues', methods=['GET'])
def get_venues():
    filepath = os.path.join(DATA_DIR, "wc2026_venues.json")
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f: return jsonify({"response": json.load(f)})
    url = f"{SOFA_BASE_URL}/unique-tournament/16/season/{S_ID}/venues"
    raw_data = fetch_via_selenium(url)
    if not raw_data or 'venues' not in raw_data: return jsonify({"response": []})
    cleaned = [{"id": v.get('id'), "name": v.get('name'), "city": v.get('city', {}).get('name', 'USA'), "capacity": v.get('capacity', 'N/A'), "image": f"https://api.sofascore.app/api/v1/venue/{v.get('id')}/image"} for v in raw_data['venues']]
    with open(filepath, 'w', encoding='utf-8') as f: json.dump(cleaned, f, indent=4)
    return jsonify({"response": cleaned})

@app.route('/api/worldcup/news', methods=['GET'])
def get_news(): return jsonify({"response": []})

if __name__ == '__main__':
    print("🚀 Serveur SofaScore WC 2026 Dynamique par Groupe (Cache Adaptatif) Online !")
    app.run(host='0.0.0.0', port=5000, debug=False)
