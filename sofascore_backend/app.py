import os
import time
import json
import datetime
import urllib.request
import urllib.parse
import threading
import firebase_admin
from firebase_admin import credentials, messaging
from flask import Flask, jsonify, request

app = Flask(__name__)

# Firebase admin initialization
try:
    firebase_creds = os.environ.get('FIREBASE_CREDENTIALS')
    if firebase_creds:
        cred_dict = json.loads(firebase_creds)
        cred = credentials.Certificate(cred_dict)
    else:
        cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin initialized successfully.")
except Exception as e:
    print(f"Firebase Init Error: {e}")

@app.route('/')
def home():
    return jsonify({"status": "ok", "message": "Mundialy API is running!"}), 200

@app.route('/health')
def health():
    return jsonify({"status": "ok"}), 200

# --- CONFIGURATION ---
IPTV_STREAM_URL = "https://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8"
UT_ID = 16
S_ID_2026 = 58210
S_ID_2022 = 41087
SOFA_BASE_URL = "https://api.sofascore.com/api/v1"
SCORES365_BASE_URL = "https://webws.365scores.com/web"
SCORES365_COMPETITION_ID = 5930
SCORES365_SEASON_NUM = 25
SCORES365_LANG_ID = os.environ.get("SCORES365_LANG_ID", "1")
SCORES365_APP_TYPE_ID = os.environ.get("SCORES365_APP_TYPE_ID", "5")
SCORES365_TIMEZONE = os.environ.get("SCORES365_TIMEZONE", "Europe/Paris")
SCORES365_START_DATE = "11/06/2026"
SCORES365_END_DATE = "19/07/2026"

# Global state for server-side polling
_SERVER_MATCH_STATES = {}
_SERVER_PROCESSED_EVENTS = set()

DATA_DIR = "data"
WC2022_DIR = os.path.join(DATA_DIR, "wc2022")
WC2026_DIR = os.path.join(DATA_DIR, "wc2026")

# Fichier de statut pour la communication entre processus (Gunicorn)
STATUS_FILE = os.path.join(DATA_DIR, "polling_status.json")

def _update_status(status_dict):
    """Écrit le statut dans un fichier pour qu'il soit partagé entre tous les workers Gunicorn."""
    try:
        with open(STATUS_FILE, "w") as f:
            json.dump(status_dict, f)
    except: pass

def _get_status():
    """Lit le statut depuis le fichier partagé."""
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, "r") as f:
                return json.load(f)
        except: pass
    return {"last_check": "Jamais", "status": "Initialisation", "games_found": 0, "api_response": "Aucune"}

# État du dernier fetch pour le diagnostic
_LAST_POLLING_STATUS = {
    "last_check": "Jamais",
    "status": "Initialisation",
    "games_found": 0,
    "api_response": "Aucune"
}

# Création automatique des répertoires pour le stockage local (Cache)
for d in [DATA_DIR, WC2022_DIR, WC2026_DIR]:
    if not os.path.exists(d):
        os.makedirs(d)

from curl_cffi import requests as cffi_requests
import random

# Profils d'impersonation robustes pour bypass Cloudflare
_PROFILES = [
    {"impersonate": "chrome124", "ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"},
    {"impersonate": "safari_ios", "ua": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"},
    {"impersonate": "safari17_0", "ua": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"},
    {"impersonate": "chrome120", "ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
]

# Headers de base
_SOFA_HEADERS = {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'fr-FR,fr;q=0.9',
}

def fetch_json_fast(url, retries=3, base_timeout=10):
    """
    MIRACLE FETCH: Utilise urllib (comme pour les news) pour contourner Cloudflare sur Render.
    """
    import ssl
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "fr-FR,fr;q=0.9",
    }
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=base_timeout, context=ctx) as response:
                if response.status == 200:
                    raw_data = response.read().decode('utf-8')
                    return json.loads(raw_data)
        except Exception as e:
            print(f"⚠️ Erreur fetch_json_fast (tentative {attempt+1}): {e}")
            time.sleep(2 ** attempt)
    return None

def fetch_json(url):
    return fetch_json_fast(url)

def fetch_365_json(path, params=None, retries=3, base_timeout=12):
    """
    MIRACLE FETCH 365: Utilise urllib pour garantir la compatibilité Render.
    """
    import ssl
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    params = params or {}
    defaults = {
        "appTypeId": SCORES365_APP_TYPE_ID,
        "langId": SCORES365_LANG_ID,
        "timezoneName": SCORES365_TIMEZONE,
    }
    query = defaults | params
    qs = urllib.parse.urlencode(query)
    url = f"{SCORES365_BASE_URL}/{path.lstrip('/')}?{qs}"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Origin": "https://www.365scores.com",
        "Referer": "https://www.365scores.com/",
    }

    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=base_timeout, context=ctx) as response:
                if response.status == 200:
                    raw_data = response.read().decode('utf-8')
                    return json.loads(raw_data)
        except Exception as e:
            print(f"⚠️ Erreur fetch_365_json (tentative {attempt+1}): {e}")
            time.sleep(2 ** attempt)
    return None

def _safe_int(value, default=0):
    try:
        if value is None:
            return default
        return int(float(value))
    except (TypeError, ValueError):
        return default

def _score_or_none(value):
    if value is None:
        return None
    try:
        numeric = int(float(value))
        return numeric if numeric >= 0 else None
    except (TypeError, ValueError):
        return None

def _parse_365_datetime(value):
    if not value:
        return None
    try:
        return datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None

