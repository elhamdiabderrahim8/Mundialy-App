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

urls = [
    "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/1/slug/round-of-16",
    "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/26/slug/round-of-16",
    "https://api.sofascore.com/api/v1/unique-tournament/16/season/41087/events/round/26",
]

driver = init_driver()
try:
    for url in urls:
        print(f"Testing URL: {url}")
        data = fetch(driver, url)
        if 'events' in data and len(data['events']) > 0:
            match = data['events'][0]
            print(f"  [OK] Found match: {match['homeTeam']['name']} vs {match['awayTeam']['name']}")
        else:
            print(f"  [FAILED]")
finally:
    driver.quit()
