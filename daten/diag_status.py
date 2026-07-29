import requests

SPECS = {
    "FURY": "https://www.wowhead.com/tbc/guide/fury-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RET": "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
}

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

for spec, url in SPECS.items():
    r = requests.get(url, headers=headers)
    print(f"{spec}: Status {r.status_code}, Length {len(r.text)}")
    if r.status_code == 200:
        print("First 200 chars:", r.text[:200])
