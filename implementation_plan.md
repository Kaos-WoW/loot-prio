# Implementation Plan: WoWSims CLI Integration

Dieser Plan beschreibt die Integration der WoWSims-Kommandozeilen-Version (CLI) in die TBC-Lootprio-Pipeline. Dadurch werden die Stat-Gewichte (EPs) für jeden DPS-Spieler individuell basierend auf seinem aktuellen Armory-Gear simuliert, anstatt starre Presets zu nutzen.

## User Review Required

> [!NOTE]
> Die Simulatoren werden auf GitHub Actions ausgeführt. Um die 6-Stunden-Laufzeitbegrenzung zu schonen, simulieren wir Chars nur dann neu, wenn sich ihr Gear (in `players.json`) seit dem letzten Lauf verändert hat. Ein vollständiger Cache der berechneten Gewichte wird im Repository gepflegt.

## Proposed Changes

### [TBC-Lootprio]

#### [NEW] [wowsims-cli.ps1](file:///c:/Users/maxim/OneDrive/Documents/Skripte&Codes&Addons/TBC-Lootprio/wowsims-cli.ps1)
Ein neues Skript, das:
1. Die WoWSims CLI-Binaries bei Bedarf automatisch für das jeweilige Betriebssystem (Windows lokal, Linux auf GitHub Actions) herunterlädt.
2. Das Gear des Spielers aus `players.json` liest und in das WoWSims-JSON-Format übersetzt (Gems, Enchants, Standard-Buffs/Consumables).
3. Die Sim-CLI aufruft, um die Stat-Gewichte (EPs) durch temporäres Erhöhen einzelner Stats (z.B. +10 Spell Power, +10 Haste) zu berechnen.
4. Die Ergebnisse in `daten/sim-weights.json` speichert.

#### [MODIFY] [3-compute.ps1](file:///c:/Users/maxim/OneDrive/Documents/Skripte&Codes&Addons/TBC-Lootprio/3-compute.ps1)
Wir passen das Berechnungs-Skript so an, dass es:
1. Prüft, ob dynamische Gewichte in `daten/sim-weights.json` für den Spieler vorliegen.
2. Falls ja, diese individuellen Gewichte für die Upgrade-Berechnung nutzt.
3. Falls nein (oder für Heiler/Tanks), auf die bewährten statischen Presets zurückfällt.

#### [MODIFY] [.github/workflows/sync.yml](file:///c:/Users/maxim/OneDrive/Documents/Skripte&Codes&Addons/TBC-Lootprio/.github/workflows/sync.yml)
Der GitHub-Workflow wird um einen neuen Schritt erweitert:
1. Vor dem Berechnungs-Schritt wird `wowsims-cli.ps1` ausgeführt, um verändertes Gear neu zu simmen.
2. Die Datei `daten/sim-weights.json` wird in die Liste der zu committenden Dateien aufgenommen.

## Verification Plan

### Automated Tests
- Lokales Ausführen von `wowsims-cli.ps1` für einen Test-Spieler (z.B. Pflasterelfe) und Prüfung, ob `sim-weights.json` korrekt befüllt wird.
- Ausführen des gesamten Build-Ablaufs (`2-fetch-gear.ps1` -> `wowsims-cli.ps1` -> `3-compute.ps1`) und Verifikation der berechneten Upgrades.
