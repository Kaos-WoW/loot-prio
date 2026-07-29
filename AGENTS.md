# AGENTS.md — Übergabe-Dokumentation für KI-Tools

Diese Datei richtet sich an KI-Coding-Tools, die an diesem Projekt arbeiten (aktuell: Claude Code und Gemini/Antigravity im Wechsel). Sie soll den schnellen Einstieg und die Einhaltung etablierter Regeln sichern.

## 1. Projektüberblick

**TBC-Lootprio** ist ein PowerShell-basiertes Tool für den Loot-Rat der Gilde **Resurrected** (WoW TBC Anniversary, Phase 3). Es berechnet den DPS-Zuwachs (ΔDPS) für jeden Raider basierend auf seinem live getragenen Gear (abgerufen aus der Classic-Armory API) im Vergleich zu Phase 3 Loot-Optionen.

### Tool-Kette (Reihenfolge)

1. `.\1-fetch-items.ps1` -> Holt Item-Pool + Werte von Wowhead -> `daten/items.json`
2. `.\2-fetch-gear.ps1` -> Holt getragene Ausrüstung -> `daten/players.json`
3. `.\3-compute.ps1` -> Berechnet Upgrades mit DPS-Stat-Gewichten -> `daten/upgrades.json`
4. `.\4-bis-check.ps1` -> Prüft Ergebnisse gegen BiS-Listen -> `daten/bis-listen.json`
5. `.\5-build-payload.ps1` -> Baut die HTML-Ausgabeseite -> `ausgabe/loot-prio-p3.html`

Normaler Update-Durchlauf nach einem Raid:
```powershell
.\2-fetch-gear.ps1; .\3-compute.ps1; .\5-build-payload.ps1
```

---

## 2. Bekannte Fallen & Konventionen

* **Prokks aus Tooltips abschneiden:** WoW-Tooltips formulieren Prokks wie Dauereffekte. Tooltips müssen vor der Wertelesung bei Schlüsselwörtern wie `Chance on hit`, `Use:`, `have a chance` abgeschnitten werden (nicht bei `Equip: Your`).
* **Sonderzeichen in PowerShell 5.1:** `.ps1`-Dateien werden standardmäßig als ANSI gelesen. Strings mit Umlauten oder Sonderzeichen (z. B. Raider-Namen wie „Järgerlie“) gehören ausschließlich in UTF-8-kodierte JSON-Dateien (z. B. `roster.json`).
* **Armory API & Umlaute:** Die classic-armory API benötigt UTF-8-Bytes, wirft aber bei `charset=utf-8` im Header einen HTTP 400 Fehler. Die Lösung ist in `2-fetch-gear.ps1` implementiert (ByteArrayContent mit rohem `application/json` Content-Type).
* **Stat-Gewichte (wowsims.com):** Verwende immer die absolute "DPS Weight" (Gewinn pro Statpunkt), niemals die relative "DPS EP", da letztere nicht klassenübergreifend vergleichbar ist.
* **Keine automatischen Git-Pushes:** Commits lokal erstellen, aber niemals automatisch pushen (`git push`), ohne die explizite Freigabe des Nutzers einzuholen.

---

## 3. Offene Punkte & TODOs

* **Knappheitsspalten:** Einpflege der Daten aus `quellen/p3-alternativen-*.md` in die Ausgabe (Alternativen im Slot, ab welchem Boss).
* **Phasenzuordnung Markenhändler:** Sobald Phase 3 live ist, die ilvl-141 Plattenteile beim Händler gegenprüfen (Wowhead-Phasen-Zuordnung ist teilweise fehlerhaft).
* **Buff-Annahmen stichprobenartig prüfen:** Die Sim-Voreinstellungen der Stat-Gewichte sind nicht spec-übergreifend auf identische Raid-Buffs verifiziert worden (siehe [p3-stat-gewichte-2026-07-27.md](file:///c:/Users/maxim/OneDrive/Documents/Skripte&Codes&Addons/TBC-Lootprio/quellen/p3-stat-gewichte-2026-07-27.md#L246-L252)).
* **Basis-DPS:** Für die Prozentanzeige fehlt noch jeweils ein Simulate-Klick pro Spec (bisher nur für Krieger erfasst).
