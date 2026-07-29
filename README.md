# TBC Loot-Prioritäten — Phase 3 (Mount Hyjal & Black Temple)

Werkzeug für den Loot-Rat der Gilde **Resurrected** auf **Thunderstrike EU** (WoW TBC Anniversary,
Serverstand Patch 2.5.6). Rechnet für jedes Phase-3-Item und jeden Raider aus, wie viel DPS-Zuwachs
es ihm **gegenüber seiner tatsächlich getragenen Ausrüstung** bringt, und baut daraus eine
sortier- und filterbare HTML-Seite.

Ergebnis liegt unter `ausgabe/loot-prio-p3.html` (im Browser öffnen, keine Abhängigkeiten).

---

## Schnellstart

Alle Skripte sind PowerShell 5.1 und finden ihre Daten über `$PSScriptRoot` — der Ordner darf also
verschoben werden. Reihenfolge:

```powershell
.\1-fetch-items.ps1     # Item-Pool + Werte von Wowhead      -> daten/items.json
.\2-fetch-gear.ps1      # getragene Ausrüstung vom Armory    -> daten/players.json
.\3-compute.ps1         # die eigentliche Rechnung           -> daten/upgrades.json
.\4-bis-check.ps1       # Gegenprobe gegen BiS-Listen        -> daten/bis-listen.json
.\5-build-payload.ps1   # Seite bauen                        -> ausgabe/loot-prio-p3.html
```

**Nur das Gear aktualisieren** (der häufigste Fall, nach jedem Raid):

```powershell
.\2-fetch-gear.ps1; .\3-compute.ps1; .\5-build-payload.ps1
```

`2-fetch-gear.ps1` meldet dabei jeden Slotwechsel seit dem letzten Abruf. Alle Skripte nutzen
`daten/cache-tooltips.json`, Wiederholungsläufe sind daher schnell.

Es wird **kein Python und kein Node** gebraucht — auf dem Zielrechner ist beides nicht installiert.

---

## Ordner

| Pfad | Inhalt |
|---|---|
| `*.ps1` | die fünf Skripte der Kette |
| `roster.json` | **von Hand gepflegt**: Spieler und ihre Spec |
| `tier-boni.json` | **von Hand gepflegt**: Set-Boni T5/T6 mit DPS-Einschätzung |
| `vorlage.html` | Seitengerüst; `"__DATEN__"` wird beim Bau durch die JSON-Nutzlast ersetzt |
| `daten/` | Zwischenstände und Tooltip-Cache (alles regenerierbar) |
| `ausgabe/` | die fertige Seite |
| `quellen/` | Rechercheunterlagen aus dem Aufbau: Item-Pool, Statgewichte, Alternativen, Gear-Stand |

Wer Spieler hinzufügt oder eine Spec ändert, bearbeitet **nur `roster.json`**.

---

## Datenquellen und Abruf-Rezepte

### Ausrüstung — classic-armory.org

```
POST https://classic-armory.org/api/v1/character/equipment
{"region":"eu","realm":"thunderstrike","name":"<Name>","flavor":"tbc-anniversary"}
```

Das Feld heißt **`flavor`**, nicht `version` — mit `version` antwortet die API `{"equipment":null}` bei
Status 200 statt mit einem Fehler.

⚠️ **Umlaut-Falle:** Die API braucht echte UTF-8-Bytes, sonst findet sie „Järgerlie" nicht — lehnt aber
ein `charset=utf-8` im Content-Type mit **HTTP 400** ab. `Invoke-RestMethod` mit String-Body scheitert
daran still. Lösung in `2-fetch-gear.ps1`: `ByteArrayContent` mit von Hand gesetztem, nacktem
`application/json`-Header.

### Item-Werte — Wowhead

```
GET https://nether.wowhead.com/tbc/tooltip/item/<ID>?locale=0
```

