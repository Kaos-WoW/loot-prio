"""BiS-Listen aller 17 Specs fuer Phase 3, 4 und 5 von Wowhead holen.

Loest scrape_bis.py (warcrafttavern) und scrape_wowhead_final.py (nur Phase 3) ab.
Quelle ist ausschliesslich Wowhead - ausdrueckliche Vorgabe des Nutzers.

Ausgabe: daten/bis-listen-phasen.json in der Form
    { "3": { "RET": [ {Slot, Rank, Id, Name}, ... ], ... }, "4": {...}, "5": {...} }

Aufruf:
    python daten/scrape-bis-wowhead.py            # alle Phasen
    python daten/scrape-bis-wowhead.py 4 5        # nur bestimmte (ergaenzt die Datei)

★ Die URLs unterscheiden sich zwischen den Phasen NUR im Raid-Kuerzel. Alle 51
Kombinationen wurden am 2026-08-10 einzeln geprueft: alle erreichbar, alle mit
Item-Links gefuellt, keine Ausnahme noetig. Wer eine Phase ergaenzt, prueft die
neuen URLs bitte genauso, bevor er sich auf sie verlaesst - Wowhead liefert fuer
unbekannte Guides teils HTTP 200 mit einer leeren Platzhalterseite, ein reiner
Statuscode-Check reicht deshalb NICHT.
"""
import concurrent.futures
import html as html_module
import json
import os
import re
import subprocess
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "daten", "bis-listen-phasen.json")

# Spec-Praefix der Guide-URL. Achtung: heisst nicht wie der Spec-Key -
# Schutz-Paladin laeuft als "paladin-tank", Heilig-Priester als "priest-healer".
PREFIX = {
    "FURY":        "fury-warrior-dps",
    "ARMS":        "arms-warrior-dps",
    "RET":         "retribution-paladin-dps",
    "ENH":         "enhancement-shaman-dps",
    "ROGUE":       "rogue-dps",
    "HUNT":        "beast-mastery-hunter-dps",
    "WLCK":        "destruction-warlock-dps",
    "MAGE":        "arcane-mage-dps",
    "SPRI":        "shadow-priest-dps",
    "ELE":         "elemental-shaman-dps",
    "BAL":         "balance-druid-dps",
    "FERAL_TANK":  "feral-druid-tank",
    "PROT_PALA":   "paladin-tank",
    "RESTO_SHAM":  "shaman-healer",
    "HOLY_PALA":   "holy-paladin-healer",
    "RESTO_DRUID": "druid-healer",
    "HOLY_PRIEST": "priest-healer",
}

RAID = {"3": "bt-hyjal-phase-3", "4": "za-phase-4", "5": "swp-phase-5"}
URL = "https://www.wowhead.com/tbc/guide/{prefix}-{raid}-best-in-slot-gear-burning-crusade"

# Unter wie vielen Item-Links eine Seite als "nicht wirklich befuellt" gilt.
MIN_ITEMS = 5


def clean(s):
    return html_module.unescape(re.sub(r"<[^>]+>", "", s)).strip()


def normalize_slot(s, spec=None):
    s = s.lower()
    if "head" in s or "helm" in s: return "Head"
    if "neck" in s or "amulet" in s: return "Neck"
    if "shoulder" in s: return "Shoulders"
    if "back" in s or "cloak" in s: return "Back"
    if "chest" in s or "robe" in s: return "Chest"
    if "wrist" in s or "bracer" in s: return "Wrists"
    if "hand" in s or "glove" in s: return "Hands"
    if "waist" in s or "belt" in s: return "Waist"
    if "leg" in s: return "Legs"
    if "feet" in s or "boot" in s: return "Feet"
    if "finger" in s or "ring" in s: return "Fingers"
    if "trinket" in s: return "Trinkets"
    if "main hand" in s or "one-hand" in s: return "Main Hand"
    if "off hand" in s or "shield" in s or "held" in s: return "Off Hand"
    if "two-hand" in s: return "Two-Hand"
    if "weapon" in s:
        return "Two-Hand" if spec == "RET" else "Main Hand"
    if any(w in s for w in ("ranged", "bow", "gun", "relic", "libram", "idol", "totem")):
        return "Ranged"
    return None


