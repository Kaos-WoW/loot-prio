"""Item-Pool der Phase-4- und Phase-5-Raids von Wowhead holen.

Zul'Aman (Phase 4) und Sunwell Plateau (Phase 5), boss-weise aus den NPC-Seiten.
Ausgabe: quellen/p4-item-pool.json bzw. p5-item-pool.json in der Form
    { "Boss": [ {"Id":..., "Name":..., "SlotCode":..., "ClassCode":..., "SubCode":...}, ... ] }

Warum boss-weise und nicht ueber die Zonen-Uebersicht: die Listview der Zone ist
unvollstaendig - beim Black Temple fehlte Teron Blutschatten mit 12 Items komplett
(siehe AGENTS.md). Pro Boss-NPC ist die einzige verlaessliche Quelle.

★ Bosse werden NICHT hartcodiert, sondern aus der Zonenseite als
classification == 3 gelesen. Darunter sind auch Nebenaktoren ohne Loot
(Geister, Event-NPCs); die fallen von selbst raus, weil ihre Drop-Tabelle
keine ausruestbaren Epics enthaelt. Das ist robuster als eine Bossliste
aus dem Gedaechtnis.

⚠️ Der Schluessel der Drop-Tabelle heisst auf manchen Seiten `data:[` OHNE
Leerzeichen und auf anderen `data: [` MIT - AGENTS.md warnte bisher nur vor
der einen Richtung. Beide Formen werden abgedeckt.

Aufruf:
    python daten/scrape-pool-wowhead.py          # Phase 4 und 5
    python daten/scrape-pool-wowhead.py 5        # nur Sunwell
"""
import json
import os
import re
import subprocess
import sys
import time

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIEL = os.path.join(BASE, "quellen")

ZONEN = {
    "4": (3805, "Zul'Aman"),
    "5": (4075, "Sunwell Plateau"),
}

# ★ Sunwell bringt eine EIGENE Tier-Token-Familie: "Bracers/Belt/Boots of the
# Forgotten Conqueror/Protector/Vanquisher" (ilvl 154). Die Token droppen im Raid,
# das Ruestungsteil holt man sich damit beim Haendler - genau wie bei Tier 6.
# Beides muss in den Pool: die Token als Drop (der Loot-Rat vergibt SIE), die
# eingetauschten Teile als bewertbare Gegenstaende.
TOKEN_MUSTER = re.compile(r"of the Forgotten (Conqueror|Protector|Vanquisher)", re.I)

# Haendler, die die Token-Teile herausgeben. Nur ausruestbare Epics werden genommen.
HAENDLER = {
    "5": [(25976, "Tier 6.5 (Sunwell-Haendler)")],
}

# Abzeichen-Items. Die Marke selbst ist Item 29434; ihre "currency-for"-Liste
# enthaelt ALLE Marken-Items aller Phasen. Die aus Phase 1 stecken schon im
# P3-Pool, deshalb wird ueber das Gegenstandsstufen-Minimum abgegrenzt:
# ab 2.4 kamen ilvl 141 und 146 dazu.
MARKE = 29434
MARKEN_MIN_ILVL = {"4": 141, "5": 141}

AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"


def hole(url, versuche=3):
    for n in range(versuche):
        r = subprocess.run(["curl.exe", "-s", "-L", "-A", AGENT, url],
                           capture_output=True, text=True, encoding="utf-8", errors="ignore")
        if r.stdout and len(r.stdout) > 5000:
            return r.stdout
        time.sleep(1.5 * (n + 1))
    return ""


def listview(html_text, listen_id):
    """Das data-Array einer Wowhead-Listview als Python-Objekt zurueckgeben."""
    i = html_text.find(f"id: '{listen_id}'")
    if i < 0:
        i = html_text.find(f'id: "{listen_id}"')
    if i < 0:
        return None
    # data: [   ODER   data:[
    m = re.compile(r"data:\s*\[").search(html_text, i)
    if not m:
        return None
    start = m.end() - 1
    tiefe = 0
    for n in range(start, len(html_text)):
        c = html_text[n]
        if c == "[":
            tiefe += 1
        elif c == "]":
            tiefe -= 1
            if tiefe == 0:
                try:
                    return json.loads(html_text[start:n + 1])
                except json.JSONDecodeError:
                    return None
    return None


