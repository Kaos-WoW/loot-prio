import requests
import re

url = "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)'}
r = requests.get(url, headers=headers)

# Find any instances of item links
item_matches = re.findall(r'href="[^"]*(?:item[=/])\d+[^"]*"[^>]*>(.*?)</a>', r.text)
print("Found item links in HTML:", len(item_matches))
for i, m in enumerate(item_matches[:15]):
    print(f"Link {i}: {m}")

# Look for headers
print("\nHeaders in HTML:")
headers_m = re.findall(r'<h[234][^>]*>(.*?)</h[234]>', r.text)
for i, h in enumerate(headers_m[:15]):
    print(f"Header {i}: {h}")