def hole(url):
    r = subprocess.run(
        ["curl.exe", "-s", "-L", "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)", url],
        capture_output=True, text=True, encoding="utf-8", errors="ignore")
    return r.stdout or ""


def parse(html_content, spec):
    kopf = list(re.finditer(r"<h([234])[^>]*>(.*?)</h\1>", html_content, re.I | re.S))
    items = []
    for i, m in enumerate(kopf):
        slot = normalize_slot(clean(m.group(2)), spec)
        if not slot:
            continue
        ende = kopf[i + 1].start() if i + 1 < len(kopf) else len(html_content)
        abschnitt = html_content[m.end():ende]
        rang = 0
        for row in re.findall(r"<tr[^>]*>(.*?)</tr>", abschnitt, re.I | re.S):
            # Kopfzeile ueberspringen - aber NUR die echte. Ein Substring-Filter auf
            # "item" wuerde Zeilen mit Woertern wie "devastation" mitfiltern.
            rl = row.lower()
            if "<b>item</b>" in rl or "<th>item</th>" in rl or "<td>item</td>" in rl:
                continue
            treffer = re.search(r'href="[^"]*(?:item[=/])(\d+)[^"]*">(.*?)</a>', row, re.I | re.S)
            if not treffer:
                continue
            zellen = re.findall(r"<td[^>]*>(.*?)</td>", row, re.I | re.S)
            r_ = rang
            if zellen:
                c0 = clean(zellen[0]).lower()
                if "best" in c0 or "bis" in c0:
                    r_ = 0
                elif "alt" in c0 or "opt" in c0:
                    r_ = max(1, rang)
            items.append({"Slot": slot, "Rank": r_,
                          "Id": int(treffer.group(1)), "Name": clean(treffer.group(2))})
            rang += 1
    return items


def eine(phase, spec):
    url = URL.format(prefix=PREFIX[spec], raid=RAID[phase])
    roh = hole(url)
    if not roh or roh.count("/tbc/item=") < MIN_ITEMS:
        return phase, spec, None, url
    return phase, spec, parse(roh, spec), url


def main():
    phasen = [a for a in sys.argv[1:] if a in RAID] or list(RAID)
    auftraege = [(p, s) for p in phasen for s in PREFIX]
    print(f"Hole {len(auftraege)} Guides (Phasen {', '.join(phasen)}) ...")

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:
        ergebnisse = list(ex.map(lambda a: eine(*a), auftraege))

    # Bestehende Datei ergaenzen statt ersetzen, damit ein Teillauf die anderen
    # Phasen nicht wegwirft.
    alles = {}
    if os.path.exists(OUT):
        with open(OUT, encoding="utf-8-sig") as f:
            alles = json.load(f)

    fehler = []
    for phase, spec, items, url in sorted(ergebnisse):
        if items is None or len(items) < MIN_ITEMS:
            fehler.append((phase, spec, url, 0 if items is None else len(items)))
            continue
        alles.setdefault(phase, {})[spec] = items

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(alles, f, indent=1, ensure_ascii=False)

    print()
    for phase in sorted(alles):
        specs = alles[phase]
        gesamt = sum(len(v) for v in specs.values())
        print(f"  Phase {phase}: {len(specs)} Specs, {gesamt} Eintraege")
    if fehler:
        print(f"\n!! {len(fehler)} Guides ohne verwertbaren Inhalt - NICHT uebernommen:")
        for phase, spec, url, n in fehler:
            print(f"   Phase {phase} {spec} ({n} Eintraege): {url}")
        sys.exit(1)
    print(f"\nGeschrieben: {OUT}")


if __name__ == "__main__":
    main()