def _team_code_365(team):
    return str(team.get("symbolicName") or team.get("nameForURL") or team.get("id") or "TBD").upper()

def _team_logo_365(team_id, size=96):
    if not team_id:
        return None
    return f"https://imagecache.365scores.com/image/upload/f_png,w_{size},h_{size},c_limit,q_auto:eco,dpr_2,d_Competitors:default1.png/Competitors/{team_id}"

def _player_image_365(athlete_id, size=96):
    if not athlete_id:
        return None
    return f"https://imagecache.365scores.com/image/upload/f_png,w_{size},h_{size},c_limit,q_auto:eco,dpr_2,d_Athletes:default.png/Athletes/{athlete_id}"

def _phase_label_365(game):
    group = game.get("groupName") or ""
    stage_num = _safe_int(game.get("stageNum"), 1)
    round_num = game.get("roundNum")
    round_name = game.get("roundName") or ""
    if stage_num == 1:
        return f"Group Stage - {round_num}" if round_num else "Group Stage"
    if stage_num == 2:
        return "Round of 32"
    if stage_num == 3:
        return "Round of 16"
    if stage_num == 4:
        return "Quarter-finals"
    if stage_num == 5:
        return "Semi-finals"
    if stage_num == 6:
        return "Final"
    return round_name or group or "World Cup"

def _status_365(game):
    status_group = _safe_int(game.get("statusGroup"), 0)
    status_text = game.get("statusText") or game.get("shortStatusText") or ""
    game_time = game.get("gameTime")
    if status_group == 3:
        short = "LIVE"
    elif status_group == 4:
        short = "FT"
    else:
        short = "NS"
    elapsed = None
    if short == "LIVE":
        elapsed = _safe_int(game_time, 0) if game_time not in [None, -1, -1.0] else None
    return {"short": short, "long": status_text, "elapsed": elapsed}

def _normalize_365_game(game):
    home = game.get("homeCompetitor") or {}
    away = game.get("awayCompetitor") or {}
    dt = _parse_365_datetime(game.get("startTime"))
    timestamp = int(dt.timestamp()) if dt else 0
    return {
        "fixture": {
            "id": game.get("id"),
            "timestamp": timestamp,
            "date": dt.isoformat() if dt else "",
            "status": _status_365(game),
            "venue": {
                "name": (game.get("venue") or {}).get("name"),
                "city": (game.get("venue") or {}).get("city"),
            },
        },
        "league": {
            "round": _phase_label_365(game),
            "group": game.get("groupName") or "",
            "stageNum": game.get("stageNum"),
            "roundNum": game.get("roundNum"),
        },
        "teams": {
            "home": {
                "id": home.get("id"),
                "name": home.get("name") or "TBD",
                "code": _team_code_365(home),
                "logo": _team_logo_365(home.get("id")),
            },
            "away": {
                "id": away.get("id"),
                "name": away.get("name") or "TBD",
                "code": _team_code_365(away),
                "logo": _team_logo_365(away.get("id")),
            },
        },
        "goals": {
            "home": _score_or_none(home.get("score")),
            "away": _score_or_none(away.get("score")),
        },
        "score": {
            "penalty": {
                "home": _score_or_none(home.get("penaltyScore") or home.get("penalties")),
                "away": _score_or_none(away.get("penaltyScore") or away.get("penalties")),
            }
        },
        "stream_url": IPTV_STREAM_URL,
        "source": "365scores",
    }

def _load_json_file(path):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return None

