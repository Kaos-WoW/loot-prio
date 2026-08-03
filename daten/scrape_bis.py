import json
import re
import os
import urllib.request
import html as html_module

specs = {
    "FURY":        "https://www.warcrafttavern.com/tbc/guides/fury-warrior-dps-phase-3-best-in-slot-bis/",
    "ARMS":        "https://www.warcrafttavern.com/tbc/guides/arms-warrior-dps-phase-3-best-in-slot-bis/",
    "RET":         "https://www.warcrafttavern.com/tbc/guides/pve-retribution-paladin-phase-3-bis/",
    "ENH":         "https://www.warcrafttavern.com/tbc/guides/pve-enhancement-shaman-phase-3-bis/",
    "ROGUE":       "https://www.warcrafttavern.com/tbc/guides/combat-rogue-pve-phase-3-best-in-slot-bis/",
    "HUNT":        "https://www.warcrafttavern.com/tbc/guides/pve-marksmanship-hunter-phase-3-bis/",
    "WLCK":        "https://www.warcrafttavern.com/tbc/guides/pve-destruction-warlock-phase-3-bis/",
    "MAGE":        "https://www.warcrafttavern.com/tbc/guides/arcane-mage-pve-phase-3-best-in-slot-bis/",
    "SPRI":        "https://www.warcrafttavern.com/tbc/guides/pve-shadow-priest-phase-3-bis/",
    "ELE":         "https://www.warcrafttavern.com/tbc/guides/pve-elemental-shaman-phase-3-bis/",
    "BAL":         "https://www.warcrafttavern.com/tbc/guides/pve-balance-druid-phase-3-bis/",
    "PROT_PALA":   "https://www.warcrafttavern.com/tbc/guides/pve-protection-paladin-phase-3-bis/",
    "FERAL_TANK":  "https://www.warcrafttavern.com/tbc/guides/pve-feral-druid-tank-phase-3-bis/",
    "RESTO_SHAM":  "https://www.warcrafttavern.com/tbc/guides/pve-restoration-shaman-phase-3-bis/",
    "HOLY_PRIEST": "https://www.warcrafttavern.com/tbc/guides/pve-holy-priest-phase-3-bis/",
    "RESTO_DRUID": "https://www.warcrafttavern.com/tbc/guides/pve-restoration-druid-phase-3-bis/",
    "HOLY_PALA":   "https://www.warcrafttavern.com/tbc/guides/pve-holy-paladin-phase-3-bis/",
}

output_path = r"c:\Users\maxim\OneDrive\Documents\Skripte&Codes&Addons\TBC-Lootprio\daten\bis-listen.json"

# Item link in a cell: we want the item ID from wowhead or wowclassicdb
item_link_re = re.compile(r'href="[^"]*(?:item[=/])(\d+)[^"]*"', re.IGNORECASE)
tag_re = re.compile(r'<[^>]+>')

def clean(s):
    return html_module.unescape(tag_re.sub('', s).strip()).strip()

all_bis = {}
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}

for spec, url in specs.items():
    print(f"Scraping {spec}...")
    req = urllib.request.Request(url, headers=headers)
    try:
        html_content = urllib.request.urlopen(req, timeout=20).read().decode('utf-8')
    except Exception as e:
        print(f"  ERROR: {e}")
        all_bis[spec] = []
        continue

    # Warcraft Tavern splits items by <h3>Slot</h3> followed by a <table>
    # Let's split the HTML by <h3> or <h4> slots.
    # The actual slots section usually starts around "Ideal Set" or a h2/h3 header
    # Let's parse all pairs of headers and tables.
    # We find all h3 headers, and then look for the next table.
    
    # Let's extract all <h3> tags and <table> tags with their indices
    h3_matches = list(re.finditer(r'<h3[^>]*>(.*?)</h3>', html_content, re.IGNORECASE | re.DOTALL))
    table_matches = list(re.finditer(r'<table[^>]*>(.*?)</table>', html_content, re.IGNORECASE | re.DOTALL))
    
    spec_items = []
    
    # For each table, find the closest preceding H3 tag which is not too far away
    # and represents a valid gear slot.
    for tbl_match in table_matches:
        tbl_start = tbl_match.start()
        
        # Find the H3 that is before this table and closest to it
        closest_h3 = None
        for h3 in h3_matches:
            if h3.end() < tbl_start:
                closest_h3 = h3
            else:
                break
                
        if not closest_h3:
            continue
            
        slot_name = clean(closest_h3.group(1))
        
        # Filter out obvious non-slot headers
        invalid_headers = ['important notes', 'set bonuses', 'weapons', 'armor', 'accessories', 'guides', 'change log']
        if any(ih in slot_name.lower() for ih in invalid_headers) or len(slot_name) > 30:
            continue
            
        tbl_content = tbl_match.group(1)
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', tbl_content, re.IGNORECASE | re.DOTALL)
        if len(rows) < 2:
            continue
            
        # Check first row header
        header_cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', rows[0], re.IGNORECASE | re.DOTALL)
        header_text = "".join(header_cells).lower()
        if 'item' not in header_text:
            continue
            
        # Determine column index of "Item"
        item_col = 0
        for ci, ch in enumerate(header_cells):
            if 'item' in clean(ch).lower():
                item_col = ci
                break
                
        rank = 0
        for row in rows[1:]:
            cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.IGNORECASE | re.DOTALL)
            if len(cells) <= item_col:
                continue
                
            item_cell = cells[item_col]
            m_link = item_link_re.search(item_cell)
            if not m_link:
                # Try search in any cell
                for cell in cells:
                    m_link = item_link_re.search(cell)
                    if m_link:
                        break
                        
            if not m_link:
                continue
                
            item_id = int(m_link.group(1))
            item_name = clean(item_cell)
            
            # If name is blank in item_cell (sometimes link is empty text), fallback to clean cell text
            if not item_name:
                item_name = clean(row)
                
            spec_items.append({
                "Slot": slot_name,
                "Rank": rank,
                "Id": item_id,
                "Name": item_name
            })
            rank += 1
            
    print(f"  Found {len(spec_items)} items for {spec}.")
    all_bis[spec] = spec_items

with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(all_bis, f, indent=4, ensure_ascii=False)

print("\nSummary:")
for spec, items in all_bis.items():
    print(f"  {spec}: {len(items)} items")
print(f"Saved to {output_path}")
