"""
Schritt 6: Schmuckstuecke per Differenzsimulation bewerten.

Warum ueberhaupt: Der Wert eines Schmuckstuecks steckt fast ganz in Prokks und Nutzeneffekten.
Die statische Naeherung in 3-compute.ps1 ($TRINKET_EFFECTS, "Methode A") mittelt den Prokk zu
einem Dauerwert und multipliziert ihn mit linearen Statgewichten. Gegen die Simulation gemessen
liegt sie nicht nur daneben, sondern im falschen Vorzeichen: fuer Kaosx sagt das Modell bei
Madness of the Betrayer +30 DPS, die Sim sagt -21 DPS.

Dieses Skript umgeht die Frage nach der Prokk-Uptime vollstaendig: Es tauscht das Schmuckstueck
im echten Gear des Spielers aus und misst die DPS-Differenz direkt. Eine Sim dauert rund zwei
Sekunden.

Ablauf je Spieler:
  1. Spec-Konfiguration aus spec-sims/specs.json + Rotation aus spec-sims/apls/<SPEC>.apl.json
     + gemeinsamer Raid-Aufbau aus spec-sims/raid-setup.json.
  2. Echtes Gear des Spielers aus daten/players.json einsetzen.
  3. Basis-Sim, dann je Kandidat eine Sim mit getauschtem Schmuckstueck.
  4. Ergebnis nach daten/trinket-werte.json.

Getauscht wird gegen BEIDE getragenen Schmuckstuecke, gewertet wird der bessere Tausch - das ist
dieselbe Regel, die 3-compute.ps1 fuer Ringe und Schmuck benutzt.

Der Raid-Aufbau (Buffs, Debuffs, Encounter) ist fuer alle Specs absichtlich identisch. Nur so sind
die DPS-Zahlen zwischen Specs vergleichbar - genau das war bei den statischen Presets offen.

Aufruf:
    python 6-trinket-sim.py             # alle Spieler mit hinterlegter Spec
    python 6-trinket-sim.py Kaosx       # nur bestimmte Spieler
"""

import copy
import json
import os
import re
import subprocess
import sys
import tempfile

BASE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(BASE, "bin", "wowsimcli-windows.exe")
SPEC_DIR = os.path.join(BASE, "spec-sims")
OUT = os.path.join(BASE, "daten", "trinket-werte.json")

ITERATIONS = 10000          # Streuung dadurch rund 0,1 DPS - klein genug fuer Vergleiche

# Reihenfolge der Ausruestungsslots in der Sim-Anfrage. Die Sim ordnet ueber die Position,
# nicht ueber einen Namen - diese Liste darf sich nicht verschieben.
SLOT_ORDER = ["HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST",
              "LEGS", "FEET", "FINGER_1", "FINGER_2", "TRINKET_1", "TRINKET_2",
              "MAIN_HAND", "OFF_HAND", "RANGED"]
IDX_T1 = SLOT_ORDER.index("TRINKET_1")
IDX_T2 = SLOT_ORDER.index("TRINKET_2")

# Klasse laut Spec-Konfiguration -> Klassenname, wie er im Tooltip unter "Classes:" steht.
KLASSE_ZU_TOOLTIP = {
    "ClassWarrior": "Warrior", "ClassPaladin": "Paladin", "ClassHunter": "Hunter",
    "ClassRogue": "Rogue", "ClassPriest": "Priest", "ClassShaman": "Shaman",
    "ClassMage": "Mage", "ClassWarlock": "Warlock", "ClassDruid": "Druid",
}


def lade(pfad):
    with open(pfad, encoding="utf-8-sig") as f:
        return json.load(f)


def hole_cli():
    """WoWSims-CLI herunterladen, falls sie fehlt.

    Die 22-MB-Binaerdatei liegt bewusst NICHT im Repo (siehe .gitignore). Diese Logik
    steckte frueher nur in wowsims-cli.ps1 - ohne sie schlaegt der Lauf auf einem
    frischen Checkout (z.B. GitHub Actions) fehl.
    """
    if os.path.exists(EXE):
        return
    import urllib.request
    import zipfile
    url = "https://github.com/wowsims/tbc-new/releases/latest/download/wowsimcli-windows.exe.zip"
    ziel = os.path.dirname(EXE)
    os.makedirs(ziel, exist_ok=True)
    zippfad = os.path.join(ziel, "wowsims.zip")
    print(f"Lade WoWSims-CLI herunter ({url}) ...")
    urllib.request.urlretrieve(url, zippfad)
    with zipfile.ZipFile(zippfad) as z:
        z.extractall(ziel)
    os.remove(zippfad)
    if not os.path.exists(EXE):
        raise RuntimeError("Download lief durch, aber " + EXE + " fehlt weiterhin.")
    print("CLI bereit.")


