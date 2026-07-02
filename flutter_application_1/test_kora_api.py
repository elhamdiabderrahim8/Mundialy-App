import urllib.request, json, ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'Origin': 'https://www.365scores.com',
    'Referer': 'https://www.365scores.com/',
}

def get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, context=ctx, timeout=15) as r:
        return json.loads(r.read().decode('utf-8', errors='replace'))

url = 'https://webws.365scores.com/web/game/?appTypeId=5&langId=31&timezoneName=Europe%2FParis&userCountryId=135&gameId=4747697'
d = get(url)
g = d.get('game', {})
home = g.get('homeCompetitor', {})
away = g.get('awayCompetitor', {})

print(f"Match: {home.get('name')} vs {away.get('name')}")
print(f"isWinner home={home.get('isWinner')} away={away.get('isWinner')}")
print(f"isQualified home={home.get('isQualified')} away={away.get('isQualified')}")
print(f"\nwinDescription: {g.get('winDescription')}")

# Check stages
print(f"\n=== STAGES ===")
for s in g.get('stages', []):
    print(f"  stageId={s.get('stageId')} name={s.get('name')} homeScore={s.get('homeCompetitorScore')} awayScore={s.get('awayCompetitorScore')}")

# Check chartEvents for penalty scores
print(f"\n=== chartEvents ===")
for c in g.get('chartEvents', [])[:10]:
    print(f"  {c}")

# Check topPerformers
print(f"\n=== topPerformers ===")
for t in g.get('topPerformers', [])[:5]:
    print(f"  {t}")
    
# Also check games list to see if stages is there
print(f"\n=== Checking games list structure ===")
url2 = 'https://webws.365scores.com/web/games/?appTypeId=5&langId=31&timezoneName=Europe%2FParis&userCountryId=135&competitions=5930&startDate=11/06/2026&endDate=19/07/2026'
d2 = get(url2)
games = d2.get('games', [])
target = next((g2 for g2 in games if g2.get('id') == 4747697), None)
if target:
    print(f"Game list top-level keys: {list(target.keys())}")
    print(f"winDescription: {target.get('winDescription')}")
    print(f"stages in list: {target.get('stages')}")
    home2 = target.get('homeCompetitor', {})
    away2 = target.get('awayCompetitor', {})
    print(f"home penaltyScore={home2.get('penaltyScore')} score={home2.get('score')}")
    print(f"away penaltyScore={away2.get('penaltyScore')} score={away2.get('score')}")
