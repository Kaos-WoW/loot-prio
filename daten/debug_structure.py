import json
import re
import urllib.request
import html as html_module

# Fetch just RET to understand structure
url = "https://www.warcrafttavern.com/tbc/guides/pve-retribution-paladin-phase-3-bis/"
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
req = urllib.request.Request(url, headers=headers)
html_content = urllib.request.urlopen(req, timeout=20).read().decode('utf-8')

# Find the BiS section
start = html_content.find('Ideal Set')
if start == -1:
    start = html_content.find('Best in Slot')
content = html_content[start:start+80000]

# Show h2/h3/h4 headers to understand structure
h_re = re.compile(r'<h([234])[^>]*>(.*?)</h\1>', re.IGNORECASE | re.DOTALL)
tag_re = re.compile(r'<[^>]+>')

print("=== HEADERS in BiS section ===")
for m in h_re.finditer(content):
    level = m.group(1)
    text = tag_re.sub('', m.group(2)).strip()
    text = html_module.unescape(text)
    print(f"  H{level}: {text}")

# Show first 3 tables structure
table_re = re.compile(r'<table[^>]*>(.*?)</table>', re.IGNORECASE | re.DOTALL)
tables = list(table_re.finditer(content))
print(f"\n=== FOUND {len(tables)} tables ===")
for i, t in enumerate(tables[:4]):
    snippet = tag_re.sub('', t.group(0))
    snippet = html_module.unescape(snippet).strip()[:300]
    print(f"\n  Table {i}: {snippet}")
