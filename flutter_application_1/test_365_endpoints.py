#!/usr/bin/env python3
"""Audit complet des endpoints 365Scores consommés par Mundialy.

Vérifie pour chaque endpoint :
  - statut HTTP
  - présence des clés attendues (games, standings, stats...)
  - taille de la réponse (gzip vs brut)
  - déchets détectés (champs demandés mais jamais consommés)

Usage : python3 test_365_endpoints.py
"""
import gzip
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://webws.365scores.com/web"
BASE_PARAMS = "appTypeId=5&langId=1&timezoneName=Europe%2FParis&userCountryId=135"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Encoding": "gzip, deflate, br",
    "Accept-Language": "fr-FR,fr;q=0.9",
    "Origin": "https://www.365scores.com",
    "Referer": "https://www.365scores.com/",
}

WC_ID = 5930


def fetch(path, params=""):
    url = f"{BASE}/{path}?{BASE_PARAMS}"
    if params:
        url += "&" + params
    req = urllib.request.Request(url, headers=HEADERS)
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read()
            # gzip auto?
            if raw[:2] == b"\x1f\x8b":
                try:
                    body = gzip.decompress(raw)
                    enc = "gzip"
                except Exception:
                    body = raw
                    enc = "raw?"
            else:
                body = raw
                enc = "identity"
            dt = time.time() - t0
            return {
                "ok": resp.status == 200,
                "status": resp.status,
                "enc": enc,
                "bytes": len(raw),
                "dec_bytes": len(body),
                "ms": int(dt * 1000),
                "json": json.loads(body) if body else None,
                "error": None,
                "url": url,
            }
    except urllib.error.HTTPError as e:
        return {"ok": False, "status": e.code, "error": str(e), "url": url,
                "bytes": 0, "ms": int((time.time() - t0) * 1000)}
    except Exception as e:
        return {"ok": False, "status": None, "error": str(e), "url": url,
                "bytes": 0, "ms": int((time.time() - t0) * 1000)}


def count_games(d):
    if not d:
        return 0
    return len(d.get("games") or [])


RESULTS = []


def check(name, expect_keys, r, notes=""):
    data = r.get("json")
    status = "OK" if r.get("ok") else "FAIL"
    found = []
    missing = []
    if data and isinstance(data, dict):
        for k in expect_keys:
            (found if k in data else missing).append(k)
    verdict = status
    if r.get("ok") and missing:
        verdict = "WARN"
    extra = ""
    if data and isinstance(data, dict):
        if "games" in data:
            extra = f" games={count_games(data)}"
        elif "standings" in data:
            st = data.get("standings") or []
            rows = len((st[0] or {}).get("rows") or []) if st else 0
            extra = f" standings={len(st)} rows={rows}"
        elif "stats" in data:
            athletes = ((data.get("stats") or {}).get("athletesStats")) or []
            extra = f" athletesStats={len(athletes)}"
        elif "brackets" in data:
            extra = f" brackets={len(data.get('brackets') or [])}"
        elif "athletes" in data:
            extra = f" athletes={len(data.get('athletes') or [])}"
        elif "squads" in data:
            sq = data.get("squads") or []
            extra = f" squads={len(sq)}"
        elif "competitions" in data:
            extra = f" comps={len(data.get('competitions') or [])}"
        elif "news" in data:
            extra = f" news={len(data.get('news') or [])}"
    RESULTS.append((name, verdict, r.get("status"), r.get("bytes"),
                    r.get("ms"), extra, notes))
    print(f"[{verdict:4}] {name:38} http={r.get('status')} "
          f"{r.get('bytes'):>7}B {r.get('ms'):>5}ms{extra} {notes}")
    if missing:
        print(f"        missing keys: {missing}")
    if r.get("error"):
        print(f"        error: {r['error']}")
    return data