def _save_json_file(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

def _get_365_all_games(force=False):
    cache_path = os.path.join(WC2026_DIR, "fixtures_365.json")
    if not force and os.path.exists(cache_path) and (time.time() - os.path.getmtime(cache_path)) < 60:
        return _load_json_file(cache_path) or []
    raw = fetch_365_json("games/allscores/", {
        "startDate": SCORES365_START_DATE,
        "endDate": SCORES365_END_DATE,
        "sports": 1,
    })
    games = []
    if isinstance(raw, dict):
        for game in raw.get("games", []):
            if _safe_int(game.get("competitionId")) == SCORES365_COMPETITION_ID:
                games.append(_normalize_365_game(game))
    games.sort(key=lambda x: x.get("fixture", {}).get("timestamp") or 0)
    if games:
        _save_json_file(cache_path, games)
    return games

def _member_index_365(raw_game):
    return {m.get("id"): m for m in raw_game.get("members", []) if isinstance(m, dict)}

def _normalize_365_lineup(team, members_by_id):
    lineups = team.get("lineups") or {}
    team_id = team.get("id")
    starters = []
    substitutes = []
    coach_name = ""
    for lineup_member in lineups.get("members", []):
        member = members_by_id.get(lineup_member.get("id"), {})
        position = lineup_member.get("position") or {}
        formation = lineup_member.get("formation") or position
        entry = {
            "player": {
                "id": member.get("athleteId") or member.get("id") or lineup_member.get("id") or 0,
                "memberId": member.get("id") or lineup_member.get("id"),
                "name": member.get("shortName") or member.get("name") or "Joueur",
                "number": _safe_int(member.get("jerseyNumber"), 0),
                "pos": formation.get("shortName") or position.get("shortName") or "",
                "photo": _player_image_365(member.get("athleteId")),
            }
        }
        status = _safe_int(lineup_member.get("status"), 0)
        if status == 1:
            starters.append(entry)
        elif status == 2:
            substitutes.append(entry)
        elif status == 4:
            coach_name = member.get("name") or member.get("shortName") or coach_name
    return {
        "team": {
            "id": team_id,
            "name": team.get("name") or "",
            "nameCode": _team_code_365(team),
            "logo": _team_logo_365(team_id),
        },
        "formation": lineups.get("formation") or "N/A",
        "coach": {"name": coach_name},
        "startXI": starters,
        "substitutes": substitutes,
    }

def _normalize_365_stats(raw_stats, home_id, away_id):
    paired = {}
    for item in (raw_stats or {}).get("statistics", []):
        stat_id = item.get("id") or item.get("name")
        if stat_id is None:
            continue
        bucket = paired.setdefault(stat_id, {
            "name": item.get("name") or str(stat_id),
            "homeValue": 0,
            "awayValue": 0,
            "statisticsType": "positive",
        })
        value = item.get("value")
        if item.get("competitorId") == home_id:
            bucket["homeValue"] = value
        elif item.get("competitorId") == away_id:
            bucket["awayValue"] = value
    items = sorted(paired.values(), key=lambda x: str(x.get("name")))
    return [{"period": "ALL", "groups": [{"groupName": "Match", "statisticsItems": items}]}] if items else []

def _normalize_365_incidents(raw_game, members_by_id):
    events = raw_game.get("events") or raw_game.get("incidents") or []
    clean = []
    for index, inc in enumerate(events):
        if not isinstance(inc, dict):
            continue
        raw_type = str(inc.get("type") or inc.get("eventType") or inc.get("incidentType") or "").lower()
        event_name = str(inc.get("name") or inc.get("text") or "").lower()
        if "goal" in raw_type or "goal" in event_name:
            incident_type = "goal"
        elif "card" in raw_type or "yellow" in event_name or "red" in event_name:
            incident_type = "card"
        elif "sub" in raw_type:
            incident_type = "substitution"
        else:
            continue
        member = members_by_id.get(inc.get("memberId") or inc.get("playerId"), {})
        team_id = inc.get("competitorId")
        item = {
            "time": _safe_int(inc.get("gameTime") or inc.get("minute") or inc.get("time"), 0),
            "addedTime": inc.get("addedTime"),
            "displayTime": inc.get("gameTimeDisplay") or f"{_safe_int(inc.get('gameTime') or inc.get('minute') or inc.get('time'), 0)}'",
            "incidentType": incident_type,
            "incidentClass": inc.get("class") or inc.get("subType") or "",
            "homeScore": _score_or_none(inc.get("homeScore")),
            "awayScore": _score_or_none(inc.get("awayScore")),
            "isHome": team_id == (raw_game.get("homeCompetitor") or {}).get("id") if team_id else None,
            "sequence": index,
        }
        if member:
            item["player"] = {
                "id": member.get("athleteId") or member.get("id"),
                "name": member.get("shortName") or member.get("name") or "Joueur",
            }
        clean.append(item)
    clean.sort(key=lambda x: (x.get("time") or 0, x.get("addedTime") or 0, x.get("sequence") or 0))
    return clean

def _build_365_match_details(match_id):
    raw = fetch_365_json("game/", {"gameId": match_id})
    if not raw or not raw.get("game"):
        return None
    raw_stats = fetch_365_json("game/stats/", {"games": match_id}) or {}
    game = raw["game"]
    home = game.get("homeCompetitor") or {}
    away = game.get("awayCompetitor") or {}
    members = _member_index_365(game)
    venue = game.get("venue") or {}
    officials = game.get("officials") or []
    official = officials[0] if officials else {}
    dt = _parse_365_datetime(game.get("startTime"))
    status = _status_365(game)
    response = {
        "response": {
            "event": {
                "id": match_id,
                "homeTeam": {
                    "id": home.get("id"),
                    "name": home.get("name") or "Home",
                    "nameCode": _team_code_365(home),
                    "logo": _team_logo_365(home.get("id")),
                },
                "awayTeam": {
                    "id": away.get("id"),
                    "name": away.get("name") or "Away",
                    "nameCode": _team_code_365(away),
                    "logo": _team_logo_365(away.get("id")),
                },
                "homeScore": {"current": _score_or_none(home.get("score")), "penalties": _score_or_none(home.get("penalties"))},
                "awayScore": {"current": _score_or_none(away.get("score")), "penalties": _score_or_none(away.get("penalties"))},
                "winnerCode": game.get("winner"),
                "status": {"description": status["long"], "type": "finished" if status["short"] == "FT" else ("inprogress" if status["short"] == "LIVE" else "notstarted")},
                "startTimestamp": int(dt.timestamp()) if dt else 0,
            },
            "venue": {
                "name": venue.get("name") or "",
                "city": venue.get("city") or venue.get("shortName") or "",
                "capacity": str(venue.get("capacity") or ""),
            },
            "referee": {
                "name": official.get("name") or "",
                "country": "",
            },
            "managers": {"home": {"name": ""}, "away": {"name": ""}},
            "lineups": {
                "home": _normalize_365_lineup(home, members),
                "away": _normalize_365_lineup(away, members),
            },
            "statistics": _normalize_365_stats(raw_stats, home.get("id"), away.get("id")),
            "incidents": _normalize_365_incidents(game, members),
            "kitColors": {
                "home": str(home.get("color") or "#660000").replace("#", ""),
                "away": str(away.get("color") or away.get("awayColor") or "#003399").replace("#", ""),
            },
            "meta": {"source": "365scores", "lastUpdateId": raw.get("lastUpdateId")},
        }
    }
    home_manager = response["response"]["lineups"]["home"].get("coach", {}).get("name", "")
    away_manager = response["response"]["lineups"]["away"].get("coach", {}).get("name", "")
    response["response"]["managers"] = {"home": {"name": home_manager}, "away": {"name": away_manager}}
    return response

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
                            "penalty": {"home": h_s.get('penalties'), "away": a_s.get('penalties')}
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

    try:
        formatted = _get_365_all_games()
        if formatted:
            return jsonify({"response": formatted})
        raise Exception("No fixtures fetched from 365Scores")
    except Exception as e:
        print(f"Error in /api/fixtures 365Scores fetch: {e}")
        cache_path = os.path.join(WC2026_DIR, "fixtures_365.json")
        cached = _load_json_file(cache_path)
        if cached:
            return jsonify({"response": cached})
        return jsonify({"response": []})

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
            raise Exception("No events fetched from live endpoint (blocked by Sofascore or no data)")

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
        print(f"Error in /api/fixtures live fetch: {e}")

    # Fallback to cache if live fetch fails or is blocked
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                print("[Fallback] Fixtures 2026 served from cache")
                return jsonify({"response": json.load(f)})
        except Exception as e:
            print(f"[Fallback] Error reading fixtures cache: {e}")

    # If all fails, return empty response instead of crashing
    return jsonify({"response": []})

@app.route('/api/standings', methods=['GET'])
def get_standings():
    season = request.args.get('season')
    if season == '2022':
        return get_wc2022_resource("standings")

    cache_path = os.path.join(WC2026_DIR, "standings_365.json")
    try:
        raw = fetch_365_json("standings/", {"competitions": SCORES365_COMPETITION_ID})
        standings = (raw or {}).get("standings", [])
        if standings:
            table = standings[0]
            group_names = {
                g.get("num"): g.get("name") or f"Group {g.get('num')}"
                for g in table.get("groups", [])
            }
            grouped = {}
            for row in table.get("rows", []):
                competitor = row.get("competitor") or {}
                group_num = row.get("groupNum")
                group_name = group_names.get(group_num, f"Group {group_num}")
                grouped.setdefault(group_num, []).append({
                    "rank": _safe_int(row.get("position"), 0),
                    "group": group_name,
                    "team": {
                        "id": competitor.get("id"),
                        "name": competitor.get("name") or "TBD",
                        "code": _team_code_365(competitor),
                        "logo": _team_logo_365(competitor.get("id")),
                    },
                    "points": _safe_int(row.get("points"), 0),
                    "goalsDiff": _safe_int(row.get("ratio"), 0),
                    "goalsFor": _safe_int(row.get("for"), 0),
                    "goalsAgainst": _safe_int(row.get("against"), 0),
                    "destinationNum": row.get("destinationNum"),
                    "all": {
                        "played": _safe_int(row.get("gamePlayed"), 0),
                        "win": _safe_int(row.get("gamesWon"), 0),
                        "draw": _safe_int(row.get("gamesEven"), 0),
                        "lose": _safe_int(row.get("gamesLost"), 0),
                    },
                })
            all_s = [sorted(rows, key=lambda r: r.get("rank") or 99) for _, rows in sorted(grouped.items())]
            res = {
                "response": [{
                    "league": {
                        "id": SCORES365_COMPETITION_ID,
                        "name": "World Cup 2026",
                        "season": 2026,
                        "standings": all_s,
                    }
                }],
                "meta": {
                    "source": "365scores",
                    "lastUpdateId": (raw or {}).get("lastUpdateId"),
                    "destinations": table.get("destinations", []),
                    "competitionRules": table.get("competitionRules", {}),
                },
            }
            _save_json_file(cache_path, res)
            return jsonify(res)
        raise Exception("No standings fetched from 365Scores")
    except Exception as e:
        print(f"/api/standings 365Scores fetch error: {e}")
        cached = _load_json_file(cache_path)
        if cached:
            return jsonify(cached)

    # Logique Classement 2026
    try:
        url_g = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/groups"
        groups_raw = fetch_json(url_g)
        if groups_raw and 'groups' in groups_raw:
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
            if all_s:
                # Sauvegarder dans le cache pour la prochaine fois
                cache_path = os.path.join(DATA_DIR, "wc2026_standings_formatted.json")
                res = {"response": [{"league": {"id": UT_ID, "name": "World Cup 2026", "standings": all_s}}]}
                with open(cache_path, 'w', encoding='utf-8') as f:
                    json.dump(res, f, indent=2)
                return jsonify(res)
    except Exception as e:
        print(f"/api/standings live fetch error: {e}")

    # FALLBACK : Lire depuis le cache local si SofaScore est bloqué
    cache_path = os.path.join(DATA_DIR, "wc2026_standings_formatted.json")
    if os.path.exists(cache_path):
        with open(cache_path, 'r', encoding='utf-8') as f:
            print("[Fallback] Standings 2026 servi depuis le cache local")
            return jsonify(json.load(f))

    # Fallback brut : fichier wc2026_true_standings.json
    raw_path = os.path.join(DATA_DIR, "wc2026_true_standings.json")
    if os.path.exists(raw_path):
        with open(raw_path, 'r', encoding='utf-8') as f:
            raw = json.load(f)
            print("[Fallback] Standings 2026 servi depuis wc2026_true_standings.json")
            return jsonify(raw if isinstance(raw, dict) else {"response": raw})

    return jsonify({"response": []})

# =======================================================
# FIREBASE NOTIFICATION GATEWAY (CROWDSOURCING)
# =======================================================

# Un cache pour éviter d'envoyer plusieurs pushs pour le même événement
# (puisque plusieurs téléphones vont le signaler en même temps)
RECENT_NOTIFICATIONS = {}

@app.route('/api/trigger_goal', methods=['POST'])
def trigger_goal():
    """Reçoit le signal d'un but depuis l'application Flutter et déclenche Firebase FCM."""
    try:
        data = request.json
        if not data:
            return jsonify({"error": "No data"}), 400
            
        match_id = str(data.get("match_id", ""))
        title = data.get("title", "")
        body = data.get("body", "")
        
        if not match_id or not title:
            return jsonify({"error": "Missing info"}), 400
            
        # Création d'une clé unique pour l'événement (pour éviter le spam)
        event_key = f"{match_id}_{title}_{body}"
        
        current_time = time.time()
        
        # Nettoyage du cache (garde les événements < 2 minutes)
        keys_to_delete = [k for k, v in RECENT_NOTIFICATIONS.items() if current_time - v > 120]
        for k in keys_to_delete:
            del RECENT_NOTIFICATIONS[k]
            
        if event_key in RECENT_NOTIFICATIONS:
            return jsonify({"status": "ignored", "message": "Already notified recently"}), 200
            
        # Marquer comme notifié
        RECENT_NOTIFICATIONS[event_key] = current_time
        
        print(f"🌟 [CROWDSOURCED EVENT] {title} - {body}")
        
        # Envoi de la notification Push globale via Firebase
        push_data = {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'goal' if data.get('is_goal') else 'event',
            'homeTeamName': str(data.get('home_team', '')),
            'awayTeamName': str(data.get('away_team', '')),
            'homeScore': str(data.get('home_score', '0')),
            'awayScore': str(data.get('away_score', '0')),
            'scoringTeam': str(data.get('scoring_team', '')),
            'scoringTeamCode': str(data.get('home_code', '')) if data.get('scoring_team') == 'home' else str(data.get('away_code', '')),
            'minute': str(data.get('minute', '')),
        }
        
        try:
            msg = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                topic='live_matches',
                data=push_data
            )
            messaging.send(msg)
            print(f"✅ Push FCM envoyée globalement: {title}")
        except Exception as ex:
            print(f"❌ FCM Erreur: {ex}")
            
        return jsonify({"status": "success", "message": "Push sent"}), 200
        
    except Exception as e:
        print(f"Error triggering goal: {e}")
        return jsonify({"error": str(e)}), 500

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
        try:
            url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/top-players/goals"
            raw_data = fetch_json_fast(url)
            if raw_data:
                data = {"response": raw_data}
        except Exception as e:
            print("Error topscorers 2026:", e)

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
    try:
        url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/venues"
        data = fetch_json_fast(url)
        return jsonify({"response": data}) if data else jsonify({"response": []})
    except Exception as e:
        print(f"Error fetching venues 2026: {e}")
        return jsonify({"response": []})

