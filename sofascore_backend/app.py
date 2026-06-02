import os
import time
import json
import datetime
from flask import Flask, jsonify, request, abort
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

app = Flask(__name__)

# --- CONFIGURATION ---
IPTV_STREAM_URL = "https://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8"
UT_ID = 16
S_ID_2026 = 58210
S_ID_2022 = 41087
SOFA_BASE_URL = "https://api.sofascore.com/api/v1"

DATA_DIR = "data"
WC2022_DIR = os.path.join(DATA_DIR, "wc2022")

for d in [DATA_DIR, WC2022_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

def init_selenium_driver():
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    options.add_experimental_option('excludeSwitches', ['enable-logging'])
    return webdriver.Chrome(options=options)

def fetch_json(driver, url):
    try:
        print(f"📡 Scraping SofaScore: {url}")
        driver.get(url)
        time.sleep(2)  # Augmenté pour garantir le chargement
        raw_text = driver.find_element("xpath", "//body").text
        return json.loads(raw_text)
    except Exception as e:
        print(f"💥 Erreur Scraping: {e}")
        return None

# ==========================================
# AUTOMATISATION INITIALISATION 2022
# ==========================================

WC2022_ENDPOINTS = {
    "info": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/info",
    "venues": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/venues",
    "standings": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/standings/total",
    "bracket": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/cuptrees",
    "top_players": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/top-players/overall",
}

WC2022_ROUNDS = [
    {"id": 1, "slug": "", "name": "Group Stage J1"},
    {"id": 2, "slug": "", "name": "Group Stage J2"},
    {"id": 3, "slug": "", "name": "Group Stage J3"},
    {"id": 26, "slug": "round-of-16", "name": "Round of 16"},
    {"id": 27, "slug": "quarter-finals", "name": "Quarter-finals"},
    {"id": 28, "slug": "semi-finals", "name": "Semi-finals"},
    {"id": 30, "slug": "play-off-for-third-place", "name": "Third place"},
    {"id": 29, "slug": "final", "name": "Final"},
]

def initialize_wc2022_data():
    """Télécharge et fige toutes les données de 2022 si elles manquent."""
    # On vérifie si les fichiers essentiels existent
    essential_files = ["info.json", "venues.json", "standings.json", "bracket.json", "fixtures.json"]
    if all(os.path.exists(os.path.join(WC2022_DIR, f)) for f in essential_files):
        print("✅ Archive WC2022 déjà complète localement.")
        return

    print("🚀 Démarrage du sprint de collecte WC2022...")
    driver = init_selenium_driver()
    try:
        # 1. Collecte des Endpoints Simples
        for key, url in WC2022_ENDPOINTS.items():
            data = fetch_json(driver, url)
            if data:
                with open(os.path.join(WC2022_DIR, f"{key}.json"), 'w', encoding='utf-8') as f:
                    json.dump({"response": data}, f, indent=4)

        # 2. Collecte et Agrégation des Matchs (Fixtures)
        all_matches = []
        for rd in WC2022_ROUNDS:
            url = f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/events/round/{rd['id']}"
            if rd['slug']:
                url += f"/slug/{rd['slug']}"

            data = fetch_json(driver, url)
            if data and 'events' in data:
                for e in data['events']:
                    h_score = e.get('homeScore', {})
                    a_score = e.get('awayScore', {})
                    all_matches.append({
                        "fixture": {
                            "id": e['id'],
                            "date": datetime.datetime.fromtimestamp(e['startTimestamp']).isoformat(),
                            "status": {"short": "FT", "long": "Finished"}
                        },
                        "league": {"round": rd['name']},
                        "teams": {
                            "home": {"id": e['homeTeam']['id'], "name": e['homeTeam']['name'], "logo": f"{SOFA_BASE_URL}/team/{e['homeTeam']['id']}/image"},
                            "away": {"id": e['awayTeam']['id'], "name": e['awayTeam']['name'], "logo": f"{SOFA_BASE_URL}/team/{e['awayTeam']['id']}/image"}
                        },
                        "goals": {"home": h_score.get('display', 0), "away": a_score.get('display', 0)},
                        "score": {
                            "fulltime": {"home": h_score.get('display', 0), "away": a_score.get('display', 0)},
                            "penalty": {"home": h_score.get('penalties'), "away": a_score.get('penalties')}
                        }
                    })
                print(f"📦 Round {rd['id']} ({rd['name']}) récupéré.")

        with open(os.path.join(WC2022_DIR, "fixtures.json"), 'w', encoding='utf-8') as f:
            json.dump({"response": all_matches}, f, indent=4)

    finally:
        driver.quit()
    print("🏁 Fin de l'initialisation de l'archive 2022.")

# ==========================================
# ROUTES API WC 2022 (CONSULTATION)
# ==========================================

@app.route('/api/wc2022/<string:resource>', methods=['GET'])
def get_wc2022_resource(resource):
    """Route générique pour servir les fichiers statiques 2022."""
    path = os.path.join(WC2022_DIR, f"{resource}.json")
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            return jsonify(json.load(f))
    return jsonify({"error": "Ressource non trouvée"}), 404

# ==========================================
# LIVE FILTERED ROUTE (NATIONS ONLY)
# ==========================================

@app.route('/api/worldcup/live', methods=['GET'])
def get_filtered_live_nations():
    cache_path = os.path.join(DATA_DIR, "live_nations_cache.json")
    if os.path.exists(cache_path) and (time.time() - os.path.getmtime(cache_path)) < 15:
        with open(cache_path, 'r', encoding='utf-8') as f:
            return jsonify(json.load(f))

    driver = init_selenium_driver()
    try:
        url = f"{SOFA_BASE_URL}/sport/football/events/live"
        data = fetch_json(driver, url)
        if not data or 'events' not in data: return jsonify({"response": []})

        filtered = []
        ALLOWED_KW = ["international", "world", "cup of nations", "euro", "copa america", "nations league", "olympic", "u21", "u23", "friendly"]

        for e in data['events']:
            tour = e.get('tournament', {})
            cat_name = tour.get('category', {}).get('name', '').lower()
            tour_name = tour.get('name', '').lower()

            if cat_name in ["international", "world"] or any(kw in tour_name for kw in ALLOWED_KW):
                h_score = e.get('homeScore', {})
                a_score = e.get('awayScore', {})
                status = e.get('status', {})

                filtered.append({
                    "id": e.get('id'),
                    "homeTeam": e.get('homeTeam', {}).get('name'),
                    "awayTeam": e.get('awayTeam', {}).get('name'),
                    "scoreHome": h_score.get('current'),
                    "scoreAway": a_score.get('current'),
                    "status": status.get('description'),
                    "shortStatus": status.get('type'),
                    "tournament": tour.get('name'),
                    "isLive": True
                })
        res = {"response": filtered}
        with open(cache_path, 'w', encoding='utf-8') as f: json.dump(res, f, indent=4)
        return jsonify(res)
    finally: driver.quit()

# ==========================================
# ROUTES DYNAMIQUES 2026
# ==========================================

@app.route('/api/fixtures', methods=['GET'])
def get_fixtures_2026():
    # ... Redirection vers 2022 si besoin ...
    season = request.args.get('season')
    if season == '2022': return get_wc2022_resource("fixtures")

    filepath = os.path.join(DATA_DIR, "wc2026_fixtures.json")
    if os.path.exists(filepath) and (time.time() - os.path.getmtime(filepath)) < 60:
        with open(filepath, 'r', encoding='utf-8') as f: return jsonify({"response": json.load(f)})

    driver = init_selenium_driver()
    try:
        url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/events/next/0"
        data = fetch_json(driver, url)
        if not data or 'events' not in data: return jsonify({"response": []})
        formatted = []
        for e in data['events']:
            status = e.get('status', {})
            short = "LIVE" if status.get('type') == "inprogress" else ("FT" if status.get('type') == "finished" else "NS")
            formatted.append({"fixture": {"id": e['id'], "timestamp": e['startTimestamp'], "date": datetime.datetime.fromtimestamp(e['startTimestamp']).isoformat(), "status": {"short": short, "long": status.get('description'), "elapsed": 0}}, "teams": {"home": {"id": e['homeTeam']['id'], "name": e['homeTeam']['name'], "logo": f"{SOFA_BASE_URL}/team/{e['homeTeam']['id']}/image"}, "away": {"id": e['awayTeam']['id'], "name": e['awayTeam']['name'], "logo": f"{SOFA_BASE_URL}/team/{e['awayTeam']['id']}/image"}}, "goals": {"home": e.get('homeScore', {}).get('current', 0), "away": e.get('awayScore', {}).get('current', 0)}, "stream_url": IPTV_STREAM_URL})
        with open(filepath, 'w', encoding='utf-8') as f: json.dump(formatted, f, indent=4)
        return jsonify({"response": formatted})
    finally: driver.quit()

@app.route('/api/standings', methods=['GET'])
def get_standings_2026():
    season = request.args.get('season')
    if season == '2022': return get_wc2022_resource("standings")
    # Logique 2026...
    return jsonify({"response": []})

@app.route('/api/match/<int:match_id>', methods=['GET'])
def get_match_details(match_id):
    # Logique d'agrégation temps réel
    driver = init_selenium_driver()
    try:
        event = fetch_json(driver, f"{SOFA_BASE_URL}/event/{match_id}")
        inc = fetch_json(driver, f"{SOFA_BASE_URL}/event/{match_id}/incidents")
        # On renvoie un format compatible avec ton MatchDetails.fromApi
        return jsonify({"response": [{"fixture": {"id": match_id}, "event": event.get('event'), "incidents": inc.get('incidents', [])}]})
    finally: driver.quit()

if __name__ == '__main__':
    # On initialise l'archive au démarrage
    initialize_wc2022_data()
    app.run(host='0.0.0.0', port=5000, debug=False)
