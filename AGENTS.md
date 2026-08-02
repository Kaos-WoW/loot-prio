# AGENTS.md — Übergabe-Dokumentation für KI-Tools

Diese Datei richtet sich an KI-Coding-Tools, die an diesem Projekt arbeiten (aktuell: Claude Code und
Gemini/Antigravity im Wechsel). Sie soll den schnellen Einstieg und die Einhaltung etablierter Regeln
sichern. **Bei jeder inhaltlichen Änderung mitpflegen**, sonst laufen diese Datei und README.md wieder
auseinander — genau das ist zuletzt passiert.

## 1. Projektüberblick

**TBC-Lootprio** ist ein PowerShell-basiertes Tool für den Loot-Rat der Gilde **Resurrected** (WoW TBC
Anniversary, Phase 3). Es berechnet für DPS den absoluten DPS-Zuwachs (ΔDPS), für Tank/Heiler den
prozentualen Zuwachs — jeweils gegenüber dem live über die Classic-Armory-API abgerufenen, tatsächlich
getragenen Gear.

### Tool-Kette (Reihenfolge)

0. `.\0-import-roster.ps1` → Kader aus dem öffentlichen Google Sheet → `roster.json`
1. `.\1-fetch-items.ps1` → Item-Pool + Werte von Wowhead → `daten/items.json`
2. `.\2-fetch-gear.ps1` → getragene Ausrüstung live, Plausibilitäts-/PvP-Check → `daten/players.json`
3. `.\wowsims-cli.ps1` → dynamische WoWSims-Simulation (aktuell nur Kaosx) → `daten/sim-weights.json`
4. `.\3-compute.ps1` → Upgrades berechnen (nutzt `sim-weights.json` wo vorhanden, sonst statische
   Presets) → `daten/upgrades.json`, `daten/payload.json`
5. `.\4-bis-check.ps1` → DPS-Empfehlungen gegen BiS-Listen prüfen → `daten/bis-listen.json`
6. `.\5-build-payload.ps1` → HTML-Ausgabeseite bauen → `ausgabe/loot-prio-p3.html`, `index.html`

**Schritt 3 (`wowsims-cli.ps1`) ist Teil der Kette, seit die WoWSims-CLI integriert wurde — nicht mehr
weglassen.** Er lädt bei Bedarf `bin/wowsimcli-windows.exe` herunter (Quelle:
`github.com/wowsims/tbc-new/releases/latest`), baut aus `players.json` eine RaidSimRequest und schreibt
die simulierten Gewichte weg. Läuft nur für Spieler mit hinterlegtem APL-Mapping — aktuell ausschließlich
Kaosx (Vergeltungs-Paladin); alle anderen fallen weiterhin auf die statischen Presets in `3-compute.ps1`
zurück.

Realer Ablauf laut `.github/workflows/sync.yml` (automatisiert, täglich 03:00 UTC):
```powershell
.\0-import-roster.ps1
.\2-fetch-gear.ps1
# Guard: bricht ab, wenn daten/players.json < 5 Einträge hat (verhindert Publish bei kaputtem Abruf)
.\wowsims-cli.ps1
.\3-compute.ps1
.\4-bis-check.ps1
.\5-build-payload.ps1
# git add roster.json daten/players.json daten/cache-tooltips.json daten/payload.json
#         index.html ausgabe/loot-prio-p3.html temp.csv daten/bis-listen.json daten/sim-weights.json
# git commit + push, wenn sich etwas geändert hat
```

---

## 2. Bekannte Fallen & Konventionen

* **Prokks aus Tooltips abschneiden:** WoW-Tooltips formulieren Prokks wie Dauereffekte. Tooltips
  müssen vor der Wertelesung bei Schlüsselwörtern wie `Chance on hit`, `Use:`, `have a chance`
  abgeschnitten werden (nicht bei `Equip: Your`, sonst gehen echte Dauereffekte wie „ignore 335 armor“
  verloren).
* **Sonderzeichen in PowerShell 5.1:** `.ps1`-Dateien werden standardmäßig als ANSI gelesen. Strings mit
  Umlauten oder Sonderzeichen (z. B. Raider-Namen wie „Järgerlie“) gehören ausschließlich in
  UTF-8-kodierte JSON-Dateien (z. B. `roster.json`).
* **Armory API & Umlaute:** Die classic-armory-API benötigt UTF-8-Bytes, wirft aber bei `charset=utf-8`
  im Content-Type-Header einen HTTP 400. Lösung in `2-fetch-gear.ps1`: `ByteArrayContent` mit rohem,
  manuell gesetztem `application/json`-Header statt `Invoke-RestMethod` mit String-Body.
* **Armory-Slot-Bug:** Die API von classic-armory.org liefert bei TBC Anniversary die Items manchmal in
  willkürlichen Slots zurück. `2-fetch-gear.ps1` ignoriert die API-Slotangabe und sortiert Items anhand
  des echten Typs aus dem Wowhead-Tooltip ein.
