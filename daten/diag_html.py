import urllib.request
import re

url = "https://www.warcrafttavern.com/tbc/guides/pve-retribution-paladin-phase-3-bis/"
headers = {'User-Agent': 'Mozilla/5.0'}
req = urllib.request.Request(url, headers=headers)
html_content = urllib.request.urlopen(req, timeout=20).read().decode('utf-8')

print("Length of HTML:", len(html_content))
print("Looking for tables...")
print("Raw count of <table:", len(re.findall(r'<table', html_content, re.IGNORECASE)))
print("Raw count of <h3:", len(re.findall(r'<h3', html_content, re.IGNORECASE)))
print("Raw count of <h4:", len(re.findall(r'<h4', html_content, re.IGNORECASE)))
# print snippet of html
with open("raw.html", "w", encoding="utf-8") as f:
    f.write(html_content)
print("Saved raw html")
