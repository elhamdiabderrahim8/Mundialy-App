import requests

def test_proxies():
    try:
        proxies_data = requests.get('https://proxylist.geonode.com/api/proxy-list?limit=30&sort_by=lastChecked&sort_type=desc&protocols=http%2Chttps').json()
        for p in proxies_data.get('data', []):
            proxy = f"http://{p['ip']}:{p['port']}"
            print('Testing proxy:', proxy)
            try:
                r = requests.get('https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/last/0', 
                                 proxies={'http': proxy, 'https': proxy}, timeout=5)
                if r.status_code == 200:
                    print('SUCCESS with proxy:', proxy)
                    return True
            except Exception as e:
                pass
    except Exception as e:
        print('Failed to get proxy list', e)
    return False

test_proxies()