def klassenbindung(tooltip):
    """Gibt die Klassenliste eines Schmuckstuecks zurueck, oder None wenn es frei ist.

    Wichtig: Ein klassengebundenes Schmuckstueck an der falschen Klasse laesst die Sim
    ABSTUERZEN (z.B. Serpent-Coil Braid am Paladin -> 'not mage.MageAgent'). Diese Zeilen
    muessen also vorher aussortiert werden, nicht erst im Fehlerfall.
    """
    m = re.search(r"Classes:\s*([A-Za-z, ]+)", re.sub(r"<[^>]+>", " ", tooltip or ""))
    if not m:
        return None
    return {k.strip() for k in m.group(1).split(",") if k.strip()}


def baue_anfrage(spec_cfg, setup, apl, name):
    profil = setup["profile"][spec_cfg["profil"]]
    spieler = {
        "name": name,
        "race": spec_cfg["rasse"],
        "class": spec_cfg["klasse"],
        # Der Talentstring gehoert HIERHER, nicht in den Spec-Block. Steht er dort, wird er
        # stillschweigend ignoriert und die Sim rechnet talentlos (siehe AGENTS.md).
        "talentsString": spec_cfg["talente"],
        spec_cfg["specKey"]: {"options": {"classOptions": {}}},
        "equipment": {"items": []},
        "consumables": profil["consumables"],
        "buffs": profil["buffs"],
        "rotation": apl,
    }
    return {
        "simOptions": {"iterations": ITERATIONS, "randomSeed": 101},
        "raid": {
            "parties": [{"players": [spieler], "buffs": setup["partyBuffs"]}],
            "buffs": setup["raidBuffs"],
            "debuffs": setup["debuffs"],
        },
        "encounter": setup["encounter"],
    }


def sim(anfrage):
    # ⚠️ Die Dateinamen MUESSEN prozesseigen sein. Vorher hiessen sie fest
    # ts_in/ts_out.json: zwei gleichzeitig laufende Simulationen (z.B. ein Lauf
    # fuer Phase 3 und einer fuer Phase 5) haben sich dann gegenseitig die
    # Ausgabedatei geloescht. Der Abbruch sieht dabei irrefuehrend aus - die CLI
    # meldet "All 16 sims finished successfully", und trotzdem fehlt das Ergebnis.
    fi = os.path.join(tempfile.gettempdir(), f"ts_in_{os.getpid()}.json")
    fo = os.path.join(tempfile.gettempdir(), f"ts_out_{os.getpid()}.json")
    if os.path.exists(fo):
        os.remove(fo)
    with open(fi, "w", encoding="utf-8") as f:
        json.dump(anfrage, f)
    r = subprocess.run([EXE, "sim", "--infile", fi, "--outfile", fo],
                       capture_output=True, text=True)
    if not os.path.exists(fo):
        raise RuntimeError("Sim ohne Ergebnis: " + (r.stdout + r.stderr)[-400:])
    with open(fo, encoding="utf-8") as f:
        erg = json.load(f)
    if erg.get("error"):
        raise RuntimeError(erg["error"].get("message", "unbekannter Sim-Fehler").split("\n")[0])
    return erg["raidMetrics"]["dps"]["avg"]


