# TBC Loot-Prioritäten — Phase 3 (Mount Hyjal & Black Temple)

Werkzeug für den Loot-Rat der Gilde **Resurrected** auf **Thunderstrike EU** (WoW TBC Anniversary,
Serverstand Patch 2.5.6). Rechnet für jedes Phase-3-Item und jeden Raider aus, wie viel Zuwachs es ihm
**gegenüber seiner tatsächlich getragenen Ausrüstung** bringt, und veröffentlicht daraus eine
sortier- und filterbare HTML-Seite.

**Deckt alle drei Rollen ab** (11 DPS-Specs, 2 Tanks, 4 Heiler) und läuft vollautomatisiert: ein
nächtlicher GitHub-Actions-Lauf holt Kader, Gear und — für einzelne Spieler — frisch simulierte
Stat-Gewichte, rechnet neu und veröffentlicht über GitHub Pages. Die Seite bietet einen
Multi-Select-Spieler-Filter für den direkten Vergleich mehrerer Raider bei der Vergabe.

Repo: `github.com/Kaos-WoW/loot-prio` · Ausgabe: `ausgabe/loot-prio-p3.html` bzw. `index.html`
(identischer Inhalt, `index.html` ist die von GitHub Pages ausgelieferte Fassung im Repo-Wurzelverzeichnis).

---

## Für Menschen, die nur die Seite lesen wollen

Nichts zu tun. Die Seite aktualisiert sich nachts automatisch (siehe „Automatisierung“ unten) und zeigt
den Stand nach dem letzten Raid. Ein lila Blitz-Knopf auf der Seite startet das Update vollautomatisch im
Hintergrund, indem er eine Supabase Edge Function aufruft, die den GitHub-Actions-Workflow triggert.

## Für alle, die am Code weiterarbeiten

**Diese README ist die Übersicht für Menschen.** Die dichte, agentenorientierte Fassung mit jedem
Stolperstein und dem genauen Konventionenkatalog steht in **[`AGENTS.md`](AGENTS.md)** — die Datei ist
für den nächsten KI-Agenten geschrieben (aktuell wechseln sich Claude Code und Gemini/Antigravity ab)
und sollte bei jeder inhaltlichen Änderung mitgepflegt werden, damit beide Dateien nicht auseinanderlaufen.

### Schnellstart (lokal)

Alle Skripte sind PowerShell 5.1 und finden ihre Daten über `$PSScriptRoot` — der Ordner darf verschoben
werden.

```powershell
.\0-import-roster.ps1   # Kader aus dem Google Sheet                -> roster.json
.\1-fetch-items.ps1     # Item-Pool + Werte von Wowhead              -> daten/items.json
.\2-fetch-gear.ps1      # getragene Ausrüstung, live + Plausibilitätscheck -> daten/players.json
python 7-stat-gewichte.py # Stat-Gewichte aller DPS-Spieler          -> daten/sim-weights.json
python 6-trinket-sim.py # Schmuckstuecke per Differenzsimulation     -> daten/trinket-werte.json
.\3-compute.ps1         # die eigentliche Rechnung                   -> daten/upgrades.json
.\4-bis-check.ps1       # Gegenprobe DPS + Tank/Heiler               -> Bericht auf der Konsole
.\5-build-payload.ps1   # Seite bauen                                -> ausgabe/loot-prio-p3.html
```

`4-bis-check.ps1` **liest** `daten/bis-listen-phasen.json`, schreibt sie aber nicht. Aufgefrischt wird
die Datei von Hand über `python daten/scrape-bis-wowhead.py` (alle 17 Specs, alle Phasen).

⚠️ **BiS-Listen kommen ausschließlich von Wowhead.** Die früheren Skripte `scrape_bis.py`
(warcrafttavern.com) und `scrape_wowhead_final.py` (nur Phase 3) sind entfallen, ebenso die von ihnen
erzeugte `bis-listen.json`.

**Normaler Durchlauf nach einem Raid** (das macht die Automatisierung nachts von selbst — siehe
`.github/workflows/sync.yml` für die verbindliche Reihenfolge inklusive eines Sicherheits-Checks, der
abbricht, falls der Gear-Abruf verdächtig wenige Spieler liefert):

```powershell
.\0-import-roster.ps1; .\2-fetch-gear.ps1; python 7-stat-gewichte.py; .\3-compute.ps1; .\4-bis-check.ps1; .\5-build-payload.ps1
```

Die Schmuckstück-Simulation (`python 6-trinket-sim.py`) läuft **nicht** bei jedem Durchgang mit — sie
dauert gut 15 Minuten und ihre Werte ändern sich nur, wenn sich das übrige Gear spürbar ändert. Nach
einem Raid mit vielen Neuteilen einmal von Hand nachziehen.