Liefert JSON mit `name` und `tooltip` (HTML), inklusive Phasenmarkierung. CORS ist erlaubt.

⚠️ **Die Zonen-Listview von Wowhead ist unvollständig** — bei Black Temple fehlte Teron Blutschatten
mit 12 Items komplett. Immer pro Boss-NPC über `/tbc/npc=<id>` ziehen, nicht über die Zonenseite.
Beim Parsen: der Schlüssel heißt `data: [` **mit Leerzeichen**.

### Statgewichte — WoWSims

`wowsims.com/tbc/<klasse>/<spec>/` → Knopf „Stat Weights" → „Calculate".
⚠️ `wowsims.github.io/tbc/` ist die **veraltete, nicht mehr gepflegte** Fassung.

Die Spalte **„DPS Weight" ist der absolute DPS-Gewinn pro Statpunkt** — genau das, was das Modell
braucht. „DPS EP" daneben ist nur derselbe Wert geteilt durch einen Referenzstat und damit zwischen
Specs **nicht** vergleichbar. Die Gewichte sind in `3-compute.ps1` fest hinterlegt (Stand 27.07.2026);
sie ändern sich nur, wenn sich das Gearniveau des Raids deutlich verschiebt.

---

## ⚠️ Fallen, die schon einmal Ergebnisse verdorben haben

**1. Prokk-Texte werden als feste Werte gelesen.** WoW-Tooltips formulieren Prokks wie Dauereffekte:
Dragonstrikes *„Chance on hit: Increases your haste rating by 212"* wurde als **dauerhafte**
Tempowertung gezählt und schenkte der Waffe rund 210 DPS Phantomwert — was die gesamte
Warglaive-Bewertung verdrehte. Bloodlust Broochs *„Use: +278 Angriffskraft"* genauso.
Lösung: Tooltip vor der Wertelesung abschneiden bei `Chance on hit`, `Use:`, `(2) Set`, `(4) Set`,
`have a chance`, `chance to`.
**Nicht** bei `Equip: Your` schneiden — dauerhafte Effekte wie *„Your attacks ignore 335 armor"*
beginnen genauso und gehen sonst verloren. (Das war die erste, zu grobe Korrektur.)

**2. Cap-Artefakte bei Treffer und Waffenkunde.** In den Sim-Presets sind die Charaktere meist schon
am Cap, deshalb kommen diese Stats dort mit **0,00** heraus. Das ist kein Ergebnis, sondern ein
Artefakt. Übernimmt man es blind, werden treffer-lastige Items massiv unterbewertet.

**3. Sonderzeichen in `.ps1`-Dateien.** PowerShell 5.1 liest Skripte als ANSI — Umlaute und Zeichen wie
`·` werden zu Kauderwelsch. Solche Texte gehören in eine UTF-8-JSON-Datei (`roster.json`,
`tier-boni.json`), die mit `-Encoding UTF8` gelesen wird. Deshalb steht der Spielername „Järgerlie"
in `roster.json` und nicht im Skript.

**4. Fähigkeitsnamen nicht selbst übersetzen.** Aus *Arcane Blast* wurde fälschlich „Arkane Explosion"
(richtig: Arkanschlag), aus *Mutilate* „Blutsturz" (richtig: Verstümmeln). In `tier-boni.json` stehen
die Namen deshalb bewusst **englisch wie in der Quelle**.

**5. Schilde erscheinen als Schildhand-Items.** Im Tooltip steht bei Schilden „Off Hand" als Slot und
„Shield" als Rüstungsart. Ohne Prüfung der Rüstungsart bekommen Magier und Druiden Schilde vorgeschlagen.

---

## Was das Modell kann — und was nicht

Gerechnet wird `ΔDPS = Wert(neues Item) − Wert(getragenes Teil im selben Slot)`, beides mit den
Statgewichten der jeweiligen Spec. Sockel werden auf beiden Seiten mit einem Standardstein bewertet
(8 Stärke/Beweglichkeit bzw. 12 Zauberschaden), Verzauberungen auf keiner Seite, weil sie beim
Wechsel mitgehen.

