import sys
sys.path.append('D:/WordCup/sofascore_backend')
from app import init_selenium_driver, fetch_json, SOFA_BASE_URL
driver = init_selenium_driver()
try:
    print('Testing rounds...')
    for r in range(1, 4):
        data = fetch_json(driver, f'{SOFA_BASE_URL}/unique-tournament/16/season/58210/events/round/{r}')
        if data and 'events' in data:
            print(f'Round {r}: {len(data["events"])} events')
        else:
            print(f'Round {r}: NO EVENTS')
    
    print('Testing last/0...')
    data = fetch_json(driver, f'{SOFA_BASE_URL}/unique-tournament/16/season/58210/events/last/0')
    if data and 'events' in data:
        print(f'last/0: {len(data["events"])} events')
    print('Testing next/0...')
    data = fetch_json(driver, f'{SOFA_BASE_URL}/unique-tournament/16/season/58210/events/next/0')
    if data and 'events' in data:
        print(f'next/0: {len(data["events"])} events')
finally:
    driver.quit()
