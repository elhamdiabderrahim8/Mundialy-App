import time
from curl_cffi import requests as cffi_requests

url = "https://api.sofascore.com/api/v1/event/10385314/incidents"

headers = {
    'Accept': 'application/json',
    'Accept-Language': 'fr-FR,fr;q=0.9',
    'Referer': 'https://www.sofascore.com/',
    'Origin': 'https://www.sofascore.com',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

try:
    r = cffi_requests.get(url, headers=headers, impersonate='chrome110', timeout=10)
    print(r.text[:1000])
except Exception as e:
    print(f"Error: {e}")
