import urllib.request
import json
import re
import os

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
    "BAL": "https://www.wowhead.com/tbc/guide/balance-druid-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
}

OUTPUT_FILE = r"c:\Users\maxim\OneDrive\Documents\Skripte&Codes&Addons\TBC-Lootprio\daten\bis-listen.json"

def fetch_url(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req) as response:
            return response.read().decode('utf-8')
    except Exception as e:
        print(f"Failed to fetch {url}: {e}")
        return None

def parse_wowhead_html(html):
    # Wowhead guides often store the guide content in a JSON script tag with id starting with data.wowhead-guid
    # The content is usually BBCode like [h2]Head[/h2] or [h3]Alternative[/h3] and [item=12345] or [url=.../item=12345]Name[/url]
    
    # We will look for WH.Gatherer.addData to map item IDs to names
    item_names = {}
    for match in re.finditer(r'WH\.Gatherer\.addData\(\d+,\s*\d+,\s*(\{.*?\})\);', html):
        try:
            data = json.loads(match.group(1))
            for item_id, item_info in data.items():
                if 'name_enus' in item_info:
                    item_names[int(item_id)] = item_info['name_enus']
        except:
            pass

    # Extract all the markup data
    bbcode = ""
    for match in re.finditer(r'<script type="application/json" id="data\.wowhead-guid[^"]*">"(.*?)"</script>', html):
        bbcode += match.group(1).encode('utf-8').decode('unicode_escape') + "\n"

    items = []
    current_slot = "Unknown"
    current_rank = 0
    
    # Parse BBCode line by line
    lines = bbcode.split('\n')
    
    slots = ["Head", "Neck", "Shoulders", "Chest", "Back", "Wrists", "Hands", "Waist", "Legs", "Feet", "Fingers", "Rings", "Trinkets", "Main Hand", "Off Hand", "Two Hand", "Ranged", "Relic", "Totem", "Idol", "Libram"]
    
    for line in lines:
        # Check for slot headers
        header_match = re.search(r'\[h[234]\](.*?)\[/h[234]\]', line)
        if header_match:
            header_text = header_match.group(1)
            is_slot = False
            for s in slots:
                if s.lower() in header_text.lower():
                    current_slot = s
                    current_rank = 0
                    is_slot = True
                    break
            if not is_slot:
                if "alternative" in header_text.lower() or "optional" in header_text.lower() or "other" in header_text.lower():
                    current_rank += 1
                
        # Check for items
        item_matches = re.finditer(r'\[(?:url=[^\]]*item=|item=)(\d+)[^\]]*\](.*?)\[/(?:url|item)\]', line)
        for im in item_matches:
            item_id = int(im.group(1))
            name = im.group(2).strip()
            if not name:
                name = item_names.get(item_id, f"Item {item_id}")
            
            # Clean up name if it has html or bbcode
            name = re.sub(r'\[.*?\]', '', name)
            name = name.replace('\\/', '/')
            
            items.append({
                "Slot": current_slot,
                "Rank": current_rank,
                "Id": item_id,
                "Name": name
            })
            current_rank += 1 # Often lists are ranked 1,2,3... within the slot, or it's a table. 
            
    # Remove duplicates while preserving order
    seen = set()
    unique_items = []
    for item in items:
        key = (item["Slot"], item["Id"])
        if key not in seen:
            seen.add(key)
            unique_items.append(item)

    return unique_items

def main():
    results = {}
    for spec, url in SPECS.items():
        print(f"Fetching {spec}...")
        html = fetch_url(url)
        if html:
            items = parse_wowhead_html(html)
            results[spec] = items
            print(f"Found {len(items)} items for {spec}.")
        else:
            results[spec] = []
            
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=4, ensure_ascii=False)
    print(f"Saved to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
