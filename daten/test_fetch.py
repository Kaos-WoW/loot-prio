import urllib.request
import json

url = "https://www.wowhead.com/tbc/guide/fury-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        print(f"Success, length: {len(html)}")
except Exception as e:
    print(f"Error: {e}")
