"""
Schritt 7: Stat-Gewichte fuer ALLE DPS-Spieler simulieren.

Loest wowsims-cli.ps1 ab, das nur Kaosx konnte und dessen Aufbau drei stille Fehler enthielt
(Talente im falschen Feld, nicht existierendes armor-Feld, zu kleine Messprobe - siehe AGENTS.md).
Dieses Skript nutzt dieselbe Konfiguration wie 6-trinket-sim.py: spec-sims/specs.json,
spec-sims/apls/ und den gemeinsamen Raid-Aufbau aus spec-sims/raid-setup.json.

Verfahren: Basis-Sim, dann je Stat eine Sim mit +PROBE Punkten. Gewicht = DPS-Differenz / PROBE.

  PROBE ist bewusst 100 und nicht 30. Tempo wirkt in TBC ueber Schwellenwerte; bei 30 Punkten
  kam fuer Kaosx -1,4 DPS heraus (Gewicht auf 0 geklemmt, "wertlos"), bei 100 Punkten +47,6 DPS.
  Lineare Stats aendern sich durch die groessere Probe nicht.

Waffenkoeffizienten (MH/OH/RANGED) lassen sich nicht als Stat messen - Waffenschaden ist kein
Eintrag im bonusStats-Array. Sie werden deshalb aus dem gemessenen AP-Gewicht hochgerechnet, im
selben Verhaeltnis, das das statische Preset in 3-compute.ps1 vorgibt. Damit bleibt die Struktur
der Spec erhalten, aber alles liegt auf der simulierten Skala.

Aufruf:
    python 7-stat-gewichte.py            # alle Spieler mit Spec-Konfiguration
    python 7-stat-gewichte.py Kaosx      # nur bestimmte (ergaenzt die Datei)
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
OUT = os.path.join(BASE, "daten", "sim-weights.json")

ITERATIONS = 10000
PROBE = 100.0

SLOT_ORDER = ["HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST",
              "LEGS", "FEET", "FINGER_1", "FINGER_2", "TRINKET_1", "TRINKET_2",
              "MAIN_HAND", "OFF_HAND", "RANGED"]

# Stat-Indizes aus proto/common.proto, enum Stat. NICHT raten - die Reihenfolge ist
# nicht intuitiv (z.B. ist 31 die Ruestung, nicht 2).
STAT_INDEX = {
    "Str": 0, "Agi": 1, "Int": 3, "SP": 5, "Spi": 16,
    "ZTreffer": 12, "ZKrit": 13, "ZTempo": 14,
    "AP": 17, "Treffer": 20, "Krit": 21, "Tempo": 22,
    "ArP": 23, "Waffk": 24, "mp5": 35,
}
# Was fuer welches Profil ueberhaupt sinnvoll messbar ist. Weniger Stats = kuerzere Laufzeit.
STATS_PROFIL = {
    "physisch": ["Str", "Agi", "AP", "Treffer", "Krit", "Tempo", "ArP", "Waffk", "Int", "SP",
                 "ZTreffer", "ZKrit"],
    "zauberer": ["Int", "SP", "Spi", "ZTreffer", "ZKrit", "ZTempo", "mp5"],
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


def lies_presets():
    """Statische Preset-Gewichte aus 3-compute.ps1 lesen.

    Nur fuer die Waffenkoeffizienten gebraucht. Bewusst geparst statt in specs.json
    dupliziert - eine zweite Kopie wuerde unbemerkt auseinanderlaufen. Schlaegt das
    Parsen fehl, faellt es lautstark auf, statt still falsche Werte zu liefern.
    """
    text = open(os.path.join(BASE, "3-compute.ps1"), encoding="utf-8", errors="replace").read()
    presets = {}
    for m in re.finditer(r"NewSpec\s+'(\w+)'.*?@\{([^}]*)\}", text):
        key, block = m.group(1), m.group(2)
        werte = {}
        for paar in block.split(";"):
            if "=" in paar:
                k, v = paar.split("=", 1)
                try:
                    werte[k.strip()] = float(v.strip())
                except ValueError:
                    pass
        if werte:
            presets[key] = werte
    if not presets:
        raise RuntimeError("Keine Preset-Gewichte in 3-compute.ps1 gefunden - Format geaendert?")
    return presets


def sim(anfrage):
    fi = os.path.join(tempfile.gettempdir(), "sw_in.json")
    fo = os.path.join(tempfile.gettempdir(), "sw_out.json")
    if os.path.exists(fo):
        os.remove(fo)
    with open(fi, "w", encoding="utf-8") as f:
        json.dump(anfrage, f)
    r = subprocess.run([EXE, "sim", "--infile", fi, "--outfile", fo],
                       capture_output=True, text=True)
    if not os.path.exists(fo):
        raise RuntimeError("Sim ohne Ergebnis: " + (r.stdout + r.stderr)[-300:])
    erg = json.load(open(fo, encoding="utf-8"))
    if erg.get("error"):
        raise RuntimeError(erg["error"].get("message", "Sim-Fehler").split("\n")[0])
    return erg["raidMetrics"]["dps"]["avg"]


def baue(cfg, setup, apl, name, slots, bonus):
    profil = setup["profile"][cfg["profil"]]
    return {
        "simOptions": {"iterations": ITERATIONS, "randomSeed": 101},
        "raid": {
            "parties": [{"players": [{
                "name": name, "race": cfg["rasse"], "class": cfg["klasse"],
                # Gehoert an den Spieler, NICHT in den Spec-Block (sonst still ignoriert).
                "talentsString": cfg["talente"],
                cfg["specKey"]: {"options": {"classOptions": {}}},
                "equipment": {"items": [{"id": int(slots.get(s, 0) or 0)} for s in SLOT_ORDER]},
                "consumables": profil["consumables"], "buffs": profil["buffs"],
                "bonusStats": {"stats": bonus},
                "rotation": apl,
            }], "buffs": setup["partyBuffs"]}],
            "buffs": setup["raidBuffs"], "debuffs": setup["debuffs"],
        },
        "encounter": setup["encounter"],
    }


def main():
    nur = {a.lower() for a in sys.argv[1:]}
    hole_cli()
    spieler = lade(os.path.join(BASE, "daten", "players.json"))
    roster = lade(os.path.join(BASE, "roster.json"))
    specs = lade(os.path.join(SPEC_DIR, "specs.json"))
    setup = lade(os.path.join(SPEC_DIR, "raid-setup.json"))
    presets = lies_presets()
    spec_von = {r["name"]: r["spec"] for r in roster}

    ergebnis, apls = {}, {}
    for p in spieler:
        name = p["Name"]
        spec = spec_von.get(name)
        if (nur and name.lower() not in nur) or not spec:
            continue

        ueber = specs.get("_spielerUeberschreibungen", {}).get(name)
        if ueber:
            cfg = dict(specs[ueber["basis"]]); cfg["talente"] = ueber["talente"]
            aplName, notiz = ueber["apl"], "  [" + ueber["grund"] + "]"
        elif spec in specs:
            cfg, aplName, notiz = specs[spec], spec, ""
        else:
            continue

        if aplName not in apls:
            datei = os.path.join(SPEC_DIR, "apls", aplName + ".apl.json")
            apls[aplName] = lade(datei) if os.path.exists(datei) else None
        if apls[aplName] is None:
            print(f"!! {aplName}: keine APL - uebersprungen (ohne APL rechnet die Sim ohne Rotation)")
            continue

        slots = dict(p["Slots"])
        null = [0] * 46
        basis = sim(baue(cfg, setup, apls[aplName], name, slots, null))
        print(f"--- {name} ({spec})  Basis {basis:.1f} DPS{notiz}")

        gewichte = {}
        for stat in STATS_PROFIL[cfg["profil"]]:
            b = list(null); b[STAT_INDEX[stat]] = PROBE
            g = (sim(baue(cfg, setup, apls[aplName], name, slots, b)) - basis) / PROBE
            if g < 0:
                # Negativ heisst praktisch immer: am Cap (Treffer/Waffenkunde) oder in einem
                # Schwellen-Totbereich. Klemmen, aber nicht stumm - genau das hat den
                # Tempo-Fehler lange verdeckt. In Value-Item faengt der Cap-Schutz die Folgen ab.
                print(f"      ! {stat}: {g:+.3f} negativ, auf 0 geklemmt (Cap oder Schwelle?)")
                g = 0.0
            gewichte[stat] = round(g, 3)

        # Waffenkoeffizienten aus dem AP-Gewicht hochrechnen, im Verhaeltnis des Presets.
        pre = presets.get(spec, {})
        if gewichte.get("AP", 0) > 0 and pre.get("AP"):
            for waffe in ("MH", "OH", "RANGED"):
                if pre.get(waffe):
                    gewichte[waffe] = round(gewichte["AP"] * (pre[waffe] / pre["AP"]), 3)

        top = sorted(((k, v) for k, v in gewichte.items() if v > 0), key=lambda kv: -kv[1])[:5]
        print("      " + ", ".join(f"{k} {v}" for k, v in top))
        ergebnis[name] = gewichte

    if not ergebnis:
        print("Keine Spieler simuliert.")
        return

    vorher = lade(OUT) if os.path.exists(OUT) else {}
    vorher.update(ergebnis)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(vorher, f, indent=2, ensure_ascii=False)
    print(f"\nsim-weights.json: {len(ergebnis)} Spieler neu berechnet, {len(vorher)} insgesamt")


if __name__ == "__main__":
    main()
