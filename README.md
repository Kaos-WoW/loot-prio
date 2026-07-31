# TBC Loot-Prioritäten — Phase 3 (Mount Hyjal & Black Temple)

Werkzeug für den Loot-Rat der Gilde **Resurrected** auf **Thunderstrike EU** (WoW TBC Anniversary,
Serverstand Patch 2.5.6). Rechnet für jedes Phase-3-Item und jeden Raider aus, wie viel Zuwachs es ihm
**gegenüber seiner tatsächlich getragenen Ausrüstung** bringt, und veröffentlicht daraus eine
sortier- und filterbare HTML-Seite.

**Deckt inzwischen alle drei Rollen ab** (11 DPS-Specs, 2 Tanks, 4 Heiler) und bietet ein interaktives Web-Interface.
Neben einem vollautomatisierten nächtlichen GitHub Actions-Lauf besitzt die Seite nun einen **Multi-Select-Spieler-Filter** (zum schnellen Vergleich von 2-4 Raidern bei der Vergabe) und ein bereinigtes Tabellendesign. Die Veröffentlichung erfolgt automatisch via GitHub Pages.

Repo: `github.com/Kaos-WoW/loot-prio` · Ausgabe: `ausgabe/loot-prio-p3.html` bzw. `index.html`
(identischer Inhalt, `index.html` ist die von GitHub Pages ausgelieferte Fassung im Repo-Wurzelverzeichnis).

---

## Für Menschen, die nur die Seite lesen wollen

Nichts zu tun. Die Seite aktualisiert sich nachts automatisch (siehe „Automatisierung“ unten) und zeigt
den Stand nach dem letzten Raid. Ein lila Blitz-Knopf auf der Seite startet das Update vollautomatisch im Hintergrund,
indem er eine Supabase Edge Function aufruft, die den GitHub Actions-Workflow triggert.

## Für alle, die am Code weiterarbeiten

**Diese README ist die Übersicht für Menschen.** Die dichte, agentenorientierte Fassung mit jedem
Stolperstein und dem genauen Konventionenkatalog steht in **[`AGENTS.md`](AGENTS.md)** — die Datei ist
für den nächsten KI-Agenten geschrieben (aktuell wechseln sich Claude Code und Gemini/Antigravity ab)
und sollte bei jeder inhaltlichen Änderung mitgepflegt werden, damit beide Dateien nicht auseinanderlaufen.

### Schnellstart (lokal)

Alle Skripte sind PowerShell 5.1 und finden ihre Daten über `$PSScriptRoot` — der Ordner darf verschoben
werden.

```powershell
.\0-import-roster.ps1   # Kader aus dem Google Sheet          -> roster.json
.\1-fetch-items.ps1     # Item-Pool + Werte von Wowhead        -> daten/items.json
.\2-fetch-gear.ps1      # getragene Ausrüstung, live + Plausibilitätscheck -> daten/players.json
.\3-compute.ps1         # die eigentliche Rechnung             -> daten/upgrades.json
.\4-bis-check.ps1       # Gegenprobe der DPS-Empfehlungen      -> daten/bis-listen.json
.\5-build-payload.ps1   # Seite bauen                          -> ausgabe/loot-prio-p3.html
```

**Normaler Durchlauf nach einem Raid** (das macht die Automatisierung nachts von selbst):

```powershell
.\0-import-roster.ps1; .\2-fetch-gear.ps1; .\3-compute.ps1; .\4-bis-check.ps1; .\5-build-payload.ps1
```

`2-fetch-gear.ps1` meldet jeden Slotwechsel seit dem letzten Abruf und verwirft verdächtige Stände
(siehe Plausibilitätscheck unten). Alle Skripte nutzen `daten/cache-tooltips.json`, Wiederholungsläufe
sind daher schnell.