def main():
    print("=" * 100)
    print("AUDIT ENDPOINTS 365Scores — Mundialy")
    print("=" * 100)

    # 1. games/current (live) — SANS showOdds
    r = fetch("games/current/", f"competitions={WC_ID}")
    d = check("games/current (live WC)", ["games"], r,
              "→ fetchLiveMatches")
    # DÉCHET : showOdds=true demandé par le code, odds jamais lues
    r_odds = fetch("games/current/", f"competitions={WC_ID}&showOdds=true")
    d_odds = r_odds.get("json")
    waste_odds = 0
    if d and d_odds:
        waste_odds = r_odds.get("bytes", 0) - r.get("bytes", 0)
        print(f"        showOdds=true coûte +{waste_odds} B "
              f"({r_odds.get('bytes')} vs {r.get('bytes')}) "
              f"→ odds JAMAIS consommées = DÉCHET")
        # Vérifier qu'aucun game n'a besoin des odds
        sample = ((d_odds.get("games") or [{}])[0]) if d_odds.get("games") else {}
        has_odds_field = "odds" in sample or "bet365" in sample
        print(f"        odds présentes dans payload: {has_odds_field} "
              f"(champ non lu par _mapToLiveMatch)")

    # 2. games/ (fixtures WC 2026)
    r = fetch("games/", f"competitions={WC_ID}&startDate=11/06/2026&endDate=19/07/2026")
    check("games/ (fixtures WC 2026)", ["games"], r, "→ fetchFixtures(2026)")

    # 3. games/ sans dates (fallback)
    r = fetch("games/", f"competitions={WC_ID}")
    check("games/ (sans dates)", ["games"], r, "→ fallback")

    # 4. standings
    r = fetch("standings/", f"competitions={WC_ID}&live=true")
    check("standings/ (WC)", ["standings"], r, "→ fetchStandings")

    # 5. stats (buteurs)
    r = fetch("stats/", f"competitions={WC_ID}")
    d = check("stats/ (WC buteurs)", ["stats"], r, "→ fetchTopScorers")
    if d and isinstance(d, dict):
        cats = ((d.get("stats") or {}).get("athletesStats")) or []
        names = [c.get("name") for c in cats if isinstance(c, dict)]
        print(f"        catégories: {names}")
        # Le code ne lit que Goals + Assists → autres catégories = déchet?
        unused = [n for n in names if n not in ("Goals", "Assists")]
        if unused:
            print(f"        catégories NON consommées: {unused}")

    # 6. game/ détail
    # Trouver un gameId réel
    r_g = fetch("games/results/", f"competitions={WC_ID}")
    game_id = None
    if r_g.get("json") and r_g["json"].get("games"):
        game_id = r_g["json"]["games"][0].get("id")
    if game_id:
        r = fetch("game/", f"gameId={game_id}")
        check(f"game/ (détail id={game_id})", ["game"], r, "→ fetchMatchDetails")
        r = fetch("game/stats/", f"games={game_id}")
        check("game/stats/", ["statistics"], r, "→ fetchMatchDetails")
        r = fetch("news/", f"gameId={game_id}")
        check("news/", ["news"], r, "→ fetchMatchNews (DEAD CODE?)")
    else:
        print("[SKIP] game/ — aucun gameId trouvé (results vide)")

    # 7. brackets
    r = fetch("brackets/", f"competitions={WC_ID}")
    check("brackets/ (WC)", ["brackets"], r, "→ fetchBracketsByCompetition")

    # 8. competitions meta
    r = fetch("competitions/", f"competitions={WC_ID}&withSeasons=true&withBestOdds=true&isDashboard=true")
    check("competitions/ (meta WC)", ["competitions"], r,
          "→ fetchCompetitionMeta (DEAD CODE?)")

    # 9. squads (équipe connue : France=122? tester quelques IDs)
    for tid in (122, 132, 5053):
        r = fetch("squads/", f"competitors={tid}")
        d = check(f"squads/ (competitor={tid})", ["squads"], r,
                  "→ fetchTeamSquad")
        if r.get("ok") and d and d.get("squads"):
            break

    # 10. athletes (joueur)
    r = fetch("athletes/", "athletes=771")
    check("athletes/ (id=771)", ["athletes"], r, "→ fetchPlayerStats")

    # 11. games/results (déchets?)
    r = fetch("games/results/", f"competitions={WC_ID}")
    check("games/results/ (WC)", ["games"], r, "→ fetchAllMatchesForCompetition")

    # 12. games/fixtures
    r = fetch("games/fixtures/", f"competitions={WC_ID}")
    check("games/fixtures/ (WC)", ["games"], r, "→ fetchAllMatchesForCompetition")

    # 13. games/current (déjà testé) — résultats pour comparaison déchets
    r = fetch("games/current/", f"competitions={WC_ID}")
    check("games/current/ (déjà)", ["games"], r, "→ dédup")

    # 14. competitors filter (équipe)
    r = fetch("games/results/", "competitors=122")
    check("games/results/ (team=122)", ["games"], r, "→ fetchAllMatchesForTeam")

    # 15. multi competitions (méthode DEAD?)
    r = fetch("games/", f"competitions={WC_ID},167")
    check("games/ (multi comps)", ["games"], r,
          "→ fetchMatchesForMultipleCompetitions (DEAD?)")

    # 16. games/allscores (backend only)
    r = fetch("games/allscores/", f"startDate=11/06/2026&endDate=19/07/2026&sports=1&competitions={WC_ID}")
    check("games/allscores/", ["games"], r, "→ backend _get_365_all_games")

    # 17. live by competition (méthode DEAD?)
    r = fetch("games/current/", f"competitions={WC_ID}&showOdds=true")
    check("games/current+odds (DEAD?)", ["games"], r,
          "→ fetchLiveMatchesByCompetition (DEAD?)")

    print()
    print("=" * 100)
    print("RÉSUMÉ")
    print("=" * 100)
    ok = sum(1 for x in RESULTS if x[1] == "OK")
    warn = sum(1 for x in RESULTS if x[1] == "WARN")
    fail = sum(1 for x in RESULTS if x[1] == "FAIL")
    print(f"  OK={ok}  WARN={warn}  FAIL={fail}  total={len(RESULTS)}")
    fails = [x for x in RESULTS if x[1] == "FAIL"]
    if fails:
        print("  Échecs:")
        for f in fails:
            print(f"    - {f[0]}: {f[2]} {f[5]}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