@app.route('/api/cuptree', methods=['GET'])
def get_cuptree():
    season = request.args.get('season', '2022')
    if season == '2022':
        return get_wc2022_resource("cuptree")
    try:
        url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/cuptrees"
        data = fetch_json_fast(url)
        return jsonify({"response": data}) if data else jsonify({"response": []})
    except Exception as e:
        print(f"Error fetching cuptree 2026: {e}")
        return jsonify({"response": []})

@app.route('/api/info', methods=['GET'])
def get_info():
    season = request.args.get('season', '2022')
    if season == '2022':
        return get_wc2022_resource("info")
    try:
        url = f"{SOFA_BASE_URL}/unique-tournament/{UT_ID}/season/{S_ID_2026}/info"
        data = fetch_json_fast(url)
        return jsonify({"response": data}) if data else jsonify({"response": {}})
    except Exception as e:
        print(f"Error fetching info 2026: {e}")
        return jsonify({"response": {}})

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

_last_broadcasts = {}

@app.route('/api/admin/push', methods=['POST'])
def send_push_notification():
    """
    Route to manually trigger or be triggered by the APK to send FCM push notifications.
    Expected JSON payload:
    {
      "topic": "live_matches",
      "type": "goal",
      "homeTeamName": "France",
      "awayTeamName": "Brazil",
      "homeScore": 1,
      "awayScore": 0,
      "minute": "45"
    }
    """
    admin_key = request.headers.get('X-Admin-Key')
    if admin_key != 'mundialy_secret_2026':
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json()
    if not data or 'topic' not in data:
        return jsonify({"error": "Missing topic"}), 400
        
    topic = data.pop('topic')
    
    # --- Deduplication Logic (Compatible Senior UI) ---
    # On cherche les noms des equipes soit à la racine, soit dans l'objet homeTeam/awayTeam
    home_team = data.get('homeTeamName') or (data.get('homeTeam', {}).get('name') if isinstance(data.get('homeTeam'), dict) else '')
    away_team = data.get('awayTeamName') or (data.get('awayTeam', {}).get('name') if isinstance(data.get('awayTeam'), dict) else '')
    home_score = data.get('homeScore') or (data.get('homeTeam', {}).get('score') if isinstance(data.get('homeTeam'), dict) else '')
    away_score = data.get('awayScore') or (data.get('awayTeam', {}).get('score') if isinstance(data.get('awayTeam'), dict) else '')
    title = data.get('title', '')

    match_key = f"{home_team}-{away_team}"
    score_key = f"{home_score}-{away_score}-{title}"
    
    current_time = time.time()
    
    if match_key in _last_broadcasts:
        last_event_key, last_time = _last_broadcasts[match_key]
        if last_event_key == score_key and (current_time - last_time) < 180:
            print(f"🚫 [Deduplicator] Ignored duplicate: {match_key} ({score_key})")
            return jsonify({"success": True, "message": "Duplicate event ignored"}), 200
            
    # Save the new state
    _last_broadcasts[match_key] = (score_key, current_time)
    
    # Use title and message from data for the system notification
    title = data.get('title', 'Mundialy Live')
    body = data.get('message', 'Événement en direct')
    
    # Image Premium (Ratio 2:1 pour un affichage plein écran élégant)
    image_url = "https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1000&h=500&q=80"
    if data.get('type') == 'goal':
        image_url = "https://images.unsplash.com/photo-1551958219-acbc608c6377?auto=format&fit=crop&w=1000&h=500&q=80"

    # Construction des données FCM à partir de data (sérialisation JSON pour les objets complexes)
    fcm_data = {str(k): json.dumps(v) if isinstance(v, (dict, list)) else str(v) for k, v in data.items()}

    try:
        # Pour le design "Senior UI", on n'envoie PAS l'objet 'notification' si c'est un GOAL
        # Cela force Android à appeler onMessageReceived (Kotlin) même en arrière-plan.
        is_custom_ui = data.get('type') in ['GOAL', 'MATCH_START', 'HALF_TIME', 'FULL_TIME']

        notification_obj = None
        if not is_custom_ui:
            notification_obj = messaging.Notification(
                title=title,
                body=body,
                image=image_url
            )

        message = messaging.Message(
            notification=notification_obj,
            data=fcm_data,
            topic=topic,
            android=messaging.AndroidConfig(
                priority='high',
                ttl=3600,
                notification=messaging.AndroidNotification(
                    sound='goal_sound',
                    click_action='FLUTTER_NOTIFICATION_CLICK',
                    channel_id='mundialy_live_alerts_v2',
                    color='#E7C16A',
                    tag=data.get('homeTeamName', 'match_update'),
                    default_vibrate_timings=True
                ) if not is_custom_ui else None
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        content_available=True,
                        mutable_content=True
                    )
                )
            )
        )
        response = messaging.send(message)
        print(f"✅ FCM Broadcast Success: {title} to {topic} (Custom UI: {is_custom_ui})")
        return jsonify({"success": True, "message_id": response})
    except Exception as e:
        print("❌ FCM Broadcast Error:", e)
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/debug/polling')
def get_polling_status():
    """Endpoint de diagnostic lisant le fichier de statut partagé."""
    status = _get_status()
    # On fusionne la mémoire locale et le statut du fichier
    monitored = list(_SERVER_MATCH_STATES.keys())
    if not monitored and "monitored_ids" in status:
        monitored = status["monitored_ids"]

    return jsonify({
        "server_time": datetime.datetime.now().strftime("%H:%M:%S"),
        "polling_status": status,
        "active_matches_monitored": monitored,
        "processed_events_count": len(_SERVER_PROCESSED_EVENTS)
    }), 200