* **Stat-Gewichte (wowsims.com):** Immer die absolute „DPS Weight“ (Gewinn pro Statpunkt) verwenden,
  niemals die relative „DPS EP“ — letztere ist nicht klassenübergreifend vergleichbar.
* **Cap-Stat-Abwärtsspirale (De-gearing):** Wird ein Spieler am Hit- oder Expertise-Cap simuliert bzw.
  mit einem statischen Preset am Cap bewertet, fällt das Gewicht für diesen Stat fast auf 0 — die Formel
  will dann faelschlich Cap-Gear ablegen. Lösung: Gewichte für `Treffer`, `Waffk` und `ZTreffer` dürfen
  in `Value-Item` (`3-compute.ps1`) nie unter ihr statisches „Below-Cap“-Gewicht fallen (z. B. RET
  Treffer = 1.20, Waffk = 1.69 statt 0).
* **Waffentempo-Normierung:** Da in TBC fast alle physischen Spezialangriffe (Mortal Strike, Stormstrike, Sinister Strike) normiert sind, wird die Waffentempo-Normierung in `Value-Item` (`3-compute.ps1`) nur für **RET-Paladine** (wegen Crusader Strike / Seal of Blood) angewendet, und zwar **linear** (`speed / normSpeed`) statt quadratisch, um eine krasse Überbewertung langsamer Waffen (wie *Torch of the Damned* vs. *Cataclysm's Edge* bei Arms) zu verhindern.
* **Bereits ausgerüstete Items (alreadyEquipped):** Damit Spieler, die ein Item bereits tragen, das in ihrer BiS-Liste steht, auf der Seite als „Bereits ausgerüstet“ gelistet werden, trackt `3-compute.ps1` die getragenen Item-IDs in `$wornIds` (der alte Check lief fälschlich gegen die stats-Hashtable) und schreibt diese Zeilen mit `Delta = 0.0` in `upgrades.json` (sowohl für DPS- als auch für Tank/Heilspezialisierungen).
* **Plausibilitäts-Check (Hashtables):** Die Funktion `Get-GearScore` in `2-fetch-gear.ps1` prüft live abgerufene Ausrüstung (die als `Hashtables` vorliegt) sowie gespeicherte Ausrüstung aus `players.json` (die als `PSCustomObjects` geladen wird). Sie iteriert universell über die Keys, um Rechenfehler (die den PvP/Offspec-Schutz durch 0-Wertungen umgehen würden) zu verhindern.
* **Legacy-BiS- und T6-Ergänzungen:** Wichtige Phase 1/2 Raid-Items, die in Phase 3 absolute BiS-Items bleiben (wie *Belt of One-Hundred Deaths* von Lady Vashj oder *Dragonspine Trophy* von Gruul), sowie alle spezialisierungsspezifischen T6-Sets sind in `1-fetch-items.ps1` hinterlegt, damit das Modell für diese Gegenstände Upgrades berechnet.
* **Fähigkeitsnamen nicht selbst übersetzen:** In `tier-boni.json` stehen sie bewusst englisch wie in
  der Quelle (*Arcane Blast* ≠ „Arkane Explosion“, das ist Arkanschlag; *Mutilate* ≠ „Blutsturz“, das
  ist Verstümmeln).
* **Schilde ≠ Schildhand-Item:** Tooltip nennt bei Schilden „Off Hand“ als Slot — ohne Prüfung der
  Rüstungsart (`Shield`) bekommen Caster Schilde vorgeschlagen.
* **Devastation-Bug im Scraper:** In `daten/scrape_wowhead_final.py` filterte ein Substring-Filter
  (`stat`) fälschlich Wörter wie „devastation“ heraus — jetzt exaktes HTML-Tag-Matching. Ret-Paladin-
  Waffen werden dort standardmäßig auf den Slot `Two-Hand` gemappt.
* **CORS-Proxy im Client:** GitHub Pages liefert nur statische Dateien ohne eigenen Proxy. Der
  clientseitige Live-Sync im Browser läuft deshalb über `corsproxy.io` zur Classic-Armory-API.
* **Trigger-Button (Supabase Edge Function):** Der lila Blitz-Knopf auf der Seite ruft
  `supabase/functions/trigger-sync` auf. Die Function prüft die Admin-Authentifizierung und stößt über
  ein im Supabase Vault hinterlegtes `GITHUB_TOKEN` den GitHub-Actions-Workflow an — das Token verlässt
  nie den Client. **Netlify wurde dafür vollständig abgelöst**, die zugehörigen Dateien
  (`netlify.toml`, `netlify/functions/trigger-sync.js`) sind entfernt.
* **Multi-Select-Spieler-Filter:** Auswahl über ein Dropdown mit Suchfeld und
  Mehrfachauswahl-Checkboxes für direkte Vergleiche (2–4 Spieler) im Loot-Rat.
* **Seitensprung bei Dynamic Heights:** Schrumpft die Tabelle durch Filter, erzwingt der Browser sonst
  einen Scroll-Sprung. Fix: `#main-tablewrap` hat eine Mindesthöhe von `65vh`.
* **Dropdown-Einklappen (`.hidden`):** `.ms-dropdown` nutzt `display: flex`, das HTML-Attribut `hidden`
  wird durch CSS-Spezifität überschrieben. Steuerung deshalb über `.classList.toggle('hidden')`, CSS
  definiert `.ms-dropdown.hidden { display: none !important; }`.

---

## 3. Offene Punkte & TODOs

* **Knappheitsspalten:** Einpflege der Daten aus `quellen/p3-alternativen-*.md` in die Ausgabe
  (Alternativen im Slot, ab welchem Boss).
* **Phasenzuordnung Markenhändler:** Sobald Phase 3 live ist, die ilvl-141-Plattenteile beim Händler
  gegenprüfen (Wowhead-Phasen-Zuordnung ist teilweise fehlerhaft).
* **Buff-Annahmen stichprobenartig prüfen:** Die statischen Preset-Gewichte sind nicht spec-übergreifend
  auf identische Raid-Buffs verifiziert (siehe
  [p3-stat-gewichte-2026-07-27.md](quellen/p3-stat-gewichte-2026-07-27.md)).
* **WoWSims-CLI-Integration auf weitere Spieler ausweiten:** Aktuell nur Kaosx individuell simuliert,
  alle anderen laufen auf statischen Presets.
* **Kein automatisierter Regressionstest für Tank/Heiler**, analog zu `4-bis-check.ps1` für DPS.
* **Aufräumen:** `raw.html`, `temp.csv` und die Python-Hilfsskripte in `daten/` (`scrape_*.py`,
  `debug_*.py`, `diag_*.py`, `inspect_*.py`, `search_wowhead.py`, `test_fetch.py`) sind
  Arbeitsartefakte einzelner Sitzungen, kein Teil der regulären Kette, aber weiterhin mitversioniert.
  Kein `.gitignore` vorhanden.
* **`bin/`-Inhalte wachsen mit jedem Lauf:** `sim_input.json`/`sim_output.json` werden bei jeder
  Simulation überschrieben und mitcommittet; `template.json` ist aktuell eine leere Datei (0 Byte) —
  prüfen, ob sie noch gebraucht wird.

---

## 4. Erledigte Meilensteine

* **[x] Roster-Import aus Google Sheets:** `0-import-roster.ps1` liest die Übersicht aus dem
  öffentlichen Google-Sheet und übersetzt deutsche Klassen-/Spec-Bezeichnungen robust.
* **[x] Plausibilitäts-Checks (PvP-Schutz):** Genereller Check in `2-fetch-gear.ps1`. Fällt der
  PvE-Wert der live angelegten Ausrüstung um mehr als 20 % gegenüber dem letzten Stand, wird das Update
  verworfen und der alte Stand behalten.
* **[x] Korrekte Prozentberechnung für Heiler & Tanks:** Statbasierte Zuwachsrechnung gegenüber dem
  Gesamtwert der getragenen PvE-Ausrüstung in `3-compute.ps1` (realistischer Bereich +0,5 % bis +4,5 %).
* **[x] Web-Interface Trigger-Button:** Admin-Update-Button triggert per Supabase Edge Function den
  GitHub-Workflow vollautomatisch und sicher im Hintergrund (Netlify-Vorgängerlösung entfernt).
* **[x] „Heiß umkämpfter Loot“:** Dynamische Übersichtstabelle oberhalb der Haupttabelle zeigt die
  begehrtesten Items (sortiert nach BiS-Kandidaten & Upgrades gesamt) mit den interessierten Spielern.
  Tier-6-Tokens sind ausgeschlossen, Schmuckstücke als (BiS)/(Bedarf) integriert.
* **[x] WoWSims-CLI-Integration & dynamische Simulation:** Vollautomatische Simulation für Kaosx zur
  Ermittlung individueller Stat-Gewichte, inklusive automatischem CLI-Download und
  Workflow-Integration.
* **[x] Globale Waffentempo- & Cap-Stat-Sicherungen:** Mechanisch korrekte Bewertung von
  Zweihandwaffen und Schutz der Cap-Gegenstände vor fälschlichem Ablegen (De-gearing).
* **[x] Interaktiver Multi-Select-Spieler-Filter:** Gleichzeitige Auswahl mehrerer Raider inklusive
  Suchfeld, ohne Scroll-Sprung beim Filtern.
* **[x] Aufräumen Tabellendesign:** Grüne Verlaufsbalken hinter den Prozentwerten entfernt.
