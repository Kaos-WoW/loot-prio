# AGENTS.md — Übergabe-Dokumentation für KI-Tools

Diese Datei richtet sich an KI-Coding-Tools, die an diesem Projekt arbeiten (aktuell: Claude Code und Gemini/Antigravity im Wechsel). Sie soll den schnellen Einstieg und die Einhaltung etablierter Regeln sichern.

## 1. Projektüberblick

**TBC-Lootprio** ist ein PowerShell-basiertes Tool für den Loot-Rat der Gilde **Resurrected** (WoW TBC Anniversary, Phase 3). Es berechnet den DPS-Zuwachs (ΔDPS) für jeden Raider basierend auf seinem live getragenen Gear (abgerufen aus der Classic-Armory API) im Vergleich zu Phase 3 Loot-Optionen.

### Tool-Kette (Reihenfolge)

1. `.\0-import-roster.ps1` -> Importiert Gilden-Kader aus Google Sheets -> `roster.json`
2. `.\1-fetch-items.ps1` -> Holt Item-Pool + Werte von Wowhead -> `daten/items.json`
3. `.\2-fetch-gear.ps1` -> Holt getragene Ausrüstung live & prüft Plausibilität (PvP-Schutz) -> `daten/players.json`
4. `.\3-compute.ps1` -> Berechnet Upgrades mit DPS-Stat-Gewichten (Prozentwert relativ zum getragenen Gear bei Tanks/Heilern) -> `daten/upgrades.json`
5. `.\4-bis-check.ps1` -> Prüft Ergebnisse gegen BiS-Listen -> `daten/bis-listen.json`
6. `.\5-build-payload.ps1` -> Baut die HTML-Ausgabeseite -> `ausgabe/loot-prio-p3.html`

Normaler Update-Durchlauf nach einem Raid (automatisiert über GitHub Actions):
```powershell
.\0-import-roster.ps1; .\2-fetch-gear.ps1; .\3-compute.ps1; .\5-build-payload.ps1
```

---

## 2. Bekannte Fallen & Konventionen

* **Prokks aus Tooltips abschneiden:** WoW-Tooltips formulieren Prokks wie Dauereffekte. Tooltips müssen vor der Wertelesung bei Schlüsselwörtern wie `Chance on hit`, `Use:`, `have a chance` abgeschnitten werden (nicht bei `Equip: Your`).
* **Sonderzeichen in PowerShell 5.1:** `.ps1`-Dateien werden standardmäßig als ANSI gelesen. Strings mit Umlauten oder Sonderzeichen (z. B. Raider-Namen wie „Järgerlie“) gehören ausschließlich in UTF-8-kodierte JSON-Dateien (z. B. `roster.json`).
* **Armory API & Umlaute:** Die classic-armory API benötigt UTF-8-Bytes, wirft aber bei `charset=utf-8` im Header einen HTTP 400 Fehler. Die Lösung ist in `2-fetch-gear.ps1` implementiert (ByteArrayContent mit rohem `application/json` Content-Type).
* **Stat-Gewichte (wowsims.com):** Verwende immer die absolute "DPS Weight" (Gewinn pro Statpunkt), niemals die relative "DPS EP", da letztere nicht klassenübergreifend vergleichbar ist.
* **Keine automatischen Git-Pushes:** Commits lokal erstellen, aber niemals automatisch pushen (`git push`), ohne die explizite Freigabe des Nutzers einzuholen.
* **Devastation & Waffen-Bug im Scraper:** Im Scraper `scrape_wowhead_final.py` wurde der Header-Filter korrigiert (nutzt nun exaktes HTML-Tag-Matching statt Substring-Filter `stat`), damit Wörter wie `devastation` nicht fälschlicherweise ausgefiltert werden. Zudem werden Ret-Paladin-Waffen standardmäßig auf den Slot `Two-Hand` gemappt.
* **Sichere Serverless Functions:** Der lila Blitz-Button auf der Webseite triggert den GitHub Actions Sync sicher über eine Netlify Serverless Function (`netlify/functions/trigger-sync.js`), um unbefugtes Auslesen des GitHub-Tokens zu verhindern.

---

## 3. Offene Punkte & TODOs

* **Knappheitsspalten:** Einpflege der Daten aus `quellen/p3-alternativen-*.md` in die Ausgabe (Alternativen im Slot, ab welchem Boss).
* **Phasenzuordnung Markenhändler:** Sobald Phase 3 live ist, die ilvl-141 Plattenteile beim Händler gegenprüfen (Wowhead-Phasen-Zuordnung ist teilweise fehlerhaft).
* **Buff-Annahmen stichprobenartig prüfen:** Die Sim-Voreinstellungen der Stat-Gewichte sind nicht spec-übergreifend auf identische Raid-Buffs verifiziert worden (siehe [p3-stat-gewichte-2026-07-27.md](file:///c:/Users/maxim/OneDrive/Documents/Skripte&Codes&Addons/TBC-Lootprio/quellen/p3-stat-gewichte-2026-07-27.md#L246-L252)).

---

## 4. Erledigte Meilensteine

* **[x] Roster-Import aus Google Sheets:** `0-import-roster.ps1` liest nun direkt die Übersicht aus dem öffentlichen Google-Sheet ein und übersetzt die deutschen Klassen/Spec-Bezeichnungen robust.
* **[x] Plausibilitäts-Checks (PvP-Schutz):** Generischer Check für alle Klassen in `2-fetch-gear.ps1` implementiert. Fällt der PvE-Wert der live angelegten Ausrüstung um mehr als 20 % im Vergleich zur DB, wird das Update verworfen.
* **[x] Korrekte Prozentberechnung für Heiler & Tanks:** Berechnung wurde in `3-compute.ps1` auf eine rein statbasierte Zuwachsrechnung im Vergleich zum Gesamtwert der getragenen PvE-Ausrüstung umgestellt (Zahlenbereich nun realistisch bei +0.5% bis +4.5%).
* **[x] Web-Interface Trigger-Button:** Admin-Update-Button auf der Webseite via Netlify Serverless Function & GitHub API Dispatch realisiert.