def main():
    # --phase N waehlt den Item-Pool. Ohne Angabe Phase 3 wie bisher.
    # Die Ergebnisdatei ist gemeinsam (Spieler -> Item-ID -> DeltaDPS) und wird
    # ergaenzt, nicht ersetzt - ein Phase-5-Lauf laesst die P3-Werte also stehen.
    argv = list(sys.argv[1:])
    phase = 3
    if "--phase" in argv:
        i = argv.index("--phase")
        phase = int(argv[i + 1])
        del argv[i:i + 2]
    nur = {a.lower() for a in argv}
    hole_cli()

    itemsDatei = "items.json" if phase == 3 else f"items-p{phase}.json"
    print(f"Item-Pool: {itemsDatei}")
    spieler = lade(os.path.join(BASE, "daten", "players.json"))
    roster = lade(os.path.join(BASE, "roster.json"))
    items = lade(os.path.join(BASE, "daten", itemsDatei))
    cache = lade(os.path.join(BASE, "daten", "cache-tooltips.json"))
    specs = lade(os.path.join(SPEC_DIR, "specs.json"))
    setup = lade(os.path.join(SPEC_DIR, "raid-setup.json"))

    namen = {str(i["Id"]): i["Name"] for i in items if i.get("Id") and i.get("Name")}
    spec_von = {r["name"]: r["spec"] for r in roster}
    kandidaten = sorted({int(i["Id"]) for i in items if i.get("Slot") == "Trinket"})

    bindung = {}
    for tid in kandidaten:
        eintrag = cache.get(str(tid)) or {}
        bindung[tid] = klassenbindung(eintrag.get("tooltip", ""))

    print(f"{len(kandidaten)} Schmuckstuecke im Pool, "
          f"{sum(1 for v in bindung.values() if v)} davon klassengebunden\n")

    ergebnis, apls, unbekannt = {}, {}, set()
    for p in spieler:
        name = p["Name"]
        spec = spec_von.get(name)
        if (nur and name.lower() not in nur) or not spec:
            continue

        # Einzelne Spieler spielen eine andere Spec, als die Kette kennt (nur je eine HUNT
        # und WLCK). Die Ueberschreibung tauscht Talente und Rotation, sonst nichts.
        ueber = specs.get("_spielerUeberschreibungen", {}).get(name)
        if ueber:
            cfg = dict(specs[ueber["basis"]])
            cfg["talente"] = ueber["talente"]
            cfg["warnung"] = None                     # gerade behoben, nicht mehr warnen
            aplName = ueber["apl"]
            abweichung = "  [" + ueber["grund"] + "]"
        elif spec in specs:
            cfg = specs[spec]
            aplName = spec
            abweichung = "  [" + cfg["warnung"] + "]" if cfg.get("warnung") else ""
        else:
            continue

        if aplName not in apls:
            apldatei = os.path.join(SPEC_DIR, "apls", aplName + ".apl.json")
            if not os.path.exists(apldatei):
                print(f"!! {aplName}: keine APL-Datei - uebersprungen "
                      f"(ohne APL rechnet die Sim ohne Rotation)")
                apls[aplName] = None
            else:
                apls[aplName] = lade(apldatei)
        if apls[aplName] is None:
            continue

        tooltipklasse = KLASSE_ZU_TOOLTIP[cfg["klasse"]]
        slots = dict(p["Slots"])
        getragen = [int(slots.get("TRINKET_1", 0) or 0), int(slots.get("TRINKET_2", 0) or 0)]

        basis_anfrage = baue_anfrage(cfg, setup, apls[aplName], name)
        basis_anfrage["raid"]["parties"][0]["players"][0]["equipment"]["items"] = [
            {"id": int(slots.get(s, 0) or 0)} for s in SLOT_ORDER
        ]
        basis = sim(basis_anfrage)
        print(f"--- {name} ({spec})  Basis {basis:.1f} DPS{abweichung}")

        werte = {}
        for tid in kandidaten:
            gebunden = bindung[tid]
            if gebunden and tooltipklasse not in gebunden:
                continue                      # andere Klasse: wuerde die Sim zum Absturz bringen
            if tid in getragen:
                werte[str(tid)] = 0.0         # traegt er schon
                continue
            # ⚠️ Die WoWSims-Datenbank kennt nicht jeden Gegenstand aus dem Wowhead-Pool
            # (z.B. Battlemaster's Determination, 34578). Frueher riss so ein Fall den
            # KOMPLETTEN Lauf ab - 18 Spieler mal 35 Schmuckstuecke waren dann umsonst.
            # Jetzt wird der einzelne Gegenstand uebersprungen und am Ende gemeldet.
            beste = None
            try:
                for idx in (IDX_T1, IDX_T2):
                    a = copy.deepcopy(basis_anfrage)
                    a["raid"]["parties"][0]["players"][0]["equipment"]["items"][idx] = {"id": tid}
                    d = sim(a) - basis
                    beste = d if beste is None else max(beste, d)
            except RuntimeError as e:
                if "No item with id" in str(e):
                    unbekannt.add(tid)
                    continue
                raise
            werte[str(tid)] = round(beste, 1)

        for tid, d in sorted(werte.items(), key=lambda kv: -kv[1])[:4]:
            print(f"      {namen.get(tid, tid):<34} {d:+8.1f} DPS")
        ergebnis[name] = werte

    if unbekannt:
        print("")
        print(f"!! {len(unbekannt)} Gegenstaende kennt die WoWSims-Datenbank nicht - uebersprungen:")
        for t in sorted(unbekannt):
            print(f"     {t} {namen.get(str(t), '?')}")

    if not ergebnis:
        print("Keine Spieler simuliert - specs.json und spec-sims/apls/ pruefen.")
        return

    # Bestehende Werte ERGAENZEN, nicht ersetzen. Sonst wirft ein gefilterter Lauf
    # ("python 6-trinket-sim.py Kaosx") alle anderen Spieler aus der Datei.
    vorher = {}
    if os.path.exists(OUT):
        vorher = lade(OUT)
    vorher.update(ergebnis)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(vorher, f, indent=2, ensure_ascii=False)
    print(f"\ntrinket-werte.json: {len(ergebnis)} Spieler neu berechnet, "
          f"{len(vorher)} insgesamt in der Datei")


if __name__ == "__main__":
    main()