def server_live_polling():
    """
    Background task avec persistance sur fichier pour communication inter-processus.
    """
    print("🚀 [Server Polling] Starting Miracle Scanner (File-Based)...")
    status = {"last_check": "Démarrage", "status": "Lancement du thread", "games_found": 0, "api_response": "Attente"}
    _update_status(status)

    while True:
        try:
            now_str = datetime.datetime.now().strftime("%H:%M:%S")
            status["last_check"] = now_str
            status["status"] = "🌍 Appel API 365Scores..."
            _update_status(status)

            data = fetch_365_json("games/current/", {"competitions": SCORES365_COMPETITION_ID}, base_timeout=8)

            if data is None:
                status["status"] = "⚠️ Bloqué ou Timeout"
                status["api_response"] = "ÉCHEC"
                _update_status(status)
                time.sleep(60)
                continue

            status["api_response"] = "SUCCÈS"
            if 'games' not in data:
                status["games_found"] = 0
                status["status"] = "😴 Aucun match aujourd'hui"
                _update_status(status)
                time.sleep(30)
                continue

            games = data['games']
            status["games_found"] = len(games)
            status["status"] = f"✅ Surveillance ({len(games)} matchs)"
            status["monitored_ids"] = [str(g['id']) for g in games[:10]] # On stocke les 10 premiers IDs pour preuve
            _update_status(status)

            now = datetime.datetime.now(datetime.timezone.utc)
            for g in games:
                game_id = str(g['id'])
                status_group = g.get('statusGroup')
                home, away = g.get('homeCompetitor', {}), g.get('awayCompetitor', {})
                h_name, a_name = home.get('name', 'Home'), away.get('name', 'Away')
                h_score = int(home.get('score', 0)) if home.get('score') is not None else 0
                a_score = int(away.get('score', 0)) if away.get('score') is not None else 0

                if game_id not in _SERVER_MATCH_STATES:
                    _SERVER_MATCH_STATES[game_id] = {"score": f"{h_score}-{a_score}", "reminded_30m": False, "started_notified": False, "ht_notified": False, "ft_notified": False, "second_half_notified": False}

                # Correction du format d'état si nécessaire
                if isinstance(_SERVER_MATCH_STATES[game_id], str):
                    _SERVER_MATCH_STATES[game_id] = {"score": _SERVER_MATCH_STATES[game_id], "reminded_30m": False, "started_notified": False, "ht_notified": False, "ft_notified": False}

                state = _SERVER_MATCH_STATES[game_id]

                # --- 1. RAPPEL 30 MIN ---
                if status_group == 1 and not state.get("reminded_30m"):
                    start_time_str = g.get('startTime', '')
                    if start_time_str:
                        try:
                            kickoff = datetime.datetime.fromisoformat(start_time_str.replace('Z', '+00:00'))
                            if 0 < (kickoff - now).total_seconds() <= 1800:
                                _send_server_push("⚽ PROCHAIN MATCH", f"Coup d'envoi dans 30 min : {h_name} vs {a_name}", {"type": "reminder", "gameId": game_id})
                                state["reminded_30m"] = True
                        except: pass

                # --- 2. DÉBUT MATCH ---
                if status_group == 3 and not state.get("started_notified"):
                    _send_server_push("⏱ DÉBUT DU MATCH", f"Le match commence : {h_name} vs {a_name}", {
                        "type": "start", 
                        "gameId": game_id,
                        "homeTeamName": h_name,
                        "awayTeamName": a_name
                    })
                    state["started_notified"] = True

                # --- 3. BUTS ---
                if status_group == 3:
                    new_score = f"{h_score}-{a_score}"
                    old_score_str = state.get("score", "0-0")
                    if new_score != old_score_str:
                        # Determiner qui a marque
                        old_h, old_a = map(int, old_score_str.split('-'))
                        scoring_side = "home" if h_score > old_h else "away"

                        game_data = fetch_365_json("game/", {"gameId": game_id})
                        p_name = ""
                        if game_data and 'game' in game_data:
                            for ev in reversed(game_data['game'].get('events', [])):
                                if ev.get('eventType', {}).get('id') == 1:
                                    p_name = ev.get('playerName', '')
                                    break

                        body = f"{p_name} ⚽ {h_name} {h_score} - {a_score} {a_name}" if p_name else f"BUT !!! {h_name} {h_score} - {a_score} {a_name}"

                        # Envoi avec le nouveau format Senior UI
                        _send_server_push("⚽ BUT !!!", body, {
                            "type": "GOAL",
                            "scoring_team": scoring_side,
                            "homeTeamName": h_name,
                            "awayTeamName": a_name,
                            "homeScore": str(h_score),
                            "awayScore": str(a_score),
                            "scorer": p_name or "Buteur",
                            "gameId": game_id
                        })
                        state["score"] = new_score

                # --- 4. MI-TEMPS ---
                status_text = (g.get('statusText') or g.get('shortStatusText') or "").upper()
                if status_group == 3 and ("MI-TEMPS" in status_text or "HT" in status_text or "HALFTIME" in status_text) and not state.get("ht_notified"):
                    game_data = fetch_365_json("game/", {"gameId": game_id})
                    scorers = []
                    if game_data and 'game' in game_data:
                        members = _member_index_365(game_data['game'])
                        for ev in game_data['game'].get('events', []):
                            if ev.get('eventType', {}).get('id') == 1: # Goal
                                mid = ev.get('memberId')
                                team_id = ev.get('competitorId')
                                team_name = h_name if team_id == home.get('id') else a_name
                                p_name = members.get(mid, {}).get('name', 'Joueur') if mid else "Joueur"
                                scorers.append({"name": p_name, "team": team_name, "minute": str(ev.get('gameTime', ''))})

                    _send_server_push("⏱ MI-TEMPS", f"Score à la pause : {h_name} {h_score} - {a_score} {a_name}", {
                        "type": "HALF_TIME",
                        "homeTeam": {"name": h_name, "score": str(h_score), "countryCode": get_iso(h_name), "logoUrl": f"https://flagcdn.com/w160/{get_iso(h_name)}.png"},
                        "awayTeam": {"name": a_name, "score": str(a_score), "countryCode": get_iso(a_name), "logoUrl": f"https://flagcdn.com/w160/{get_iso(a_name)}.png"},
                        "scorers": scorers[:2],
                        "gameId": game_id
                    })
                    state["ht_notified"] = True

                # --- 4.5 DEUXIÈME MI-TEMPS ---
                if status_group == 3 and ("SECOND HALF" in status_text or "2ND HALF" in status_text) and not state.get("second_half_notified"):
                    _send_server_push("⏱ REPRISE", f"La 2ème mi-temps commence : {h_name} vs {a_name}", {
                        "type": "start", 
                        "gameId": game_id,
                        "homeTeamName": h_name,
                        "awayTeamName": a_name
                    })
                    state["second_half_notified"] = True

                # --- 5. FIN DU MATCH ---
                if status_group == 4 and not state.get("ft_notified"):
                    winner_side = "draw"
                    if h_score > a_score: winner_side = "home"
                    elif a_score > h_score: winner_side = "away"

                    _send_server_push("🏁 FIN DU MATCH", f"Score final : {h_name} {h_score} - {a_score} {a_name}", {
                        "type": "FULL_TIME",
                        "winner": winner_side,
                        "duration": status_text,
                        "homeTeam": {"name": h_name, "score": str(h_score), "countryCode": get_iso(h_name), "logoUrl": f"https://flagcdn.com/w160/{get_iso(h_name)}.png"},
                        "awayTeam": {"name": a_name, "score": str(a_score), "countryCode": get_iso(a_name), "logoUrl": f"https://flagcdn.com/w160/{get_iso(a_name)}.png"},
                        "gameId": game_id
                    })
                    state["ft_notified"] = True

        except Exception as e:
            print(f"⚠️ [Server Polling] Erreur : {e}")

        time.sleep(30)

