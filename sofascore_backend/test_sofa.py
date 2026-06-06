import time
from curl_cffi import requests as cffi_requests

url_api = "https://api.sofascore.com/api/v1/sport/football/events/live"
url_www = "https://www.sofascore.com/api/v1/sport/football/events/live"

headers = {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'Referer': 'https://www.sofascore.com/',
    'Origin': 'https://www.sofascore.com',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

def test_fetch(url, profile):
    print(f"Testing {url} with profile {profile}...")
    try:
        r = cffi_requests.get(url, headers=headers, impersonate=profile, timeout=10)
        print(f"Result: {r.status_code}")
        if r.status_code == 200:
            print("Success!")
            return True
    except Exception as e:
        print(f"Error: {e}")
    return False

profiles = ['chrome110', 'chrome120', 'safari15_5', 'edge101']
for p in profiles:
    if test_fetch(url_api, p):
        break
    time.sleep(1)

for p in profiles:
    if test_fetch(url_www, p):
        break
    time.sleep(1)
