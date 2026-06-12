import json
import urllib.request

url = "https://webws.365scores.com/web/player/?appTypeId=5&langId=1&players=455623"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    data = json.loads(urllib.request.urlopen(req).read())
    print("keys:", data.keys())
except Exception as e:
    print(e)