def get_iso(name):
    iso_map = {
        "Algeria": "dz", "Argentina": "ar", "Australia": "au", "Austria": "at", 
        "Belgium": "be", "Bosnia & Herzegovina": "ba", "Brazil": "br", "Canada": "ca", 
        "Cape Verde": "cv", "Colombia": "co", "Croatia": "hr", "Curacao": "cw", 
        "Czechia": "cz", "DR Congo": "cd", "Ecuador": "ec", "Egypt": "eg", 
        "England": "gb-eng", "France": "fr", "Germany": "de", "Ghana": "gh", 
        "Haiti": "ht", "Iran": "ir", "Iraq": "iq", "Ivory Coast": "ci", 
        "Japan": "jp", "Jordan": "jo", "Mexico": "mx", "Morocco": "ma", 
        "Netherlands": "nl", "New Zealand": "nz", "Norway": "no", "Panama": "pa", 
        "Paraguay": "py", "Portugal": "pt", "Qatar": "qa", "Saudi Arabia": "sa", 
        "Scotland": "gb-sct", "Senegal": "sn", "South Africa": "za", "South Korea": "kr", 
        "Spain": "es", "Sweden": "se", "Switzerland": "ch", "Tunisia": "tn", 
        "Turkiye": "tr", "USA": "us", "Uruguay": "uy", "Uzbekistan": "uz",
        
        # Fallbacks (for robust handling)
        "Czech Republic": "cz", "Turkey": "tr", "United States": "us", "Wales": "gb-wls"
    }
    return iso_map.get(name, "un")

