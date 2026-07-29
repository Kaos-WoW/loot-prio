import os
import re
import json
import requests
import html as html_module

SPECS = {
    "FURY": "https://www.wowhead.com/tbc/guide/fury-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ARMS": "https://www.wowhead.com/tbc/guide/arms-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RET": "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ENH": "https://www.wowhead.com/tbc/guide/enhancement-shaman-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ROGUE": "https://www.wowhead.com/tbc/guide/combat-rogue-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "HUNT": "https://www.wowhead.com/tbc/guide/beast-mastery-hunter-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "WLCK": "https://www.wowhead.com/tbc/guide/destruction-warlock-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "MAGE": "https://www.wowhead.com/tbc/guide/arcane-mage-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "SPRI": "https://www.wowhead.com/tbc/guide/shadow-priest-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ELE": "https://www.wowhead.com/tbc/guide/elemental-shaman-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "BAL": "https://www.wowhead.com/tbc/guide/balance-druid-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "PROT_PALA": "https://www.wowhead.com/tbc/guide/protection-paladin-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "FERAL_TANK": "https://www.wowhead.com/tbc/guide/feral-druid-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RESTO_SHAM": "https://www.wowhead.com/tbc/guide/restoration-shaman-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "HOLY_PRIEST": "https://www.wowhead.com/tbc/guide/holy-priest-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RESTO_DRUID": "https://www.wowhead.com/tbc/guide/restoration-druid-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "HOLY_PALA": "https://www.wowhead.com/tbc/guide/holy-paladin-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
}

FALLBACKS = {
    "ROGUE": "https://www.wowhead.com/tbc/guide/rogue-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
}

# Known slots mapping to keep them clean
SLOTS = [
    'Head', 'Neck', 'Shoulders', 'Back', 'Chest', 'Wrists', 'Hands', 'Waist', 'Legs', 'Feet',
    'Fingers', 'Rings', 'Trinkets', 'Main Hand', 'Off Hand', 'Two-Hand', 'Ranged', 'Relic'
]

def clean(s):
    s = re.sub(r'<[^>]+>', '', s)
    return html_module.unescape(s).strip()

def normalize_slot(s):
    s = s.lower()
    if 'head' in s or 'helm' in s: return 'Head'
    if 'neck' in s or 'amulet' in s: return 'Neck'
    if 'shoulder' in s: return 'Shoulders'
    if 'back' in s or 'cloak' in s: return 'Back'
    if 'chest' in s or 'robe' in s: return 'Chest'
    if 'wrist' in s or 'bracer' in s: return 'Wrists'
    if 'hand' in s or 'glove' in s: return 'Hands'
    if 'waist' in s or 'belt' in s: return 'Waist'
    if 'leg' in s: return 'Legs'
    if 'feet' in s or 'boot' in s: return 'Feet'
    if 'finger' in s or 'ring' in s: return 'Fingers'
    if 'trinket' in s: return 'Trinkets'
    if 'main hand' in s or 'one-hand' in s: return 'Main Hand'
    if 'off hand' in s or 'shield' in s or 'held' in s: return 'Off Hand'
    if 'two-hand' in s: return 'Two-Hand'
    if 'ranged' in s or 'bow' in s or 'gun' in s or 'relic' in s or 'libram' in s or 'idol' in s or 'totem' in s: return 'Ranged'
    return None

def scrape_spec(url):
    print(f"Fetching {url}")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        r = requests.get(url, headers=headers, timeout=20)
    except Exception as e:
        print(f"  Error fetching: {e}")
        return None
    if r.status_code == 404:
        return None

    html_content = r.text

    # Let's find all headers: <h2 ...> or <h3 ...>
    # e.g., <h3 class="heading-size-3">Best in Slot Head Armor for...</h3>
    h_matches = list(re.finditer(r'<h([234])[^>]*>(.*?)</h\1>', html_content, re.IGNORECASE | re.DOTALL))
    
    spec_items = []
    
    for i in range(len(h_matches)):
        m = h_matches[i]
        header_text = clean(m.group(2))
        
        # Check if the header contains a slot name
        slot = normalize_slot(header_text)
        if not slot:
            continue
            
        # Get content between this header and the next header
        start_pos = m.end()
        end_pos = h_matches[i+1].start() if i + 1 < len(h_matches) else len(html_content)
        section_html = html_content[start_pos:end_pos]
        
        # Within this section, parse all rows <tr>...</tr>
        # Regex matching <tr> and everything inside it up to </tr>
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', section_html, re.IGNORECASE | re.DOTALL)
        if not rows:
            continue
            
        # Skip the header row (contains "Item", "Source", etc.)
        rank_counter = 0
        for row in rows:
            if 'item' in row.lower() and ('source' in row.lower() or 'stat' in row.lower()):
                continue
                
            # Find item link: /item=NNNNN or /item/NNNNN
            # e.g., <a href="/tbc/item=32235/cursed-vision-of-sargeras">Cursed Vision of Sargeras</a>
            item_match = re.search(r'href="[^"]*(?:item[=/])(\d+)[^"]*">(.*?)</a>', row, re.IGNORECASE | re.DOTALL)
            if not item_match:
                continue
                
            item_id = int(item_match.group(1))
            item_name = clean(item_match.group(2))
            
            # Determine Rank
            # Usually the first column td contains "Best", "Optional", "Alt", "Rank 1", etc.
            # Let's extract cells: <td>...</td>
            cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.IGNORECASE | re.DOTALL)
            rank = rank_counter
            if cells:
                col0 = clean(cells[0]).lower()
                if 'best' in col0 or 'bis' in col0:
                    rank = 0
                elif 'alt' in col0 or 'opt' in col0:
                    rank = max(1, rank_counter)
                    
            spec_items.append({
                "Slot": slot,
                "Rank": rank,
                "Id": item_id,
                "Name": item_name
            })
            rank_counter += 1
            
    return spec_items

def main():
    out_dir = r"c:\Users\maxim\OneDrive\Documents\Skripte&Codes&Addons\TBC-Lootprio\daten"
    os.makedirs(out_dir, exist_ok=True)
    
    results = {}
    for spec, url in SPECS.items():
        data = scrape_spec(url)
        if data is None and spec in FALLBACKS:
            print(f"  {spec} 404'd. Trying fallback.")
            data = scrape_spec(FALLBACKS[spec])
            
        if data:
            results[spec] = data
            print(f"  => {spec}: Scraped {len(data)} items")
        else:
            results[spec] = []
            print(f"  => {spec}: Failed to scrape or empty")
            
    out_file = os.path.join(out_dir, "bis-listen.json")
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=4, ensure_ascii=False)
        
    print(f"\nSaved to {out_file}")

if __name__ == '__main__':
    main()