Sonderfälle, die abgebildet sind: Ringe und Schmuck gegen das **schlechtere** der beiden getragenen
Teile · Zweihandwaffen gegen Waffenhand **plus** Schildhand · wer eine Zweihandwaffe führt, bekommt
keine Schildhand-Items · Waffenkenntnisse je Klasse · Rüstungsklasse und niedrigere · Distanzslot
zählt Waffenschaden nur bei Jägern · Warglaives zusätzlich als **Paar-Zeile** samt 2er-Bonus · **BiS-Priorisierung**: Items, die für eine Spec Best-in-Slot (#1) sind, werden vor bloßen Upgrades für andere Spieler einsortiert — inklusive Exklusivitäts-Badges (★ BiS für 1 bzw. 2 Spieler).

**Nicht abgebildet:**

- **Schmuckstücke.** Ihr Wert steckt fast ganz in Prokks und Nutzeneffekten. Die Zeilen sind als
  `NichtBewertbar` markiert und werden auf der Seite ausgeblendet.
- **Tier-Set-Boni als Zahl.** Prozentboni auf einzelne Fähigkeiten (*„+5 % auf Bloodthirst"*) lassen
  sich ohne Simulation nicht in DPS umrechnen. Stattdessen steht unter jeder Tier-Zeile, was der
  Wechsel mit den Boni macht: Teilezahl vorher/nachher, welcher Bonus wegfällt, welcher anspringt,
  welcher erhalten bleibt — je mit Einschätzung `hoch/mittel/gering/keiner` aus `tier-boni.json`.
- **Waffengeschwindigkeit**, außer als Ausschluss: Waffenhand-Kandidaten unter 2,4 s sind für
  Verstärkung und Kampf-Schurke aussortiert. Feiner rechnet das Modell nicht — deshalb steht der
  Schaden pro Schlag als Zusatzangabe in der Tabelle.
- **Spezifische Spec-Mechaniken** wie Kampfgewandtheit des Schurken (die eine *schnelle* Schildhand
  belohnt). Deshalb ist der Vorsprung der Krieger bei den Warglaives vermutlich überzeichnet.

## Verlässlichkeit

`4-bis-check.ps1` stellt die beste Empfehlung je Slot und Spec gegen die veröffentlichten
Phase-3-BiS-Listen von warcrafttavern.com. Stand 28.07.2026:

**136 Empfehlungen · 57 % auf BiS-Platz 1 · 88 % in den BiS-Top-3 · 9 nicht gelistet.**

Die meisten Nichttreffer sind Marken- und Trash-Items, die die BiS-Listen gar nicht berücksichtigen.
Das Skript nach jeder Modelländerung erneut laufen lassen — es ist der beste vorhandene Regressionstest.

---

## Offene Punkte

1. **Knappheitsspalten fehlen.** Die Daten dafür liegen in `quellen/p3-alternativen-*.md` vollständig
   vor (Marken-Sortiment, T6-Teile, Handwerk, Trash), ausgewertet ist es noch nicht. Ziel wären zwei
   Spalten: „wie viele gleichwertige Alternativen hat diese Spec im Slot" und „ab welchem Boss".
2. **Markenhändler im Spiel gegenprüfen**, sobald Phase 3 live ist. Wowheads Phasenzuordnung ist
   widersprüchlich (gleiche Item-Reihe teils Phase 3, teils Phase 4). Sind die ilvl-141-Plattenteile
   kaufbar, entfällt für Brust, Beine und Gürtel der Plattenträger die Knappheitsbegründung.
3. **Schmuckstücke** ließen sich über gezielte Simulationsläufe nachziehen.
4. **Tanks und Heiler** sind bewusst nicht enthalten — bisher nur die 13 DPS-Specs.
