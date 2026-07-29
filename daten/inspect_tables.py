import re
import html as html_module

with open("raw.html", "r", encoding="utf-8") as f:
    html_content = f.read()

# Let's find some table content to see what it actually looks like in raw HTML
tables = re.findall(r'<table[^>]*>(.*?)</table>', html_content, re.IGNORECASE | re.DOTALL)
print(f"Found {len(tables)} tables")

# Let's inspect the headers and first row of the first few tables
tag_re = re.compile(r'<[^>]+>')
for i, t in enumerate(tables[:5]):
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', t, re.IGNORECASE | re.DOTALL)
    print(f"\nTable {i} has {len(rows)} rows:")
    for r_idx, row in enumerate(rows[:3]):
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.IGNORECASE | re.DOTALL)
        clean_cells = [tag_re.sub('', c).strip() for c in cells]
        print(f"  Row {r_idx}: {clean_cells}")
