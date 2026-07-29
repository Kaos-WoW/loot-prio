import os
import re
import json
import subprocess
import html as html_module

SPECS = {
    "FURY": "https://www.wowhead.com/tbc/guide/fury-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ARMS": "https://www.wowhead.com/tbc/guide/arms-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RET": "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ENH": "https://www.wowhead.com/tbc/guide/enhancement-shaman-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ROGUE": "https://www.wowhead.com/tbc/guide/rogue-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "HUNT": "https://www.wowhead.com/tbc/guide/beast-mastery-hunter-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "WLCK": "https://www.wowhead.com/tbc/guide/destruction-warlock-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "MAGE": "https://www.wowhead.com/tbc/guide/arcane-mage-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "SPRI": "https://www.wowhead.com/tbc/guide/shadow-priest-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "ELE": "https://www.wowhead.com/tbc/guide/elemental-shaman-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "BAL": "https://www.wowhead.com/tbc/guide/balance-druid-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "FERAL_TANK": "https://www.wowhead.com/tbc/guide/feral-druid-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "PROT_PALA": "https://www.wowhead.com/tbc/guide/paladin-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RESTO_SHAM": "https://www.wowhead.com/tbc/guide/shaman-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "HOLY_PALA": "https://www.wowhead.com/tbc/guide/holy-paladin-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "RESTO_DRUID": "https://www.wowhead.com/tbc/guide/druid-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade",
    "HOLY_PRIEST": "https://www.wowhead.com/tbc/guide/priest-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
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
    print(f"Fetching {url} via curl.exe...")
    try:
        r = subprocess.run(['curl.exe', '-s', '-L', '-A', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', url], capture_output=True, text=True, encoding='utf-8', errors='ignore')
        html_content = r.stdout
    except Exception as e:
        print(f"  Error fetching: {e}")
        return None

    if not html_content or "404 Not Found" in html_content or "Error 404" in html_content:
        print("  Not found (404)")
        return None

    h_matches = list(re.finditer(r'<h([234])[^>]*>(.*?)</h\1>', html_content, re.IGNORECASE | re.DOTALL))
    spec_items = []
    
    for i in range(len(h_matches)):
        m = h_matches[i]
        header_text = clean(m.group(2))
        
        slot = normalize_slot(header_text)
        if not slot:
            continue
            
        start_pos = m.end()
        end_pos = h_matches[i+1].start() if i + 1 < len(h_matches) else len(html_content)
        section_html = html_content[start_pos:end_pos]
        
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', section_html, re.IGNORECASE | re.DOTALL)
        if not rows:
            continue
            
        rank_counter = 0
        for row in rows:
            if 'item' in row.lower() and ('source' in row.lower() or 'stat' in row.lower()):
                continue
                
            item_match = re.search(r'href="[^"]*(?:item[=/])(\d+)[^"]*">(.*?)</a>', row, re.IGNORECASE | re.DOTALL)
            if not item_match:
                continue
                
            item_id = int(item_match.group(1))
            item_name = clean(item_match.group(2))
            
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
    out_file = os.path.join(out_dir, "bis-listen.json")
    
    existing_data = {}
    if os.path.exists(out_file):
        try:
            with open(out_file, 'r', encoding='utf-8') as f:
                existing_data = json.load(f)
            print(f"Loaded existing data with {len(existing_data)} specs.")
        except Exception as e:
            print(f"Failed to load existing bis-listen.json: {e}")
            
    results = {}
    for spec, url in SPECS.items():
        data = scrape_spec(url)
        if data:
            results[spec] = data
            print(f"  => {spec}: Scraped {len(data)} items")
        else:
            if spec in existing_data:
                results[spec] = existing_data[spec]
                print(f"  => {spec}: Failed to scrape, keeping existing ({len(results[spec])} items)")
            else:
                results[spec] = []
                print(f"  => {spec}: Failed and no existing data")
                
    for spec, items in existing_data.items():
        if spec not in results:
            results[spec] = items
            print(f"  => {spec}: Keeping existing spec data ({len(items)} items)")
            
    with open(out_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=4, ensure_ascii=False)
        
    print(f"\nSaved to {out_file}")

if __name__ == '__main__':
    main()
