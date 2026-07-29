import requests
import re

url = "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)'}
r = requests.get(url, headers=headers)

# Find all positions of "Cursed Vision of Sargeras"
positions = [m.start() for m in re.finditer("Cursed Vision of Sargeras", r.text)]
print(f"Found {len(positions)} matches")
for i, pos in enumerate(positions):
    print(f"\nMatch {i} at position {pos}:")
    print(r.text[max(0, pos-150):pos+250])