Die Kernkette (Schritte 1–5) braucht **kein Python und kein Node**. Im Ordner `daten/` liegen zusätzlich
ein paar Python-Hilfsskripte (`scrape_*.py`, `debug_*.py`) — das sind **einmalige Werkzeuge**, mit denen
einzelne BiS-Listen von Wowhead nachgepflegt wurden (u. a. um Cloudflare zu umgehen), kein Teil der
regulären Kette. Für den normalen Betrieb kann man sie ignorieren.

---

## Automatisierung

**GitHub Actions** (`.github/workflows/sync.yml`) läuft täglich um 03:00 UTC und lässt sich zusätzlich
manuell über das GitHub-Interface oder über den lila Blitz-Knopf (triggert eine sichere Supabase Edge Function `trigger-sync` per API) auslösen.

Der Workflow importiert das Roster, holt das Gear, rechnet neu und **committet und pusht das Ergebnis
automatisch** (`roster.json`, `daten/players.json`, `daten/cache-tooltips.json`, `index.html`,
`ausgabe/loot-prio-p3.html`, `daten/bis-listen.json`, `temp.csv`). Das ist ein bewusst eingerichteter,
system-eigener Push und keine Ausnahme von der Regel, dass ein Assistent nicht ungefragt pusht — die
Automatisierung wurde als solche eingerichtet und genehmigt.

**GitHub Pages** hostet die Seite direkt aus dem Hauptverzeichnis (`index.html`) des `main`-Branches.
Clientseitige Abfragen der WoW-Armory greifen über den Proxy `corsproxy.io` auf die API von `classic-armory.org` zu, um CORS-Beschränkungen im Browser zu umgehen.

---

## Roster — jetzt aus Google Sheets, nicht mehr von Hand

`0-import-roster.ps1` liest den Kader aus einem öffentlichen Google Sheet (Tabellenblatt „Übersicht“)
und schreibt `roster.json` **komplett neu**. Wer Spieler oder Specs ändern will, trägt das im Sheet ein,
nicht mehr in der Datei — ein manueller Edit an `roster.json` wird beim nächsten Lauf überschrieben.

Die deutschen Klassen-/Spec-Bezeichnungen aus dem Sheet werden robust auf interne Spec-Keys gemappt
(Teilstring-Erkennung, z. B. „Furor“ → `FURY`, „Schutz“ → `PROT_PALA`, „Wiederherstellung“ →
`RESTO_SHAM`/`RESTO_DRUID`). Das Google Sheet muss auf „Jeder mit dem Link kann lesen“ freigegeben sein,
sonst schlägt der CSV-Export fehl.

---

## Rollen und Bewertungsmethodik

| Rolle | Specs | Bewertung |
|---|---|---|
| **DPS** | Furor/Waffen-Krieger, Vergeltung, Verstärkung, Kampf-Schurke, Jäger, Hexer, Magier, Schattenpriester, Elementar, Gleichgewicht | absoluter DPS-Zuwachs (`ΔDPS`), direkt zwischen Specs vergleichbar |
| **Tank** | Schutz-Paladin, Feral-Tank | prozentualer Zuwachs relativ zum Gesamtwert der aktuell getragenen Ausrüstung |
| **Heiler** | Wiederherstellung-Druide/Schamane, Heilig-Paladin, Heilig-Priester | prozentualer Zuwachs relativ zum Gesamtwert der aktuell getragenen Ausrüstung |

Für Tank und Heiler wird **zusätzlich gegen die jeweilige BiS-Liste gegatet**: ein Item taucht für diese
Rollen nur auf, wenn es in der hinterlegten Phase-3-BiS-Liste der Spec steht. Das verhindert, dass ein
rein statistisches Modell (das Blockwert, Abhärtung oder Heilungsmenge nicht simuliert) Tanks und Heilern
unsinnige Empfehlungen gibt.

**BiS-Priorisierung (alle Rollen):** Items, die für eine Spec Best-in-Slot sind, werden vor bloßen
Upgrades einsortiert und als Exklusivitäts-Badge ausgewiesen — „★ BiS für 1 Spieler“ bzw. „für 2 Spieler“
markiert die knappsten, eindeutigsten Vergabeentscheidungen. Ist ein Item BiS für eine andere Spec, aber
nicht für die anfragende, wird die Zeile als „Gesperrt“ markiert statt als Upgrade angeboten.