def bosse(zone_id):
    roh = hole(f"https://www.wowhead.com/tbc/zone={zone_id}")
    daten = listview(roh, "npcs")
    if daten is None:
        raise RuntimeError(f"NPC-Listview der Zone {zone_id} nicht lesbar")
    return [(x["id"], x["name"]) for x in daten if x.get("classification") == 3]


def eintrag(it, quelle):
    return {
        "Id": it["id"],
        "Name": it.get("name", ""),
        "SlotCode": it.get("slot", -1),
        "ClassCode": it.get("classs", -1),
        "SubCode": it.get("subclass", -99),
        "Ilvl": it.get("level", 0),
        "Quelle": quelle,
    }


def drops(npc_id):
    roh = hole(f"https://www.wowhead.com/tbc/npc={npc_id}")
    daten = listview(roh, "drops")
    if daten is None:
        return []
    raus = []
    for it in daten:
        if it.get("quality", 0) < 4:
            continue
        if it.get("slot"):
            raus.append(eintrag(it, "Raid"))
        elif TOKEN_MUSTER.search(it.get("name", "")):
            # Token: kein Slot, keine Werte - aber der Loot-Rat vergibt genau diese.
            raus.append(eintrag(it, "Token"))
        # alles andere mit slot == 0 (Marken, Rezepte, Rufgegenstaende) faellt raus
    return raus


def haendler_items(npc_id, quelle):
    roh = hole(f"https://www.wowhead.com/tbc/npc={npc_id}")
    daten = listview(roh, "sells")
    if daten is None:
        return []
    return [eintrag(it, quelle) for it in daten
            if it.get("quality", 0) >= 4 and it.get("slot")]


def marken_items(min_ilvl):
    roh = hole(f"https://www.wowhead.com/tbc/item={MARKE}")
    daten = listview(roh, "currency-for")
    if daten is None:
        return []
    return [eintrag(it, "Marken") for it in daten
            if it.get("quality", 0) >= 4 and it.get("slot")
            and it.get("level", 0) >= min_ilvl]


def phase_bauen(phase):
    zone_id, raid = ZONEN[phase]
    print(f"=== Phase {phase}: {raid} (zone={zone_id})")
    liste = bosse(zone_id)
    print(f"    {len(liste)} NPCs mit classification=3")
    pool, leer = {}, []
    gesehen = set()
    for npc_id, name in liste:
        items = drops(npc_id)
        # Doppelte ueber Bosse hinweg vermeiden (z.B. Kalecgos mehrfach im Encounter)
        neu = [i for i in items if i["Id"] not in gesehen]
        for i in neu:
            gesehen.add(i["Id"])
        if not neu:
            leer.append(name)
            continue
        pool.setdefault(name, []).extend(neu)
        print(f"    {name:<28} {len(neu):>3} Items")
    if leer:
        print(f"    ohne verwertbaren Loot (erwartet fuer Event-NPCs): {', '.join(leer)}")

    for npc_id, bezeichnung in HAENDLER.get(phase, []):
        items = [i for i in haendler_items(npc_id, "Tier") if i["Id"] not in gesehen]
        for i in items:
            gesehen.add(i["Id"])
        if items:
            pool[bezeichnung] = items
            print(f"    {bezeichnung:<28} {len(items):>3} Items (Haendler {npc_id})")

    if phase in MARKEN_MIN_ILVL:
        items = [i for i in marken_items(MARKEN_MIN_ILVL[phase]) if i["Id"] not in gesehen]
        for i in items:
            gesehen.add(i["Id"])
        if items:
            pool["Haendler (Abzeichen)"] = items
            print(f"    {'Haendler (Abzeichen)':<28} {len(items):>3} Items "
                  f"(ab ilvl {MARKEN_MIN_ILVL[phase]})")

    ziel = os.path.join(ZIEL, f"p{phase}-item-pool.json")
    with open(ziel, "w", encoding="utf-8") as f:
        json.dump(pool, f, indent=1, ensure_ascii=False)
    gesamt = sum(len(v) for v in pool.values())
    print(f"    -> {ziel}: {len(pool)} Bosse, {gesamt} Items\n")
    return gesamt


def main():
    os.makedirs(ZIEL, exist_ok=True)
    phasen = [a for a in sys.argv[1:] if a in ZONEN] or list(ZONEN)
    summe = sum(phase_bauen(p) for p in phasen)
    if summe == 0:
        print("!! Nichts gefunden - Seitenstruktur geaendert?")
        sys.exit(1)


if __name__ == "__main__":
    main()