`2-fetch-gear.ps1` meldet jeden Slotwechsel seit dem letzten Abruf und verwirft verdächtige Stände
(siehe Plausibilitätscheck unten). Alle Skripte nutzen `daten/cache-tooltips.json`, Wiederholungsläufe
sind daher schnell.

Die PowerShell-Schritte brauchen **kein Python und kein Node**. Die beiden Simulationsschritte
(`7-stat-gewichte.py`, `6-trinket-sim.py`) sind dagegen Python und laden bei Bedarf die
WoWSims-Kommandozeilenversion herunter (`bin/wowsimcli-windows.exe`). Python statt PowerShell, weil
dessen `ConvertTo-Json` die tief verschachtelten Sim-Anfragen zerlegt. Ebenfalls Python sind die beiden
Beschaffungsskripte in `daten/`: `scrape-bis-wowhead.py` (BiS-Listen) und `scrape-pool-wowhead.py`
(Item-Pools für Zul'Aman und Sunwell). Sie laufen nicht bei jedem Durchgang, sondern nach Bedarf.

---

## Automatisierung

**GitHub Actions** (`.github/workflows/sync.yml`) läuft täglich um 03:00 UTC und lässt sich zusätzlich
manuell über das GitHub-Interface oder über den lila Blitz-Knopf auf der Seite auslösen (der ruft eine
Supabase Edge Function auf, die per API den Workflow anstößt — das GitHub-Token liegt dafür nur im
Supabase Vault, nie im Client-Code).

Der Workflow importiert das Roster, holt das Gear, bricht ab, wenn dabei verdächtig wenige Spieler
zurückkommen (Schutz gegen einen kaputten Abruf), simuliert die individuellen Stat-Gewichte **aller**
DPS-Spieler, rechnet neu und **committet und pusht das Ergebnis automatisch** (`roster.json`,
`daten/players.json`, `daten/cache-tooltips.json`, `daten/payload.json`, `index.html`,
`ausgabe/loot-prio-p3.html`, `daten/bis-listen-phasen.json`, `daten/bis-check.json`, `daten/sim-weights.json`,
`daten/trinket-werte.json`, `daten/upgrades-p4.json`, `daten/upgrades-p5.json`). Das ist ein bewusst eingerichteter,
system-eigener Push und keine Ausnahme von der Regel, dass ein Assistent nicht ungefragt pusht — die
Automatisierung wurde als solche eingerichtet und genehmigt.

**GitHub Pages** hostet die Seite direkt aus dem Hauptverzeichnis (`index.html`) des `main`-Branches.
Clientseitige Abfragen der WoW-Armory laufen über den Proxy `corsproxy.io` auf die API von
`classic-armory.org`, weil GitHub Pages rein statisch ist und keinen eigenen Proxy anbietet.

(Frühere Fassungen dieses Projekts hosteten über Netlify mit einer Netlify-Function als Trigger. Das
ist vollständig durch GitHub Pages + Supabase abgelöst, die zugehörigen Dateien wurden entfernt.)

---

## Roster — aus Google Sheets, nicht mehr von Hand

`0-import-roster.ps1` liest den Kader aus einem öffentlichen Google Sheet (Tabellenblatt „Übersicht“)
und schreibt `roster.json` **komplett neu**. Wer Spieler oder Specs ändern will, trägt das im Sheet ein,
nicht mehr in der Datei — ein manueller Edit an `roster.json` wird beim nächsten automatischen Lauf
überschrieben (punktuelle Handkorrekturen zwischen zwei Läufen kommen vor, siehe Commit-Historie, sind
aber nicht der vorgesehene Weg).

Die deutschen Klassen-/Spec-Bezeichnungen aus dem Sheet werden robust auf interne Spec-Keys gemappt
(Teilstring-Erkennung, z. B. „Furor“ → `FURY`, „Schutz“ → `PROT_PALA`, „Wiederherstellung“ →
`RESTO_SHAM`/`RESTO_DRUID`). Das Google Sheet muss auf „Jeder mit dem Link kann lesen“ freigegeben sein,
sonst schlägt der CSV-Export fehl.

---

## Phasen 3, 4 und 5

Die Seite hat oben eine Umschaltleiste: **Phase 3** (Hyjal & Black Temple), **Phase 4** (Zul'Aman),
**Phase 5** (Sunwell). Die gewählte Phase bestimmt Item-Pool *und* BiS-Listen; die Wahl wird im
Browser gemerkt. Die Phasen sind **kumulativ** — eine Phase-5-Liste enthält weiterhin BT-Teile, weil
die dort oft BiS bleiben.

```powershell
python daten\scrape-bis-wowhead.py       # BiS-Listen aller Phasen -> daten/bis-listen-phasen.json
python daten\scrape-pool-wowhead.py      # Item-Pools ZA/Sunwell   -> quellen/p4-,p5-item-pool.json
.\1-fetch-items.ps1 -Phase 4             # -> daten/items-p4.json  (ohne -Phase: items.json wie bisher)
.\3-compute.ps1     -Phase 4             # -> daten/upgrades-p4.json
```

**Ohne `-Phase` verhalten sich beide Skripte exakt wie vorher** — das ist bewusst so gebaut und
wurde per Prüfsumme nachgewiesen, damit die laufende Phase-3-Seite von der Erweiterung nicht
berührt wird. `5-build-payload.ps1` nimmt Phase 4 und 5 nur auf, wenn ihre Dateien existieren;
fehlen sie, entsteht die Seite von vorher ganz ohne Umschaltleiste.

### Gegenprobe je Phase

`4-bis-check.ps1` prüft inzwischen **alle Phasen** und ausschließlich gegen **Wowhead**
(`.\4-bis-check.ps1 -Phasen 5` für eine einzelne). Stand 2026-08-10:

| Phase | DPS: Platz 1 / Top 3 | Tank/Heiler: Platz 1 / Top 3 |
|---|---|---|
| 3 | 71 % / 86 % | 77 % / 90 % |
| 4 | 59 % / 69 % | 80 % / 90 % |
| 5 | 73 % / 80 % | 82 % / 94 % |

⚠️ **Die niedrigere DPS-Quote in Phase 4 und 5 ist kein Defekt**, sondern der oben beschriebene
Effekt in verstärkter Form: Die Guides optimieren für einen Charakter, der die jeweilige Phase
bereits trägt. Unsere Raider stecken in Phase-3-Ausrüstung, für sie sind andere Teile die größten
Sprünge. Nachgemessen: In Phase 4 sind **23 der 49 Abweichungen Marken-Items** (für einen
P3-Charakter echte Upgrades, für einen P4-Charakter längst überholt), in Phase 5 überwiegend
Sunwell-Raid-Teile. Als **Änderungsdetektor je Phase** bleibt die Zahl trotzdem brauchbar — ein
plötzlicher Einbruch deutet weiterhin auf einen echten Fehler hin.

Die früher dokumentierten 58 % / 79 % (Phase 3) stammen von warcrafttavern.com. Seit dem Wechsel
auf Wowhead sind es 60 % / 81 % — praktisch derselbe Wert, was für die Belastbarkeit beider
Quellen spricht, aber streng genommen nicht vergleichbar.

**Schmuckstücke späterer Phasen** werden mit `python 6-trinket-sim.py --phase 5` simuliert (ohne
`--phase` weiterhin Phase 3). Die Ergebnisdatei `daten/trinket-werte.json` ist gemeinsam und wird
ergänzt, ein Phase-5-Lauf wirft die Phase-3-Werte also nicht weg. Nach dem Lauf für Phase 5 sind
alle DPS-Schmuckstücke bewertet; es bleiben 13 Zeilen „nicht bewertbar", ausschließlich **Tank und
Heiler** — für die simuliert das Werkzeug grundsätzlich nicht und die Näherung kennt diese neuen
Gegenstände nicht.

⚠️ **Zwei Simulationen dürfen nicht gleichzeitig laufen.** Die Ein-/Ausgabedateien der WoWSims-CLI
liegen im Temp-Verzeichnis; sie tragen seit 2026-08-10 die Prozessnummer im Namen, vorher hießen sie
fest und zwei parallele Läufe löschten sich gegenseitig das Ergebnis. Der Abbruch sieht dabei
irreführend aus: die CLI meldet „All 16 sims finished successfully", trotzdem fehlt die Ausgabedatei.

---

## Rollen und Bewertungsmethodik

| Rolle | Specs | Bewertung |
|---|---|---|
| **DPS** | Furor/Waffen-Krieger, Vergeltung, Verstärkung, Kampf-Schurke, Jäger, Hexer, Magier, Schattenpriester, Elementar, Gleichgewicht | absoluter DPS-Zuwachs (`ΔDPS`), direkt zwischen Specs vergleichbar |
| **Tank** | Schutz-Paladin, Feral-Tank | prozentualer Zuwachs relativ zum Gesamtwert der aktuell getragenen Ausrüstung |
| **Heiler** | Wiederherstellung-Druide/Schamane, Heilig-Paladin, Heilig-Priester | prozentualer Zuwachs relativ zum Gesamtwert der aktuell getragenen Ausrüstung |

⚠️ **Die Prozentzahlen der beiden Zeilen bedeuten nicht dasselbe.** Bei DPS ist es der Anteil an der
Gesamt-DPS des Spielers, bei Tank/Heiler der Anteil am Wert der getragenen Ausrüstung. Die Seite
schreibt die Bezugsgröße deshalb unter jede Zahl (`8.29% von 1418 DPS` gegen `1.88% der Ausrüstung`)
und zeigt bei DPS den absoluten ΔDPS als Hauptzahl.

Für Tank und Heiler kann der Zuwachs auch **±0 %** sein. Das ist kein Rechenfehler: Diese Rollen werden
gegen die BiS-Liste gegatet (s. u.), und ein BiS-Item wird auch dann angezeigt, wenn es statmäßig
gerade **kein** Gewinn gegenüber dem getragenen Teil ist. Solche Zeilen sind auf der Seite ausdrücklich
als „kein Statgewinn — steht nur wegen BiS in der Liste" gekennzeichnet.

Für Tank und Heiler wird **zusätzlich gegen die jeweilige BiS-Liste gegatet**: ein Item taucht für diese
Rollen nur auf, wenn es in der hinterlegten Phase-3-BiS-Liste der Spec steht. Das verhindert, dass ein
rein statistisches Modell (das Blockwert, Abhärtung oder Heilungsmenge nicht simuliert) Tanks und Heilern
unsinnige Empfehlungen gibt.

**BiS-Priorisierung (alle Rollen):** Items, die für eine Spec Best-in-Slot sind, werden vor bloßen
Upgrades einsortiert und als Exklusivitäts-Badge ausgewiesen — „★ BiS für 1 Spieler“ bzw. „für 2 Spieler“
markiert die knappsten, eindeutigsten Vergabeentscheidungen. Ist ein Item BiS für eine andere Spec, aber
nicht für die anfragende, wird die Zeile als „Gesperrt“ markiert statt als Upgrade angeboten.

**„Heiß umkämpfter Loot“**: eine eigene Übersichtstabelle oberhalb der Haupttabelle zeigt die
begehrtesten Items — sortiert nach Anzahl der BiS-Kandidaten und Gesamtzahl der Interessenten — mit den
jeweiligen Spielern. Tier-6-Tokens sind hier ausgeschlossen (die haben eine eigene Tabelle, s. u.),
Schmuckstücke sind trotz der DPS-Bewertungslücke als (BiS)/(Bedarf) integriert.

**Tier-6-Tokens** haben eine eigene Ansicht, weil sich immer **drei Klassen ein Token teilen**
(Eroberer = Paladin/Priester/Hexer, Beschützer = Krieger/Jäger/Schamane, Bezwinger =
Schurke/Magier/Druide). In der Haupttabelle steht das *eingetauschte* Rüstungsteil — beim Loot-Rat fällt
aber das Token. Die Tabelle „Tier-6-Tokens“ dreht die Sicht deshalb um: pro Token stehen dort alle
Anwärter, wie viele davon BiS-#1-Kandidaten sind, und der Boss, der es wirklich fallen lässt
(Handschuhe = Azgalor, Helm = Archimonde, Schultern = Mutter Shahraz, Beine = Illidari-Rat, Brust =
Illidan). Die Anwärter sind **nach Rolle getrennt** aufgeführt: DPS rechnet in absolutem ΔDPS,
Tank/Heiler in Prozent — eine gemeinsame Rangliste über beides wäre bedeutungslos. Zusätzlich zeigt der
Boss-Filter T6-Teile jetzt auch unter dem Boss des zugehörigen Tokens.

**Individuelle Stat-Gewichte statt Presets:** `7-stat-gewichte.py` simuliert die Stat-Gewichte **für
jeden DPS-Spieler einzeln** aus seinem Live-Gear, statt die statischen Presets aus `3-compute.ps1` zu
verwenden — rund 20 Sekunden je Spieler. Das ist wichtig, weil Gewichte vom eigenen Gear abhängen:
Wer am Trefferkap steht, für den ist Trefferwertung wertlos, für den Nebenmann nicht. Tank und Heiler
laufen weiterhin auf Presets, dort ist die Leitmetrik ohnehin prozentual.

Derselbe Lauf schreibt auch die **gemessene Basis-DPS** jedes Spielers als `_basisDps` mit. Sie ist der
Nenner der Prozentanzeige auf der Seite. Vorher lief der gegen einen hartcodierten Spec-Schätzwert
(RET 1600 gegen tatsächlich gemessene ~1456) — der Zähler war also individuell simuliert und der Nenner
generisch. Zeilen, für die keine gemessene Basis vorliegt, sind auf der Seite mit `*` gekennzeichnet.

Die Waffenkoeffizienten lassen sich nicht als Stat messen (Waffenschaden ist kein Eintrag im
Bonus-Stat-Array) und werden deshalb aus dem gemessenen Angriffskraft-Gewicht hochgerechnet, im
Verhältnis des jeweiligen Presets.

⚠️ **Diese Simulation war bis 2026-08-02 in drei Punkten defekt.** Die WoWSims-CLI ignoriert falsch
platzierte Felder stillschweigend — ohne Fehler, ohne Warnung:

1. **Keine Talente.** Der Talentstring stand im Spec-Block statt am Spieler → die Sim rechnete einen
   talentlosen Paladin (614 statt 1456 DPS). Kaosx' Stat-Gewichte waren dadurch um Faktor 2,4–3,5 zu
   klein, seine ΔDPS-Werte auf der veröffentlichten Seite also systematisch zu niedrig — im Loot-Rat
   wirkte er als jemand, der weniger von Items profitiert als alle anderen.
2. **Keine Bossrüstung.** Ein Feld `armor` am Ziel existiert nicht; die Rüstung gehört ins Statarray
   auf Index 31. Die Sim schlug auf ein ungepanzertes Ziel ein (rund 17 % zu hohe DPS), und
   Rüstungsdurchschlag wurde folgerichtig immer mit 0 bewertet.
3. **Zu kleine Messprobe.** Die Gewichte wurden mit +30 Statpunkten gemessen. Tempo wirkt in TBC über
   Schwellenwerte: +30 ergab −1,4 DPS (Gewicht auf 0 geklemmt, „wertlos"), +100 ergab +47,6 DPS.

Alles drei behoben. Als Plausibilitätsprobe taugt die Zaubermacht: sie muss mit und ohne Bossrüstung
identisch bleiben (Heiligschaden ignoriert Rüstung), während die physischen Gewichte fallen — genau so
verhält es sich jetzt. Kaosx' Rangfolge verschiebt sich dadurch spürbar, Zweihandwaffen steigen
(*Torch of the Damned* von 35,6 auf 52,9 DPS und damit auf Platz 1).

---

## Schutzmechanismen

**Verräter-Items gegen Doppelspec-Verwechslung:** Der Wertungsvergleich unten erkennt nicht, wenn ein
Feral-Druide statt im Tank- im Katzen-DPS-Set ausgeloggt ist — beide Sets sind Leder auf ähnlichem
Itemlevel, der Wert bricht also nicht ein. Deshalb gibt es eine Liste von Gegenständen, deren bloße
Anwesenheit den Offspec verrät: Trägt ein `FERAL_TANK` den **Wolfshead Helm**, wird der Abruf
unabhängig vom Wert verworfen. Weitere Doppelspec-Spieler brauchen jeweils einen eigenen Marker.

**Plausibilitätscheck beim Gear-Abruf:** `2-fetch-gear.ps1` vergleicht bei jedem Abruf den neuen
PvE-Statwert der Ausrüstung mit dem zuletzt gespeicherten. Fällt der Wert um mehr als 20 %, wird der
neue Stand verworfen und der alte behalten — typischerweise, weil der Spieler gerade in Arena-/BG-
Ausrüstung oder einem Nebenspec ausgeloggt war. Das Skript gibt in diesem Fall eine Warnung mit altem
und neuem Wert aus. Das löst das Problem, das früher Valiror und Pflasterelfe betraf (Offspec-Stand
wurde ungefiltert übernommen).

**Cap-Stat-Untergrenze:** Verhindert, dass Statgewichte für Treffer/Waffenkunde/Zaubertreffer nahe null
fallen, nur weil ein Spieler oder das Preset gerade am Cap liegt, und die Formel deshalb faelschlich
Cap-Gear zum Ablegen vorschlägt (siehe „Cap-Stat-Abwärtsspirale“ in AGENTS.md).

**Mindestspieler-Guard in der Automatisierung:** Der nächtliche Workflow bricht ab, bevor er etwas
committet, wenn `daten/players.json` nach dem Gear-Abruf verdächtig wenige Einträge hat — verhindert,
dass ein kaputter API-Abruf die veröffentlichte Seite mit Fehldaten überschreibt.

---

## Wichtigste Datenquellen (Kurzfassung — Details in AGENTS.md)

- **Ausrüstung:** classic-armory.org, `POST /api/v1/character/equipment` mit `flavor` (nicht `version`)
  im Body. Braucht echte UTF-8-Bytes für Umlaute im Namen, verträgt aber kein `charset=utf-8` im
  Content-Type-Header (→ `ByteArrayContent` mit rohem Header, siehe `2-fetch-gear.ps1`).
- **Item-Werte:** `nether.wowhead.com/tbc/tooltip/item/<ID>?locale=0`. Die Zonen-Übersichtsseiten von
  Wowhead sind unvollständig (Teron Blutschatten fehlte komplett) — immer pro Boss-NPC abrufen.
- **Statgewichte:** statische Presets aus wowsims.com (die gepflegte Fassung, nicht
  `wowsims.github.io`) in `3-compute.ps1` fest hinterlegt. Für einzelne Spieler (aktuell Kaosx) werden
  sie zusätzlich dynamisch über die lokale `wowsimcli-windows.exe` simuliert (25er-Raid-Setup mit
  APL-Rotation) und überschreiben das Preset.
- **BiS-Listen (alle Rollen, alle Phasen):** offizielle Wowhead-Guides über
  `daten/scrape-bis-wowhead.py` → `daten/bis-listen-phasen.json`. Sie dienen doppelt: als BiS-Gate in
  `3-compute.ps1` und als Gegenprobe in `4-bis-check.ps1` (dort Tank/Heiler nach `Pct` statt `Delta`
  sortiert, s. „Verlässlichkeit"). **Warcraft Tavern wird nicht mehr verwendet.**

---

## Bekannte Fallen (Kurzfassung — vollständige Liste in AGENTS.md)

1. **Prokk-Texte sehen aus wie feste Werte.** *„Chance on hit: Increases your haste rating by 212“* ist
   kein Dauereffekt — vor der Wertelesung bei `Chance on hit`, `Use:`, `(2) Set`, `(4) Set` abschneiden,
   aber **nicht** bei `Equip: Your`, sonst gehen echte Dauereffekte verloren.
2. **Cap-Artefakte bei Treffer/Waffenkunde.** Presets oder simulierte Spieler liegen oft schon am Cap;
   ein Gewicht nahe 0,00 heißt „am Cap“, nicht „wertlos“ — dagegen gibt es jetzt eine feste Untergrenze.
3. **Sonderzeichen nie literal in `.ps1`-Dateien** — PowerShell 5.1 liest sie als ANSI. Umlaute und
   Sonderzeichen gehören in UTF-8-JSON (`roster.json`, `tier-boni.json`).
4. **Fähigkeitsnamen nicht selbst übersetzen** — in `tier-boni.json` stehen sie bewusst englisch
   (*Arcane Blast* ≠ „Arkane Explosion“, das ist Arkanschlag; *Mutilate* ≠ „Blutsturz“, das ist
   Verstümmeln).
5. **Schilde tragen „Off Hand“ als Slot** — ohne Prüfung der Rüstungsart (`Shield`) bekommen Caster
   Schilde vorgeschlagen.
6. **Tier-Tokens niemals über hartcodierte Item-IDs gruppieren.** Ein Token gehört drei Klassen; die
   Gruppen werden aus `items.json` abgeleitet (Setname + Slot). Die frühere ID-Liste war stark
   fehlerhaft und hat die Konkurrenzzahlen verfälscht — Details in AGENTS.md.
7. **`d` (Zuwachs) ist rollenübergreifend nicht vergleichbar** — bei DPS absoluter ΔDPS, bei Tank/Heiler
   ein roher Stat-Score. Für rollenübergreifende Listen (Tokens!) nach Rolle trennen.
8. **Zweihandwaffen-Tempo-Normierung nur für RET.** Da in TBC fast alle physischen Spezialangriffe normiert sind, wird die Tempo-Normierung nur für RET-Paladine angewendet und dort linear statt quadratisch gerechnet, um eine Überbewertung langsamer Waffen (wie *Torch* vs. *Cataclysm's Edge*) zu verhindern.

---

## Was das Modell kann — und was nicht

Für DPS gilt weiterhin `ΔDPS = Wert(neues Item) − Wert(getragenes Teil im selben Slot)`, mit den
Statgewichten der jeweiligen Spec (Preset oder — für Kaosx — individuell simuliert). Sockel werden
beidseitig mit einem Standardstein bewertet, Verzauberungen auf keiner Seite (sie gehen beim Wechsel mit).

Abgebildet: Ringe/Schmuck gegen das schlechtere der beiden getragenen Teile · Zweihandwaffen gegen
Waffenhand plus Schildhand, mit Tempo-Normierung · Waffenkenntnisse je Klasse · Rüstungsklasse und
niedriger · Warglaives zusätzlich als Paar-Zeile samt 2er-Bonus · BiS-Priorisierung und -Sperre für alle
Rollen · Tank/Heiler als prozentualer Zuwachs mit BiS-Gate · Cap-Stat-Untergrenze gegen
De-gearing-Vorschläge.

**Nicht abgebildet:**

- **Schmuckstücke für Tank und Heiler** — dort läuft weiter die Näherung, weil WoWSims für diese
  Rollen keine belastbare Zielgröße liefert. Für DPS werden sie simuliert (siehe unten).
- **Tier-Set-Boni als Zahl.** Prozentboni auf einzelne Fähigkeiten lassen sich ohne Simulation nicht in
  DPS umrechnen. Stattdessen steht unter jeder Tier-Zeile der Set-Übergang als Text mit Einschätzung
  (`hoch/mittel/gering/keiner`) aus `tier-boni.json`.
- **Tank-/Heiler-Feinmechaniken** wie Blockwert-Verteilung, Heil-Overhealing oder Aggro — die
  BiS-Gate-Logik fängt die gröbsten Fehlanreize ab, ersetzt aber keine Simulation.
- **Spec-Mechaniken wie Kampfgewandtheit** (schnelle Schildhand gibt dem Schurken Energie zurück) —
  deshalb ist der Warglaive-Vorsprung der Krieger gegenüber dem Schurken vermutlich etwas überzeichnet.

## Schmuckstücke

Schmuckstücke waren lange gar nicht bewertet, weil ihr Wert in Prokks und Nutzeneffekten steckt.
Seit dem 03.08.2026 werden sie **simuliert** und sind normaler Teil der Liste — die frühere Beta-Seite
(`index-beta.html`) ist damit entfallen.

`6-trinket-sim.py` tauscht jedes Schmuckstück im **echten Gear** des Spielers aus und misst die
DPS-Differenz direkt in WoWSims. Damit entfällt die Frage nach der Prokk-Uptime vollständig — es wird
nicht mehr geschätzt, sondern gemessen. Eine Sim dauert rund zwei Sekunden, ein Spieler rund 50.

```bash
python 6-trinket-sim.py          # alle DPS-Spieler -> daten/trinket-werte.json
python 6-trinket-sim.py Kaosx    # nur einzelne (ergänzt die Datei, ersetzt sie nicht)
```

`3-compute.ps1` nimmt einen gemessenen Wert direkt als Zuwachs und greift nur dort auf die Näherung
zurück, wo keiner vorliegt (Tanks, Heiler, Spieler ohne Spec-Konfiguration). Die Spec-Konfiguration
liegt in [`spec-sims/`](spec-sims/) und stammt vollständig aus dem WoWSims-Quelltext — Talente,
Rotationen und Proto-Schlüssel sind abgerufen, nicht geraten. **Der Raid-Aufbau ist für alle Specs
absichtlich identisch**, denn nur so sind die DPS-Zahlen zwischen Specs vergleichbar.

### Warum die alte Näherung ersetzt wurde

**Sie hielt der Gegenprobe nicht stand.** Gegen die WoWSims-Simulation gemessen (Kaosx,
Vergeltungs-Paladin, 10.000 Iterationen, Streuung ±0,1 DPS) liegt sie bei allen drei geprüften
Schmuckstücken nicht nur daneben, sondern im **falschen Vorzeichen**:

| Schmuckstück | Näherung | Simulation |
|---|---|---|
| Madness of the Betrayer | +30,0 DPS | **−21,4 DPS** |
| Icon of Unyielding Courage | +27,4 DPS | **−49,2 DPS** |
| Tsunami Talisman | +13,5 DPS | **−15,5 DPS** |

Das ließ sich nicht über bessere Uptime-Schätzungen reparieren — lineare Statgewichte mal flach
gemitteltem Prokk bilden weder Burst-Cooldowns noch Rüstungsdurchschlag ab. Deshalb der Umstieg auf
die Simulation. Die Näherung bleibt als Rückfall für alles, was nicht simuliert wird — also für
Tanks und Heiler.

## Verlässlichkeit

`4-bis-check.ps1` prüft **beide Rollengruppen und alle Phasen automatisiert** gegen die
**Wowhead**-Guides (`daten/bis-listen-phasen.json`): DPS sortiert nach ΔDPS, Tank/Heiler nach dem
prozentualen Zuwachs `Pct`, da `Delta` dort rollenübergreifend nicht vergleichbar ist. Die aktuellen
Werte je Phase stehen weiter oben unter „Gegenprobe je Phase". Zur Einordnung des Phase-3-Werts:

- **DPS: 160 Empfehlungen · 71 % auf BiS-Platz 1 · 86 % in den BiS-Top-3.** Die nicht gelisteten
  Empfehlungen sind ausnahmslos Marken- und Trash-Items, die diese Guides gar nicht führen.
- **Tank/Heiler: 70 Empfehlungen · 77 % auf BiS-Platz 1 · 90 % in den BiS-Top-3.** Der höhere Wert ist
  erwartbar: Tank/Heiler-Empfehlungen sind bereits gegen dieselbe BiS-Liste gegatet (s. o.), ein
  Vorschlag außerhalb der Liste kann hier praktisch nicht entstehen.

Nach jeder Modelländerung erneut laufen lassen — es ist der beste vorhandene Regressionstest und hat
mehrere echte Fehler aufgedeckt (Prokk-Falle, Distanzwaffen für Nahkämpfer, zu schnelle Waffen für
Verstärkung/Schurke, und zuletzt eine Skalenvermischung bei den simulierten Gewichten).

⚠️ **Der Wert ist eine Übereinstimmungsquote, kein Genauigkeitsmaß.** Die Guides sind eine einzelne
Meinung, gerechnet für einen *generischen* Charakter. Dieses Werkzeug rechnet dagegen mit dem
tatsächlich getragenen Gear jedes Spielers — wer am Trefferkap steht, für den ist Trefferwertung
wirklich wertlos, im Guide aber nicht. Eine Abweichung kann also genauso gut heißen, dass das Werkzeug
recht hat. Als **Regressionstest** ist die Zahl trotzdem wertvoll: ein plötzlicher Einbruch deutet
zuverlässig auf einen echten Fehler hin, so wurde die Skalenvermischung überhaupt erst gefunden.

Die früher dokumentierten 88 % (DPS) stammen vom `main`-Stand vor der Pool-Erweiterung und sind nicht
vergleichbar.

---

## Ordnerüberblick

| Pfad | Inhalt |
|---|---|
| `0`–`5-*.ps1` | die PowerShell-Kette |
| `7-stat-gewichte.py` | Stat-Gewichte aller DPS-Spieler per Simulation |
| `wowsims-cli.ps1` | **abgelöst** durch `7-stat-gewichte.py`, liegt nur noch als Referenz herum |
| `6-trinket-sim.py` | Schmuckstück-Bewertung per Differenzsimulation (Python, braucht die WoWSims-CLI) |
| `spec-sims/` | Spec-Konfiguration für die Simulation: Talente, Rotationen, gemeinsamer Raid-Aufbau |
| `roster.json` | wird von `0-import-roster.ps1` aus dem Google Sheet überschrieben, nicht von Hand pflegen |
| `tier-boni.json` | **von Hand gepflegt**: Set-Boni T5/T6 mit DPS-Einschätzung |
| `vorlage.html` | Seitengerüst; `"__DATEN__"` wird beim Bau durch die JSON-Nutzlast ersetzt |
| `daten/` | Zwischenstände, Tooltip-Cache; `scrape_bis.py`/`scrape_wowhead_final.py` holen `bis-listen.json` neu |
| `bin/` | heruntergeladene WoWSims-CLI plus deren Ein-/Ausgabedateien |
| `ausgabe/`, `index.html` | die fertige Seite (zweimal, s. „Automatisierung“) |
| `quellen/` | Rechercheunterlagen aus dem Erstaufbau: Item-Pool, Statgewichte, Alternativen, Gear-Stand |
| `supabase/functions/trigger-sync/` | Edge Function für den Blitz-Knopf |
| `.github/workflows/sync.yml` | die Automatisierung |

---

## Offene Punkte

1. **Supfreshyo ist ausgeblendet**, weil sein Armory-Stand das Katzen-DPS-Set zeigt. Sobald er einmal
   im Tank-Set erfasst wurde, aus `$UNSICHER` in `3-compute.ps1` entfernen.
2. **Rassen in `spec-sims/specs.json` sind angenommen**, nicht abgerufen — `players.json` enthält keine.

## Bewusst verworfen

**Knappheitsspalten** (Anzahl Alternativen im Slot, frühester Boss mit Alternative, Exklusiv-Flag).
Einmal gebaut und wieder entfernt (Commit `a413a14`), am 2026-08-09 endgültig verworfen: In Phase 3
gibt es je Slot **meist gar keine und sonst genau eine** Alternative. Eine Spalte, die fast überall
„0" oder „1" anzeigt, trägt keine Entscheidung — sie kostet nur Breite in einer ohnehin breiten
Tabelle. Die Rohdaten in `quellen/p3-alternativen-*.md` bleiben als Rechercheunterlage liegen.
**Nicht erneut vorschlagen.**

Der Hinweis „Alternative: …“ unter einzelnen Tier-Zeilen ist etwas anderes und bleibt: er nennt das
konkrete Ausweichteil samt Zuwachs, statt nur eine Anzahl zu zählen.