---

## Neuer Schutzmechanismus: Plausibilitätscheck beim Gear-Abruf

`2-fetch-gear.ps1` vergleicht bei jedem Abruf den neuen PvE-Statwert der Ausrüstung mit dem zuletzt
gespeicherten. **Fällt der Wert um mehr als 20 %**, wird der neue Stand verworfen und der alte behalten
— typischerweise, weil der Spieler gerade in Arena-/BG-Ausrüstung oder einem Nebenspec ausgeloggt war.
Das Skript gibt in diesem Fall eine Warnung mit altem und neuem Wert aus. Das löst das Problem, das
früher Valiror und Pflasterelfe betraf (Offspec-Stand wurde ungefiltert übernommen).

---

## Wichtigste Datenquellen (Kurzfassung — Details in AGENTS.md)

- **Ausrüstung:** classic-armory.org, `POST /api/v1/character/equipment` mit `flavor` (nicht `version`)
  im Body. Braucht echte UTF-8-Bytes für Umlaute im Namen, verträgt aber kein `charset=utf-8` im
  Content-Type-Header (→ `ByteArrayContent` mit rohem Header, siehe `2-fetch-gear.ps1`).
- **Item-Werte:** `nether.wowhead.com/tbc/tooltip/item/<ID>?locale=0`. Die Zonen-Übersichtsseiten von
  Wowhead sind unvollständig (Teron Blutschatten fehlte komplett) — immer pro Boss-NPC abrufen.
- **Statgewichte:** wowsims.com (die gepflegte Fassung, nicht `wowsims.github.io`). Für Kaosx werden
  die Gewichte vollautomatisch über die lokale `wowsimcli-windows.exe` dynamisch simuliert (25er-Raid-Setup mit APL-Rotation) und in `daten/sim-weights.json` abgelegt. Für alle anderen Spieler dienen die offiziellen WoWSims-Presets als statischer Fallback.
- **DPS-BiS-Gegenprobe:** warcrafttavern.com, automatisiert über `4-bis-check.ps1`.
- **Tank-/Heiler-BiS-Listen:** offizielle Wowhead-Phase-3-Guides, per Hand bzw. über die
  Python-Hilfsskripte in `daten/` eingepflegt (kein automatisierter Regressionstest wie bei DPS).

---

## Bekannte Fallen (Kurzfassung — vollständige Liste in AGENTS.md)

1. **Prokk-Texte sehen aus wie feste Werte.** *„Chance on hit: Increases your haste rating by 212“* ist
   kein Dauereffekt — vor der Wertelesung bei `Chance on hit`, `Use:`, `(2) Set`, `(4) Set` abschneiden,
   aber **nicht** bei `Equip: Your`, sonst gehen echte Dauereffekte verloren.
2. **Cap-Artefakte bei Treffer/Waffenkunde.** Sim-Presets liegen oft schon am Cap; ein Gewicht von 0,00
   heißt „am Cap“, nicht „wertlos“.
3. **Sonderzeichen nie literal in `.ps1`-Dateien** — PowerShell 5.1 liest sie als ANSI. Umlaute und
   Sonderzeichen gehören in UTF-8-JSON (`roster.json`, `tier-boni.json`).
4. **Fähigkeitsnamen nicht selbst übersetzen** — in `tier-boni.json` stehen sie bewusst englisch
   (*Arcane Blast* ≠ „Arkane Explosion“, das ist Arkanschlag; *Mutilate* ≠ „Blutsturz“, das ist
   Verstümmeln).
5. **Schilde tragen „Off Hand“ als Slot** — ohne Prüfung der Rüstungsart (`Shield`) bekommen Caster
   Schilde vorgeschlagen.

---

## Was das Modell kann — und was nicht

Für DPS gilt weiterhin `ΔDPS = Wert(neues Item) − Wert(getragenes Teil im selben Slot)`, mit den
Statgewichten der jeweiligen Spec. Sockel werden beidseitig mit einem Standardstein bewertet,
Verzauberungen auf keiner Seite (sie gehen beim Wechsel mit).

