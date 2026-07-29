import requests
import re
import html
import json

url = "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)'}

r = requests.get(url, headers=headers)
print("HTML Length:", len(r.text))

# Find the JSON data script block that contains the guide markup
matches = list(re.finditer(r'<script type="application/json" id="data\.wowhead-guid[^"]*">(.*?)</script>', r.text))
print("Found json data script tags:", len(matches))
for i, m in enumerate(matches):
    content = m.group(1)
    print(f"Tag {i} length: {len(content)}")
    # Decode string
    try:
        decoded = json.loads(content)
        print(f"Decoded tag {i} type: {type(decoded)}")
        print(f"Decoded tag {i} snippet: {decoded[:300]}")
    except Exception as e:
        print("Failed to decode json:", e)
