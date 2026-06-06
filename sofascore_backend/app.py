import os
import time
import json
import datetime
import urllib.request
import threading
import firebase_admin
from firebase_admin import credentials, messaging
from flask import Flask, jsonify, request

app = Flask(__name__)

# Firebase admin initialization
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin initialized successfully.")
except Exception as e:
    print(f"Error initializing Firebase Admin: {e}")

# --- CONFIGURATION ---
IPTV_STREAM_URL = "https://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8"
UT_ID = 16
S_ID_2026 = 58210
S_ID_2022 = 41087
SOFA_BASE_URL = "https://api.sofascore.com/api/v1"

DATA_DIR = "data"
WC2022_DIR = os.path.join(DATA_DIR, "wc2022")
WC2026_DIR = os.path.join(DATA_DIR, "wc2026")

# Création automatique des répertoires pour le stockage local (Cache)
for d in [DATA_DIR, WC2022_DIR, WC2026_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

from curl_cffi import requests as cffi_requests
import random

# Profils d'impersonation à rotater pour éviter le blocage
_IMPERSONATE_PROFILES = ['chrome110', 'chrome107', 'chrome104', 'chrome101']

# Headers réalistes d'un vrai navigateur Chrome sur SofaScore
_SOFA_HEADERS = {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'Referer': 'https://www.sofascore.com/',
    'Origin': 'https://www.sofascore.com',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

def fetch_json_fast(url, retries=3, base_timeout=10):
    """Fetch JSON from SofaScore API avec retry + rotation de profil."""
    last_error = None
    for attempt in range(retries):
        profile = _IMPERSONATE_PROFILES[attempt % len(_IMPERSONATE_PROFILES)]
        timeout = base_timeout + attempt * 5  # 10s, 15s, 20s
        try:
            r = cffi_requests.get(
                url,
                headers=_SOFA_HEADERS,
                impersonate=profile,
                timeout=timeout
            )
            if r.status_code == 200:
                return r.json()
            elif r.status_code == 429:
                # Rate limited - attendre avant de réessayer
                wait_time = 2 ** attempt  # 1s, 2s, 4s
                print(f"[Rate Limited] Attente {wait_time}s avant retry...")
                time.sleep(wait_time)
            elif r.status_code in [403, 451]:
                print(f"[Bloqué] Status {r.status_code} pour {url}")
                time.sleep(1)
            else:
                print(f"[HTTP {r.status_code}] {url}")
        except Exception as e:
            last_error = e
            wait_time = 2 ** attempt
            print(f"[Tentative {attempt+1}/{retries}] Erreur: {e} — retry dans {wait_time}s")
            time.sleep(wait_time)
    if last_error:
        print(f"Error fetching JSON: {last_error}")
    return None

def fetch_json(url):
    return fetch_json_fast(url)

# =======================================================
# AUTOMATISATION INITIALISATION 2022 (LIEN MAÎTRE GLOBAL)
# =======================================================

WC2022_ENDPOINTS = {
    "info": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/info",
    "venues": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/venues",
    "cuptree": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/cuptrees",
    "top_players": f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/top-players/goals",
}

def initialize_wc2022_data():
    """Télécharge et vérifie l'intégralité des 64 matchs, groupes et bracket avec vérification absolue."""
    essential_files = ["info.json", "venues.json", "standings.json", "cuptree.json", "fixtures.json"]
    fixtures_path = os.path.join(WC2022_DIR, "fixtures.json")

    # Vérification d'intégrité : On ne skip que si on a bien les 64 matches
    if all(os.path.exists(os.path.join(WC2022_DIR, f)) for f in essential_files):
        try:
            with open(fixtures_path, 'r', encoding='utf-8') as f:
                current_data = json.load(f)
                matches = current_data.get('response', []) if isinstance(current_data, dict) else current_data
                if len(matches) >= 64:
                    print(f"Base de données locale Mundialy 2022 déjà complète ({len(matches)} matchs).")
                    return
        except Exception:
            pass

    print("Démarrage de la collecte exhaustive WC2022 (Groupes + Knockout)...")
    # 1. Métadonnées & Bracket
    for key, url in WC2022_ENDPOINTS.items():
        data = fetch_json(url)
        if data:
            with open(os.path.join(WC2022_DIR, f"{key}.json"), 'w', encoding='utf-8') as f:
                # Enveloppé pour Flutter
                json.dump({"response": data}, f, indent=4)

    # 2. Standings (Classement des Groupes) - LIEN ABSOLU & FORMATAGE FLUTTER
    url_st = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2022}/standings/total"
    st_data = fetch_json(url_st)
    if st_data and 'standings' in st_data:
        all_groups_list = []
        for group_data in st_data['standings']:
            g_name = group_data.get('name', 'Group')
            teams = []
            for r in group_data.get('rows', []):
                t = r.get('team', {})
                teams.append({
                    "rank": r.get('position'),
                    "group": g_name,
                    "team": {
                        "id": t.get('id'),
                        "name": t.get('name'),
                        "logo": f"https://api.sofascore.app/api/v1/team/{t.get('id')}/image"
                    },
                    "points": r.get('points', 0),
                    "goalsDiff": r.get('goalsFor', 0) - r.get('goalsAgainst', 0),
                    "all": {
                        "played": r.get('matches', 0),
                        "win": r.get('wins', 0),
                        "draw": r.get('draws', 0),
                        "lose": r.get('losses', 0)
                    }
                })
            all_groups_list.append(teams)

        # Structure finale harmonisée avec 2026 pour le parsing Flutter
        final_standings = {
            "response": [
                {
                    "league": {
                        "id": UT_ID,
                        "name": "World Cup 2022",
                        "standings": all_groups_list
                    }
                }
            ]
        }
        with open(os.path.join(WC2022_DIR, "standings.json"), 'w', encoding='utf-8') as f:
            json.dump(final_standings, f, indent=4)
        print(f"Classements 2022 formatés avec succès ({len(all_groups_list)} groupes).")

    # 3. Collecte de TOUS les matches (Groupes Round 1-3 + Knockout)
    all_matches_dict = {}

    # Sources spécifiques pour garantir l'absence de régression
    sources = [
        (f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/events/round/1", "Group Stage J1"),
        (f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/events/round/2", "Group Stage J2"),
        (f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/events/round/3", "Group Stage J3"),
        (f"{SOFA_BASE_URL}/unique-tournament/16/season/41087/events/last/0", "Knockout")
    ]

    # On utilise le domaine .app pour les images (plus performant pour le cache mobile)
    IMG_BASE = "https://api.sofascore.app/api/v1/team"

    for url, phase_label in sources:
        data = fetch_json(url)
        if data and 'events' in data:
            for e in data['events']:
                m_id = e['id']
                if m_id not in all_matches_dict:
                    tour_name = e.get('tournament', {}).get('name', '')

                    # LOGIQUE DE SÉCURITÉ (Votre analyse) : Filtrage selon tournament.name pour éviter le conflit Round 1
                    if "Group Stage" in phase_label and "Knockout" in tour_name:
                        continue # On ignore les huitièmes qui se glisseraient dans le Round 1 des groupes

                    h_s, a_s = e.get('homeScore', {}), e.get('awayScore', {})

                    # Détermination propre du Round : si c'est un groupe, on force notre label propre
                    # sinon on utilise le nom SofaScore (pour les 8èmes, Quarts, etc.)
                    r_name = e.get('roundInfo', {}).get('name', 'Match')
                    if "Group Stage" in phase_label:
                        r_name = phase_label

                    all_matches_dict[m_id] = {
                        "fixture": {
                            "id": m_id,
                            "date": datetime.datetime.fromtimestamp(e['startTimestamp']).isoformat(),
                            "status": {"short": "FT", "long": "Finished"}
                        },
                        "league": {"round": r_name},
                        "teams": {
                            "home": {"id": e['homeTeam']['id'], "name": e['homeTeam']['name'], "logo": f"{IMG_BASE}/{e['homeTeam']['id']}/image"},
                            "away": {"id": e['awayTeam']['id'], "name": e['awayTeam']['name'], "logo": f"{IMG_BASE}/{e['awayTeam']['id']}/image"}
                        },
                        "goals": {"home": h_s.get('display', 0), "away": a_s.get('display', 0)},
                        "score": {
                            "fulltime": {"home": h_s.get('display', 0), "away": a_s.get('display', 0)},
                            "penalty": {"home": h_s.get('penalties'), "away": h_s.get('penalties')}
                        }
                    }

    # =======================================================
    # TEST DE RÉGRESSION & VÉRIFICATION ABSOLUE
    # =======================================================
    final_list = list(all_matches_dict.values())
    final_list.sort(key=lambda x: x['fixture']['date'])

    # Décompte précis pour validation
    group_matches = [m for m in final_list if "Group Stage" in m['league']['round']]
    knockout_matches = [m for m in final_list if "Group Stage" not in m['league']['round']]


    print(f"Matches de Groupes (J1+J2+J3) : {len(group_matches)} / 48")
    print(f"Matches de Phase Finale (Knockout) : {len(knockout_matches)} / 16")
    print(f"TOTAL GLOBAL : {len(final_list)} / 64")

    if len(final_list) >= 64:
        print("TEST RÉUSSI : L'intégralité du tournoi est sécurisée.")
    else:
        print("ALERTE : Données incomplètes. Vérifiez la connexion SofaScore.")

    with open(fixtures_path, 'w', encoding='utf-8') as f:
        json.dump({"response": final_list}, f, indent=4)

    print(f"Fichier fixtures.json généré avec succès.")
    print("Fin de l'initialisation de l'archive 2022.")

# =======================================================
# ROUTES API SECURISEES (RETOURS EXCLUSIVEMENT EN JSON)
# =======================================================

@app.route('/api/wc2022/<string:resource>', methods=['GET'])
def get_wc2022_resource(resource):
    """Route générique sécurisée contre l'envoi de HTML brut."""
    path = os.path.join(WC2022_DIR, f"{resource}.json")
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # Compatibilité absolue : si c'est déjà enveloppé on renvoie tel quel,
            # sinon on enveloppe dans 'response' pour le Flutter ApiService
            if isinstance(data, dict) and 'response' in data:
                return jsonify(data)
            return jsonify({"response": data})
    return jsonify({"error": f"Ressource {resource} introuvable", "status": 404}), 404

@app.route('/api/fixtures', methods=['GET'])
def get_fixtures():
    season = request.args.get('season')
    if season == '2022':
        return get_wc2022_resource("fixtures")

    # Logique Direct / Prochains Matchs 2026 (TTL 30s pour live)
    filepath = os.path.join(DATA_DIR, "wc2026_fixtures.json")
    if os.path.exists(filepath) and (time.time() - os.path.getmtime(filepath)) < 30:
        with open(filepath, 'r', encoding='utf-8') as f:
            return jsonify({"response": json.load(f)})

    try:
        # Fetch all group rounds and last/next events for full coverage
        all_events = {}
        endpoints = [
            "events/round/1", "events/round/2", "events/round/3",
            "events/last/0", "events/next/0"
        ]
        for endpoint in endpoints:
            url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/{endpoint}"
            data = fetch_json(url)
            if data and 'events' in data:
                for ev in data['events']:
                    all_events[ev['id']] = ev  # Deduplicate by event ID

        if not all_events:
            return jsonify({"response": []})

        formatted = []
        now_ts = int(time.time())
        for e in all_events.values():
            status = e.get('status', {})
            status_type = status.get('type', '')

            # Determine short status
            if status_type == 'inprogress':
                short = 'LIVE'
            elif status_type == 'finished':
                short = 'FT'
            else:
                short = 'NS'

            # Calculate elapsed minutes for live matches
            elapsed = None
            if short == 'LIVE':
                period_start = e.get('time', {}).get('currentPeriodStartTimestamp')
                if period_start:
                    elapsed = (now_ts - period_start) // 60
                desc = status.get('description', '')
                if desc and elapsed is None:
                    elapsed = desc  # SofaScore often puts "45'" etc. here

            # Round / phase label — format identique à 2022: "Group Stage - 1", "Group Stage - 2", etc.
            round_name = e.get('roundInfo', {}).get('name') or e.get('tournament', {}).get('name', '')
            group_label = ''
            if e.get('tournament', {}).get('isGroup'):
                group_label = e.get('tournament', {}).get('groupName', '')
                round_num = e.get('roundInfo', {}).get('round', '')
                if round_num:
                    round_name = f"Group Stage - {round_num}"
                else:
                    round_name = "Group Stage"

            formatted.append({
                "fixture": {
                    "id": e['id'],
                    "timestamp": e['startTimestamp'],
                    "date": datetime.datetime.fromtimestamp(e['startTimestamp']).isoformat(),
                    "status": {
                        "short": short,
                        "long": status.get('description', ''),
                        "elapsed": elapsed
                    }
                },
                "league": {
                    "round": round_name,
                    "group": group_label
                },
                "teams": {
                    "home": {"id": e['homeTeam']['id'], "name": e['homeTeam']['name'], "logo": f"https://api.sofascore.app/api/v1/team/{e['homeTeam']['id']}/image"},
                    "away": {"id": e['awayTeam']['id'], "name": e['awayTeam']['name'], "logo": f"https://api.sofascore.app/api/v1/team/{e['awayTeam']['id']}/image"}
                },
                "goals": {
                    "home": e.get('homeScore', {}).get('current'),
                    "away": e.get('awayScore', {}).get('current')
                },
                "score": {
                    "penalty": {
                        "home": e.get('homeScore', {}).get('penalties'),
                        "away": e.get('awayScore', {}).get('penalties')
                    }
                },
                "stream_url": IPTV_STREAM_URL
            })

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(formatted, f, indent=4)
        return jsonify({"response": formatted})
    except Exception as e:
        print(f"Error in /api/fixtures: {e}")
        return jsonify({"response": []})

@app.route('/api/standings', methods=['GET'])
def get_standings():
    season = request.args.get('season')
    if season == '2022':
        return get_wc2022_resource("standings")

    # Logique Classement 2026
    try:
        url_g = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/groups"
        groups_raw = fetch_json(url_g)
        if not groups_raw or 'groups' not in groups_raw:
            return jsonify({"response": []})
        all_s = []
        for g in groups_raw.get('groups', []):
            tid = g.get('tournamentId')
            if not tid: continue
            url_s = f"{SOFA_BASE_URL}/tournament/{tid}/season/{S_ID_2026}/standings/total"
            data = fetch_json(url_s)
            if data and data.get('standings'):
                teams = []
                for r in data['standings'][0].get('rows', []):
                    t = r.get('team', {})
                    teams.append({"rank": r.get('position'), "group": g.get('groupName'), "team": {"id": t.get('id'), "name": t.get('name'), "logo": f"https://api.sofascore.app/api/v1/team/{t.get('id')}/image"}, "points": r.get('points', 0), "goalsDiff": r.get('goalsFor', 0) - r.get('goalsAgainst', 0), "all": {"played": r.get('matches', 0), "win": r.get('wins', 0), "draw": r.get('draws', 0), "lose": r.get('losses', 0)}})
                all_s.append(teams)
        res = {"response": [{"league": {"id": UT_ID, "name": "World Cup 2026", "standings": all_s}}]}
        return jsonify(res)
    except Exception as e:
        print(f"/api/standings error: {e}")
        return jsonify({"response": []})

# Cache pour la route Live
LIVE_CACHE = {
    "timestamp": 0,
    "data": []
}

PREVIOUS_SCORES = {}

def live_updater_loop():
    global LIVE_CACHE, PREVIOUS_SCORES
    last_scheduled_fetch = 0
    scheduled_data_cache = None

    while True:
        try:
            live_url = f"{SOFA_BASE_URL}/sport/football/events/live"
            live_data = fetch_json(live_url)
            
            # Fetch scheduled matches only once every 60 secondes pour éviter le blocage
            current_time = time.time()
            if current_time - last_scheduled_fetch > 60 or scheduled_data_cache is None:
                real_today = datetime.date.today().strftime("%Y-%m-%d")
                scheduled_url = f"{SOFA_BASE_URL}/sport/football/scheduled-events/{real_today}"
                scheduled_data_cache = fetch_json(scheduled_url)
                last_scheduled_fetch = current_time

            all_events = []
            if live_data and 'events' in live_data:
                all_events.extend(live_data['events'])

            if scheduled_data_cache and 'events' in scheduled_data_cache:
                live_ids = [ev.get('id') for ev in all_events]
                for sev in scheduled_data_cache['events']:
                    if sev.get('id') not in live_ids:
                        all_events.append(sev)

            filtered = []
            for e in all_events:
                if e.get('tournament', {}).get('name') != 'Int. Friendly Games':
                    continue

                status = e.get('status', {})
                status_type = status.get('type', '')
                is_live = status_type == 'inprogress'
                
                h_s = e.get('homeScore') or {}
                a_s = e.get('awayScore') or {}

                dt = datetime.datetime.fromtimestamp(e.get('startTimestamp', 0)).isoformat() if e.get('startTimestamp') else ""

                if status_type == 'finished':
                    short_status = 'FT'
                elif status_type == 'canceled':
                    short_status = 'CANC'
                elif status_type == 'postponed':
                    short_status = 'PST'
                elif is_live:
                    short_status = status.get('description', 'LIVE')
                else:
                    short_status = 'NS'

                current_home = h_s.get('current') if h_s.get('current') is not None else h_s.get('display')
                current_away = a_s.get('current') if a_s.get('current') is not None else a_s.get('display')
                
                m_id = str(e.get('id'))
                c_h = current_home if isinstance(current_home, int) else 0
                c_a = current_away if isinstance(current_away, int) else 0

                if m_id in PREVIOUS_SCORES:
                    prev = PREVIOUS_SCORES[m_id]
                    ht_name = e.get('homeTeam', {}).get('name', 'Home')
                    at_name = e.get('awayTeam', {}).get('name', 'Away')
                    ht_code = e.get('homeTeam', {}).get('nameCode', '')
                    at_code = e.get('awayTeam', {}).get('nameCode', '')
                    
                    title = None
                    body = None
                    push_data = {'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'type': 'event'}
                    
                    # 1. Vérification des buts
                    if c_h > prev['home'] or c_a > prev['away']:
                        title = '⚽ BUT !!!'
                        body = f"{ht_name} {c_h} - {c_a} {at_name}"
                        push_data['type'] = 'goal'
                        push_data['homeTeamName'] = ht_name
                        push_data['awayTeamName'] = at_name
                        push_data['homeScore'] = str(c_h)
                        push_data['awayScore'] = str(c_a)
                        
                        # Fetch incidents to get goal details
                        incident_data = fetch_json(f"{SOFA_BASE_URL}/event/{m_id}/incidents")
                        scorer_name = "Buteur inconnu"
                        minute = ""
                        is_penalty = "false"
                        scoring_team = ""
                        scoring_code = ""
                        
                        if incident_data and 'incidents' in incident_data:
                            for inc in incident_data['incidents']:
                                if inc.get('incidentType') == 'goal':
                                    scorer_name = inc.get('player', {}).get('name', 'Buteur')
                                    minute = str(inc.get('time', ''))
                                    is_penalty = "true" if inc.get('incidentClass') == 'penalty' else "false"
                                    is_home = inc.get('isHome', False)
                                    scoring_team = "home" if is_home else "away"
                                    scoring_code = ht_code if is_home else at_code
                                    break # On prend le plus récent (les incidents sont souvent triés du plus récent au plus ancien, ou l'inverse, mais on peut juste chercher celui qui a amené au score actuel)
                                    # Pour plus de sécurité on peut chercher l'incident qui a les mêmes scores, mais SofaScore renvoie les plus récents en premier.
                        
                        push_data['scorerName'] = scorer_name
                        push_data['minute'] = minute
                        push_data['isPenalty'] = is_penalty
                        push_data['scoringTeam'] = scoring_team
                        push_data['scoringTeamCode'] = scoring_code

                    elif c_h < prev['home'] or c_a < prev['away']:
                        title = '❌ BUT ANNULÉ'
                        body = f"Retour au score : {ht_name} {c_h} - {c_a} {at_name}"
                        push_data['type'] = 'goal_cancelled'
                        
                    # 2. Vérification des changements d'état du match (si pas de but détecté en même temps)
                    if not title:
                        prev_type = prev.get('status_type', '')
                        prev_short = prev.get('short_status', '')
                        
                        if prev_type == 'notstarted' and status_type == 'inprogress':
                            title = '🟢 Le match commence !'
                            body = f"{ht_name} vs {at_name}"
                        elif prev_type != 'finished' and status_type == 'finished':
                            title = '🏁 Match Terminé (FT)'
                            body = f"Score final : {ht_name} {c_h} - {c_a} {at_name}"
                        elif prev_short != 'Halftime' and short_status == 'Halftime':
                            title = '⏱️ Mi-temps'
                            body = f"{ht_name} {c_h} - {c_a} {at_name}"
                        elif prev_short != short_status and ('Penalty' in short_status or 'Penalties' in short_status):
                            title = '❗ Penalty !'
                            body = f"Moment décisif pour {ht_name} vs {at_name}"

                    if title and body:
                        try:
                            msg = messaging.Message(
                                notification=messaging.Notification(title=title, body=body),
                                topic='live_matches',
                                data=push_data
                            )
                            messaging.send(msg)
                            print(f"Push envoyée: {title} {body}")
                        except Exception as ex:
                            print(f"FCM Erreur: {ex}")
                            
                PREVIOUS_SCORES[m_id] = {
                    'home': c_h, 
                    'away': c_a, 
                    'status_type': status_type, 
                    'short_status': short_status
                }

                filtered.append({
                    "fixture": {
                        "id": e.get('id'),
                        "date": dt,
                        "status": {
                            "short": short_status,
                            "long": status.get('description', ''),
                            "type": status_type,
                            "code": status.get('code'),
                            "elapsed": status.get('currentMinute')
                        },
                        "time": e.get('time', {}) if is_live else {}
                    },
                    "league": {
                        "round": e.get('tournament', {}).get('name', 'Match'),
                        "group": ""
                    },
                    "teams": {
                        "home": {
                            "id": e.get('homeTeam', {}).get('id'),
                            "name": e.get('homeTeam', {}).get('name'),
                            "logo": f"https://api.sofascore.app/api/v1/team/{e.get('homeTeam', {}).get('id')}/image"
                        },
                        "away": {
                            "id": e.get('awayTeam', {}).get('id'),
                            "name": e.get('awayTeam', {}).get('name'),
                            "logo": f"https://api.sofascore.app/api/v1/team/{e.get('awayTeam', {}).get('id')}/image"
                        }
                    },
                    "goals": {
                        "home": current_home,
                        "away": current_away
                    },
                    "is_live": is_live
                })
            
            LIVE_CACHE["data"] = filtered
            LIVE_CACHE["timestamp"] = time.time()
        except Exception as loop_ex:
            print(f"Error in background loop iteration: {loop_ex}")

        time.sleep(15)

bg_thread = threading.Thread(target=live_updater_loop, daemon=True)
bg_thread.start()

@app.route('/api/worldcup/live', methods=['GET'])
def get_live_worldcup():
    return jsonify({"response": LIVE_CACHE["data"]})

# ---- ROUTE DYNAMIQUE : DÉTAILS COMPLETS DU MATCH (STRATÉGIE BFF RADICALE) ----
@app.route('/api/match/<int:match_id>', methods=['GET'])
def get_match_full_details(match_id):
    """BFF : Nettoyeur SofaScore vers Mundialy UI — v2 avec données complètes."""
    # Check WC2022 permanent cache first
    cache_path_2022 = os.path.join(WC2022_DIR, f"match_full_{match_id}.json")
    if os.path.exists(cache_path_2022):
        with open(cache_path_2022, 'r', encoding='utf-8') as f:
            return jsonify(json.load(f))

    # Check WC2026 cache (short TTL for live, permanent for finished)
    cache_path_2026 = os.path.join(WC2026_DIR, f"match_full_{match_id}.json")
    if os.path.exists(cache_path_2026):
        with open(cache_path_2026, 'r', encoding='utf-8') as f:
            cached = json.load(f)
            status_type = cached.get('response', {}).get('event', {}).get('status', {}).get('type', '')
            if status_type == 'finished':
                return jsonify(cached)  # Permanent cache for finished matches
            elif (time.time() - os.path.getmtime(cache_path_2026)) < 20:
                return jsonify(cached)  # 20s cache for live/upcoming

    try:
        # 1. RÉCUPÉRATION DES SOURCES BRUTES
        raw_e = fetch_json(f"{SOFA_BASE_URL}/event/{match_id}") or {}
        raw_l = fetch_json(f"{SOFA_BASE_URL}/event/{match_id}/lineups") or {}
        raw_s = fetch_json(f"{SOFA_BASE_URL}/event/{match_id}/statistics") or {}
        raw_i = fetch_json(f"{SOFA_BASE_URL}/event/{match_id}/incidents") or {}

        event_raw = raw_e.get('event', {}) if raw_e else {}
        home_team_raw = event_raw.get('homeTeam', {})
        away_team_raw = event_raw.get('awayTeam', {})

        # 2. NORMALISATION DU SCORE
        h_s = event_raw.get('homeScore', {})
        a_s = event_raw.get('awayScore', {})
        score_h = h_s.get('display', 0) if h_s.get('display') is not None else 0
        score_a = a_s.get('display', 0) if a_s.get('display') is not None else 0

        # 3. EXTRACTION DES COULEURS DE MAILLOTS depuis incidents (pour le pitch)
        inc_colors = raw_i if isinstance(raw_i, dict) else {}
        home_kit_color = "660000"  # fallback
        away_kit_color = "003399"  # fallback
        if inc_colors.get('home', {}).get('playerColor', {}).get('primary'):
            home_kit_color = inc_colors['home']['playerColor']['primary']
        if inc_colors.get('away', {}).get('playerColor', {}).get('primary'):
            away_kit_color = inc_colors['away']['playerColor']['primary']

        # 4. NORMALISATION DES LINEUPS avec noms, numéros, positions
        def map_lineup(side):
            data = raw_l.get(side, {})
            players = data.get('players', [])
            starters = []
            subs = []
            for p in players:
                pl = p.get('player', {})
                entry = {
                    "player": {
                        "id": pl.get('id', 0),
                        "name": pl.get('shortName') or pl.get('name', 'Joueur'),
                        "number": p.get('shirtNumber') or p.get('jerseyNumber', 0),
                        "pos": p.get('position', ''),
                    }
                }
                if not p.get('substitute', False):
                    starters.append(entry)
                else:
                    subs.append(entry)

            # Coach depuis l'event (homeTeam.manager / awayTeam.manager)
            team_data = home_team_raw if side == 'home' else away_team_raw
            manager_name = ''
            mgr = team_data.get('manager', {})
            if mgr:
                manager_name = mgr.get('name', '')

            return {
                "team": {
                    "id": team_data.get('id'),
                    "name": team_data.get('name', ''),
                    "nameCode": team_data.get('nameCode', ''),
                },
                "formation": data.get('formation', 'N/A'),
                "coach": {"name": manager_name},
                "startXI": starters,
                "substitutes": subs
            }

        clean_lineups = {
            "home": map_lineup('home'),
            "away": map_lineup('away')
        }

        # 5. NORMALISATION DES INCIDENTS (Noms, minutes, types)
        clean_incidents = []
        for inc in (raw_i.get('incidents', []) if isinstance(raw_i, dict) else []):
            i_type = inc.get('incidentType')
            if i_type not in ["goal", "substitution", "card", "varDecision", "injuryTime", "penaltyShootout"]:
                continue

            time_val = inc.get('time', 0)
            added = inc.get('addedTime')
            
            if i_type == "penaltyShootout":
                display_time = "TAB"
            else:
                display_time = f"{time_val}'"
                if added:
                    display_time = f"{time_val}+{added}'"

            item = {
                "time": time_val,
                "addedTime": added,
                "displayTime": display_time,
                "incidentType": i_type,
                "incidentClass": inc.get('incidentClass', ''),
                "homeScore": inc.get('homeScore'),
                "awayScore": inc.get('awayScore'),
                "isHome": inc.get('isHome'),
                "length": inc.get('length'),
                "sequence": inc.get('sequence'),
            }

            if i_type == "substitution":
                p_in = inc.get('playerIn', {})
                p_out = inc.get('playerOut', {})
                item["playerIn"] = {
                    "id": p_in.get('id', 0),
                    "name": p_in.get('shortName') or p_in.get('name', 'Entrant'),
                }
                item["playerOut"] = {
                    "id": p_out.get('id', 0),
                    "name": p_out.get('shortName') or p_out.get('name', 'Sortant'),
                }
            elif i_type == "card":
                pl = inc.get('player', {})
                item["player"] = {
                    "id": pl.get('id', 0),
                    "name": pl.get('shortName') or pl.get('name') or inc.get('playerName', 'Joueur'),
                }
                item["reason"] = inc.get('reason', '')
            elif i_type == "goal" or i_type == "penaltyShootout":
                pl = inc.get('player', {})
                item["player"] = {
                    "id": pl.get('id', 0),
                    "name": pl.get('shortName') or pl.get('name', 'Joueur'),
                }
                item["from"] = inc.get('from', '')
                # Assist
                assist_pl = inc.get('assist1', {})
                if assist_pl:
                    item["assist"] = {
                        "id": assist_pl.get('id', 0),
                        "name": assist_pl.get('shortName') or assist_pl.get('name', ''),
                    }
            elif i_type == "varDecision":
                pl = inc.get('player', {})
                item["player"] = {
                    "id": pl.get('id', 0),
                    "name": pl.get('shortName') or pl.get('name', 'Joueur'),
                }

            clean_incidents.append(item)

        # Trier par temps croissant (les TAB iront à la fin car sequence est utilisé)
        clean_incidents.sort(key=lambda x: (x.get('time', 0), x.get('addedTime') or 0, x.get('sequence') or 0))

        # 6. VENUE propre
        venue_raw = event_raw.get('venue', {})
        venue_name = venue_raw.get('name') or venue_raw.get('stadium', {}).get('name', 'Stadium')
        venue_city = venue_raw.get('city', {}).get('name', '') if isinstance(venue_raw.get('city'), dict) else str(venue_raw.get('city', ''))
        venue_capacity = venue_raw.get('capacity') or venue_raw.get('stadium', {}).get('capacity', '')

        # 7. REFEREE propre
        ref_raw = event_raw.get('referee', {})
        ref_name = ref_raw.get('name', '') if ref_raw else ''
        ref_country = ref_raw.get('country', {}).get('name', '') if ref_raw else ''

        # 8. RÉPONSE BFF FINALE
        IMG_BASE = "https://api.sofascore.app/api/v1/team"
        full_details = {
            "response": {
                "event": {
                    "id": match_id,
                    "homeTeam": {
                        "id": home_team_raw.get('id'),
                        "name": home_team_raw.get('name', 'Home'),
                        "nameCode": home_team_raw.get('nameCode', ''),
                        "logo": f"{IMG_BASE}/{home_team_raw.get('id')}/image",
                    },
                    "awayTeam": {
                        "id": away_team_raw.get('id'),
                        "name": away_team_raw.get('name', 'Away'),
                        "nameCode": away_team_raw.get('nameCode', ''),
                        "logo": f"{IMG_BASE}/{away_team_raw.get('id')}/image",
                    },
                    "homeScore": {"current": score_h, "penalties": h_s.get('penalties')},
                    "awayScore": {"current": score_a, "penalties": a_s.get('penalties')},
                    "winnerCode": event_raw.get('winnerCode'),
                    "status": event_raw.get('status', {"description": "Terminé", "type": "finished"}),
                    "startTimestamp": event_raw.get('startTimestamp', 0),
                },
                "venue": {
                    "name": venue_name,
                    "city": venue_city,
                    "capacity": str(venue_capacity) if venue_capacity else '',
                },
                "referee": {
                    "name": ref_name,
                    "country": ref_country,
                },
                "managers": {
                    "home": {"name": home_team_raw.get('manager', {}).get('name', '') if home_team_raw.get('manager') else ''},
                    "away": {"name": away_team_raw.get('manager', {}).get('name', '') if away_team_raw.get('manager') else ''},
                },
                "lineups": clean_lineups,
                "statistics": raw_s.get('statistics', []),
                "incidents": clean_incidents,
                "kitColors": {
                    "home": home_kit_color,
                    "away": away_kit_color,
                },
            }
        }

        # Save cache: use WC2022 dir only for known 2022 matches, otherwise WC2026
        cache_path = cache_path_2026
        with open(cache_path, 'w', encoding='utf-8') as f:
            json.dump(full_details, f, indent=4, ensure_ascii=False)

        return jsonify(full_details)
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Erreur Critique BFF : {e}")
        return jsonify({"error": str(e)}), 500

# ---- ROUTE SECONDAIRE POUR STATS (ANCIENNE COMPATIBILITÉ) ----
@app.route('/api/match/<int:match_id>/details', methods=['GET'])
def get_match_statistics_legacy(match_id):
    return get_match_full_details(match_id)

# ---- ROUTE DYNAMIQUE : STATISTIQUES DES ÉQUIPES (NATIONS) ----
@app.route('/api/team/<int:team_id>/stats', methods=['GET'])
def get_team_statistics(team_id):
    season = request.args.get('season', '2022')
    s_id = S_ID_2026 if season == '2026' else S_ID_2022
    target_dir = WC2026_DIR if season == '2026' else WC2022_DIR
    cache_path = os.path.join(target_dir, f"team_{team_id}.json")
    if os.path.exists(cache_path):
        with open(cache_path, 'r', encoding='utf-8') as f:
            return jsonify(json.load(f))

    try:
        url = f"{SOFA_BASE_URL}/team/{team_id}/statistics/unique-tournament/{UT_ID}/season/{s_id}/all"
        data = fetch_json(url)
        if data:
            with open(cache_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=4)
            return jsonify(data)
        return jsonify({"error": "Profil d'équipe indisponible"}), 404
    except Exception as e:
        return jsonify({"error": "Erreur serveur", "details": str(e)}), 500
    finally:
        if driver: driver.quit()

# ---- ROUTE : MEILLEURS BUTEURS (TOP SCORERS) ----
@app.route('/api/topscorers', methods=['GET'])
def get_topscorers():
    season = request.args.get('season', '2022')
    data = None

    if season == '2022':
        path = os.path.join(WC2022_DIR, "top_players.json")
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
    else:
        driver = None
        try:
            driver = init_selenium_driver()
            url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/top-players/goals"
            raw_data = fetch_json(driver, url)
            if raw_data:
                data = {"response": raw_data}
        except Exception as e:
            print("Error topscorers 2026:", e)
        finally:
            if driver: driver.quit()

    if data:
        # On extrait l'objet topPlayers
        top_data = data.get('response', {}).get('topPlayers', [])

        # Si top_data est une liste (cas de l'endpoint spécialisé /goals)
        if isinstance(top_data, list):
            raw_players = top_data
        # Si c'est un dictionnaire (cas de l'endpoint /overall)
        elif isinstance(top_data, dict):
            raw_players = top_data.get('goals') or top_data.get('rating') or []
        else:
            raw_players = []

        formatted_scorers = []
        for p in raw_players[:20]: # Top 20
            player = p.get('player', {})
            stats = p.get('statistics', {})
            formatted_scorers.append({
                "player": {
                    "id": player.get('id'),
                    "name": player.get('name')
                },
                "team": p.get('team', {}),
                "goals": stats.get('goals', 0),
                "assists": stats.get('assists', 0),
                "matches": stats.get('appearances', 0)
            })
        return jsonify({"response": formatted_scorers})
    
    return jsonify({"response": []})

@app.route('/api/venues', methods=['GET'])
def get_venues():
    season = request.args.get('season', '2022')
    if season == '2022':
        return get_wc2022_resource("venues")
    driver = None
    try:
        driver = init_selenium_driver()
        data = fetch_json(driver, f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/venues")
        return jsonify({"response": data}) if data else jsonify({"response": []})
    except:
        return jsonify({"response": []})
    finally:
        if driver: driver.quit()

@app.route('/api/cuptree', methods=['GET'])
def get_cuptree():
    season = request.args.get('season', '2022')
    if season == '2022':
        return get_wc2022_resource("cuptree")
    driver = None
    try:
        driver = init_selenium_driver()
        data = fetch_json(driver, f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/cuptrees")
        return jsonify({"response": data}) if data else jsonify({"response": []})
    except:
        return jsonify({"response": []})
    finally:
        if driver: driver.quit()

@app.route('/api/info', methods=['GET'])
def get_info():
    season = request.args.get('season', '2022')
    if season == '2022':
        return get_wc2022_resource("info")
    driver = None
    try:
        driver = init_selenium_driver()
        data = fetch_json(driver, f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/info")
        return jsonify({"response": data}) if data else jsonify({"response": {}})
    except:
        return jsonify({"response": {}})
    finally:
        if driver: driver.quit()

@app.route('/api/worldcup/news', methods=['GET'])
def get_news():
    team_filter = request.args.get('team', '').lower()
    url = "https://cxm-api.fifa.com/fifaplusweb/api/sections/news/FaumbRZruNFhWXbDW1INW?locale=en&limit=30"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        res = urllib.request.urlopen(req).read().decode('utf-8')
        data = json.loads(res)
        
        formatted_news = []
        for item in data.get('items', []):
            # Check team filter
            if team_filter:
                match = False
                if team_filter in item.get('title', '').lower():
                    match = True
                for tag in item.get('semanticTags', []):
                    if tag.get('sourceCategory') in ['Country', 'Team', 'Association']:
                        if team_filter in tag.get('title', '').lower():
                            match = True
                            break
                if not match:
                    continue

            img_src = None
            if 'image' in item and 'src' in item['image']:
                img_src = item['image']['src']

            url_path = item.get('articlePageUrl', '')
            if url_path and not url_path.startswith('http'):
                url_path = "https://www.fifa.com" + url_path
            
            formatted_news.append({
                "title": item.get('title', ''),
                "url": url_path,
                "img": img_src,
                "source": item.get('roofline') or "FIFA.com",
                "date": item.get('publishedDate', '')
            })
            
        return jsonify(formatted_news)
    except Exception as e:
        print("Error fetching news:", e)
        return jsonify([])

if __name__ == '__main__':
    initialize_wc2022_data()
    app.run(host='0.0.0.0', port=5000, debug=False)