def _send_server_push(title, body, extra_data):
    """
    Internal helper to send Ultra-Premium Firebase messages.
    """
    try:
        # Resolve team names from nested objects if necessary
        h_name = extra_data.get('homeTeamName') or (extra_data.get('homeTeam', {}).get('name') if isinstance(extra_data.get('homeTeam'), dict) else 'Home')
        a_name = extra_data.get('awayTeamName') or (extra_data.get('awayTeam', {}).get('name') if isinstance(extra_data.get('awayTeam'), dict) else 'Away')
        
        # Resolve scores
        h_score = extra_data.get('homeScore') or (extra_data.get('homeTeam', {}).get('score') if isinstance(extra_data.get('homeTeam'), dict) else '0')
        a_score = extra_data.get('awayScore') or (extra_data.get('awayTeam', {}).get('score') if isinstance(extra_data.get('awayTeam'), dict) else '0')

        raw_type = extra_data.get('type', 'GOAL')
        msg_type = raw_type
        if raw_type == "start":
            msg_type = "MATCH_START"
        
        scoring_team = extra_data.get('scoring_team', extra_data.get('scoringTeam', 'home'))
        scoring_iso = get_iso(h_name) if scoring_team == 'home' else get_iso(a_name)

        # Build flat payload structure expected by Android Native codebase
        fcm_payload_obj = {
            "type": msg_type,
            "title": title,
            "message": body,
            "scoringCountryCode": scoring_iso,
            "homeCountryCode": get_iso(h_name),
            "awayCountryCode": get_iso(a_name),
            "homeTeamName": h_name,
            "awayTeamName": a_name,
            "homeScore": str(h_score),
            "awayScore": str(a_score),
            "scoringTeam": scoring_team,
            "scorerName": extra_data.get('scorer', extra_data.get('scorerName', 'Joueur')),
            "minute": str(extra_data.get('minute', '0')),
            "isPenalty": "true" if "PENALTY" in title.upper() else "false",
            "competition": extra_data.get('competition', 'Coupe du Monde'),
            "motm": extra_data.get('motm', extra_data.get('winner', ''))
        }
        
        # topScorer handling for HT
        if 'scorers' in extra_data and isinstance(extra_data['scorers'], list) and len(extra_data['scorers']) > 0:
            s = extra_data['scorers'][0]
            fcm_payload_obj['topScorer'] = f"⚽ {s.get('name', '')} {s.get('minute', '')}' · {s.get('team', '')}"
        else:
            fcm_payload_obj['topScorer'] = extra_data.get('topScorer', '')

        # Filter empty and force strings
        fcm_data = {str(k): str(v) for k, v in fcm_payload_obj.items() if v is not None}

        message = messaging.Message(
            data=fcm_data,
            topic='live_matches',
            android=messaging.AndroidConfig(
                priority='high',
                ttl=3600
            )
        )
        messaging.send(message)
        print(f"🔥 [Auto-Polling Push] Sent Senior UI {msg_type} for {h_name} vs {a_name}")
    except Exception as e:
        print(f"❌ [Auto-Polling Push] Error: {e}")

# --- DÉMARRAGE AUTOMATIQUE (Compatible Gunicorn/Render) ---
# --- DÉMARRAGE AUTOMATIQUE ---
# On sort de toute fonction pour forcer l'exécution globale au chargement
print("🚀 [System] Initializing Global Scorer Engine...")

def delayed_start():
    print("⏳ [System] Waiting for Flask to stabilize (5s)...")
    time.sleep(5)
    print("🚀 [System] Starting Scorer Loop now.")
    server_live_polling()

# Lancement immédiat du thread
threading.Thread(target=delayed_start, daemon=True).start()

if __name__ == '__main__':
    # Ce bloc n'est utilisé que pour le développement local
    app.run(host='0.0.0.0', port=10000, debug=False)
