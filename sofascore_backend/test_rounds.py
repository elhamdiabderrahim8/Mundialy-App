import json
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

def init_driver():
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('user-agent=Mozilla/5.0')
    return webdriver.Chrome(options=options)

def fetch(driver, url):
    driver.get(url)
    time.sleep(3)
    return json.loads(driver.find_element("xpath", "//body").text)

urls = {
    "R16": "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/26/slug/round-of-16",
    "QF": "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/27/slug/quarter-finals",
    "SF": "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/28/slug/semi-finals",
    "Final": "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/29/slug/final"
}

driver = init_driver()
try:
    for name, url in urls.items():
        print(f"Testing {name}...")
        data = fetch(driver, url)
        if 'events' in data and len(data['events']) > 0:
            match = data['events'][0]
            print(f"  [OK] Found match: {match['homeTeam']['name']} vs {match['awayTeam']['name']}")
        else:
            print(f"  [FAILED] No events found for {name}")
finally:
    driver.quit()