Abgebildet: Ringe/Schmuck gegen das schlechtere der beiden getragenen Teile · Zweihandwaffen gegen
Waffenhand plus Schildhand · Waffenkenntnisse je Klasse · Rüstungsklasse und niedriger · Warglaives
zusätzlich als Paar-Zeile samt 2er-Bonus · BiS-Priorisierung und -Sperre für alle Rollen · Tank/Heiler
als prozentualer Zuwachs mit BiS-Gate.

**Nicht abgebildet:**

- **Schmuckstücke** bei DPS — ihr Wert steckt fast ganz in Prokks/Nutzeneffekten und ist nicht
  bewertbar; die Zeilen werden ausgeblendet (`NichtBewertbar`).
- **Tier-Set-Boni als Zahl.** Prozentboni auf einzelne Fähigkeiten lassen sich ohne Simulation nicht in
  DPS umrechnen. Stattdessen steht unter jeder Tier-Zeile der Set-Übergang als Text mit Einschätzung
  (`hoch/mittel/gering/keiner`) aus `tier-boni.json`.
- **Waffengeschwindigkeit:** Wir haben eine physische Waffentempo-Normierung eingebaut (3.6 für 2H, 2.6 für 1H), um Swing-Damage-Vorteile (Crusader Strike, Windfury, Seal of Blood) akkurat abzubilden.
- **Tank-/Heiler-Feinmechaniken** wie Blockwert-Verteilung, Heil-Overhealing oder Aggro — die
  BiS-Gate-Logik fängt die gröbsten Fehlanreize ab, ersetzt aber keine Simulation.
- **Spec-Mechaniken wie Kampfgewandtheit** (schnelle Schildhand gibt dem Schurken Energie zurück) —
  deshalb ist der Warglaive-Vorsprung der Krieger gegenüber dem Schurken vermutlich etwas überzeichnet.

## Verlässlichkeit

`4-bis-check.ps1` prüft ausschließlich die **DPS-Empfehlungen** gegen warcrafttavern.com. Letzter Stand:
**136 Empfehlungen · 57 % auf BiS-Platz 1 · 88 % in den BiS-Top-3 · 9 nicht gelistet** (meist Marken-
oder Trash-Items, die diese Guides gar nicht führen). Nach jeder Modelländerung erneut laufen lassen —
es ist der beste vorhandene Regressionstest, hat hier bereits mehrere echte Fehler aufgedeckt (Prokk-
Falle, Distanzwaffen für Nahkämpfer, zu schnelle Waffen für Verstärkung/Schurke).

Für **Tank und Heiler existiert kein automatisierter Gegentest** — die BiS-Listen dort wurden von Hand
gegen offizielle Wowhead-Guides abgeglichen und punktuell nachgepflegt.

---

## Offene Punkte

1. **Knappheitsspalten fehlen weiterhin.** Die Rohdaten liegen in `quellen/p3-alternativen-*.md`
   vollständig vor (Marken-Sortiment, T6-Teile, Handwerk, Trash); ausgewertet und in die Seite
   eingebaut ist es noch nicht.
2. **Markenhändler im Spiel gegenprüfen**, sobald Phase 3 live ist — Wowheads Phasenzuordnung ist
   teils widersprüchlich (gleiche Item-Reihe mal Phase 3, mal Phase 4 markiert).
3. **Buff-Annahmen der Statgewichte** sind nicht spec-übergreifend auf identische Raid-Buffs verifiziert.
4. **Ein automatisierter Regressionstest für Tank/Heiler** wäre sinnvoll, analog zu `4-bis-check.ps1`.
5. **Aufräumen im `daten/`-Ordner:** die Python-Hilfsskripte und die Wurzeldateien `raw.html`/`temp.csv`
   sind Arbeitsartefakte einzelner Sitzungen und aktuell mitversioniert — ein `.gitignore` gibt es noch
   nicht.
