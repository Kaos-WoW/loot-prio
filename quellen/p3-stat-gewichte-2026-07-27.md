# Stat-Gewichte der 13 DPS-Specs (Schritt 3, Teil 1) — Stand 2026-07-27

Quelle: **WoWSims TBC**, gepflegte Fassung auf `wowsims.com/tbc/<klasse>/<spec>/`.
⚠️ Die ältere Fassung auf `wowsims.github.io/tbc/` weist selbst darauf hin, dass sie **nicht mehr gepflegt**
wird — nicht verwenden.

## Abruf-Rezept

Auf der Spec-Seite den Knopf „Stat Weights" klicken, dann im Dialog über die Preset-Chips
(`.saved-data-set-chip`) iterieren und je Zeile den Nicht-Checkbox-`input` auslesen. Ein echter
Neuberechnungslauf („Calculate") dauert ~5 Minuten pro Spec (23 Simulationen, 287.500 Iterationen) — die
hinterlegten Presets sind dieselben Werte, die der Simulator selbst zum Sortieren der Items benutzt.

Simulator-URLs: `warrior/dps`, `paladin/retribution`, `rogue/dps`, `hunter/dps`, `mage/dps`, `warlock/dps`,
`priest/dps`, `shaman/elemental`, `shaman/enhancement`, `druid/balance`.

## ⚠️ Drei Einschränkungen, die vor der Rechnung gelöst werden müssen

**1. Uneinheitliche Normierung.** Jeder Sim normiert auf einen anderen Referenzwert: Krieger und Vergeltung
auf Stärke = 1,00, Schurke und Verstärkung auf Angriffskraft = 1,00, Jäger auf Beweglichkeit = 1,00, alle
Caster auf Zauberschaden = 1,00. **Die Zahlen sind zwischen Specs nicht direkt vergleichbar** — sie müssen
erst auf eine gemeinsame Basis und dann über den Basis-DPS in absolute DPS umgerechnet werden.

**2. Trefferwertung ist in mehreren Presets ein Cap-Artefakt.** Beim Jäger steht Trefferwertung bei 0,12 —
das heißt nur, dass die Preset-Ausrüstung bereits am Cap ist, nicht dass Treffer wertlos wäre. Für Spieler
unter dem Cap ist der Wert um ein Vielfaches höher. Treffer muss deshalb **pro Spieler aus dem echten Gear**
gerechnet werden, nicht aus dem Preset übernommen. Gleiches gilt abgeschwächt für Waffenkunde.

**3. Ungleiche Phasenabdeckung.** Phase-3-Presets existieren nur für Waffen-Krieger, Verstärkung (als „WiP"),
Schattenpriester und Gleichgewicht. Furor hat ein gemeinsames P2–P5-Preset. Vergeltung, Schurke, Jäger,
Hexer und Elementar haben nur P1/P2 bzw. gar keine Phasenangabe. Bei denen rechne ich mit dem neuesten
verfügbaren Stand und markiere das im Ergebnis.

Auffälligkeit zum Nachprüfen: Gleichgewicht hat in „Phase 3" ein Zaubertempo von **0,53**, in „Phase 3.5"
aber **1,09** — der Einbruch wirkt wie ein Artefakt und nicht wie echtes Verhalten. Vor der Endrechnung klären.

---

# Nahkampf (physisch)

## Furor-Krieger — Preset „P2, P3, P4 & P5 - Fury" (Stärke = 1,00)
Stärke 1,00 | Bew 0,75 | AP 0,45 | **Treffer 1,50** | Krit 0,90 | Tempo 0,86 | ArP 0,20 | **Waffk 1,31** | Waffen-DPS Waffenhand 2,80 | Schildhand 1,50

## Waffen-Krieger — Preset „P3, P4 & P5 - Arms" (Stärke = 1,00)
Stärke 1,00 | Bew 0,80 | AP 0,45 | Treffer 1,01 | **Krit 1,05** | Tempo 0,85 | ArP 0,23 | **Waffk 1,78** | **Waffen-DPS 6,00**

## Vergeltungs-Paladin — ECHTE NEUBERECHNUNG auf P2-Gear (Stärke = 1,00)
Stand 2026-07-27, 23 Sims / volle Iterationen, Standardfehler in Klammern:
Stärke 1,00 | Bew 0,76 (±0,02) | Zauberschaden 0,17 | AP 0,42 | **Treffer 0,00** | Krit 0,78 (±0,02) |
Tempo 1,22 (±0,12) | ArP 0,10 | Waffk 2,04 (±0,13) | Waffen-DPS Waffenhand 5,39 | Schildhand 0,00

⚠️ **Treffer = 0,00 ist ein Cap-Artefakt, kein Ergebnis.** Die P2-Sim-Ausrüstung liegt bei 9,80 % Trefferchance
und damit über dem 9-%-Cap. Treffer darf deshalb **nie** als fester Gewichtswert in die Rechnung — pro Spieler
aus dem echten Gear als Stufenfunktion behandeln (unter Cap hoch, über Cap null).

**Validierung:** Alle übrigen Werte decken sich bis auf wenige Prozent mit dem hinterlegten Preset. Die
Preset-Methode ist damit für die anderen Specs als tragfähig bestätigt.

**Rauschen:** Tempo ±0,12 und Waffenkunde ±0,13 sind relevant. Abstände unter ~5 % zwischen zwei Specs
sind nicht signifikant und müssen in der Endliste als Gleichstand ausgewiesen werden.

## Vergeltungs-Paladin — hinterlegtes Preset „P2" (Stärke = 1,00), zum Vergleich
Stärke 1,00 | Bew 0,75 | Zauberschaden 0,17 | AP 0,41 | **Treffer 2,15** | Krit 0,77 | Tempo 1,17 | ArP 0,10 | **Waffk 2,14** | **Waffen-DPS 5,34**
(P1 zum Vergleich: Treffer 2,19, Tempo 1,30, Waffk 2,18, Waffen-DPS 5,88)

## Verstärkungs-Schamane — Preset „P3 (WiP)" (Angriffskraft = 1,00)
Stärke 2,20 | Bew 1,69 | Int 0,10 | Zauberschaden 0,48 | Natur-ZS 0,35 | AP 1,00 | **Treffer 1,91** | Krit 1,74 | **Tempo 1,94** | ArP 0,33 | **Waffk 2,73** | Waffen-DPS 8,25 / 3,61
(Default-Preset zum Vergleich: Tempo nur 1,37, Waffk 3,10 — Tempo steigt in P3 deutlich)

## Kampf-Schurke — Preset „Combat Swords" (Angriffskraft = 1,00)
Stärke 1,10 | **Bew 2,17** | AP 1,00 | **Treffer 3,06** | Krit 1,70 | **Tempo 2,19** | ArP 0,30 | **Waffk 3,47** | Bonus-Waffenschaden 8,47 | Waffen-DPS 9,34 / 3,40

# Distanz (physisch)

## Tierherrschafts- und Überlebens-Jäger — Preset „P1 BM" / „P1 SV" (Beweglichkeit = 1,00)
Beide Presets sind **identisch**: Stärke 0,06 | Bew 1,00 | Int 0,01 | AP 0,06 | **Fernkampf-AP 0,40** | Treffer 0,12 (Cap-Artefakt!) | Krit 0,92 | Tempo 0,79 | ArP 0,16 | Fernkampf-DPS 1,75

# Caster

## Arkan-Magier — Preset „P2 - Arcane" (Zauberschaden = 1,00)
Int 1,31 | ZS 1,00 | Arkan-ZS 0,90 | **Z-Treffer 2,30** | Z-Krit 0,77 | Z-Tempo 0,55 | Willenskraft 0,90 | mp5 0,48

## Gebrechens- und Zerstörungs-Hexer — Preset „P1 - Affli / Demo / Destro" (Zauberschaden = 1,00)
Int 0,38 | ZS 1,00 | Schatten-ZS 0,92 | **Z-Treffer 1,73** | Z-Krit 0,82 | **Z-Tempo 1,21** | mp5 0,29
(Es gibt zusätzlich „P1 - Destro (Fire)" mit Feuer-ZS 0,92 statt Schatten — nur relevant, falls jemand auf Feuer-Destro spielt. Bei eurer Aufstellung greift das Schatten-Preset.)

## Schattenpriester — Preset „P3" (Zauberschaden = 1,00)
Int 0,06 | ZS 1,00 | Schatten-ZS 1,00 | **Z-Treffer 1,35** | Z-Krit 0,19 | Z-Tempo 0,88 | Willenskraft 0,11 | mp5 0,01
(P1 zum Vergleich: Z-Treffer 1,18, Z-Tempo 0,69 — beide steigen in P3)

## Elementar-Schamane — Preset „Default" (Zauberschaden = 1,00)
Int 0,25 | ZS 1,00 | Natur-ZS 1,00 | **Z-Treffer 2,12** | Z-Krit 0,85 | Z-Tempo 1,18

## Gleichgewichts-Druide — Preset „Phase 3" (Zauberschaden = 1,00)
Int 0,57 | ZS 1,00 | Arkan-ZS 1,00 | **Z-Treffer 1,91** | Z-Krit 0,73 | Z-Tempo 0,53 (siehe Auffälligkeit oben) | Willenskraft 0,11 | mp5 0,02

---

## Querbefund: Waffenkunde bestätigt die SSC-Teile endgültig

Waffenkunde ist bei jeder Nahkampf-Spec eines der höchstgewichteten Statistiken — Schurke 3,47,
Verstärkung 2,73, Vergeltung 2,14, Waffen 1,78, Furor 1,31 (jeweils in der Normierung der Spec).
Da **kein einziges DPS-Item in Hyjal oder BT Waffenkunde trägt**, bleiben Gürtel der hundert Tode und
Schulterpolster des Fremden zwangsläufig BiS. Die Annahme des Nutzers ist damit von zwei unabhängigen
Seiten bestätigt.

---

# ★ ABSOLUTE DPS-GEWICHTE (echte Neuberechnung, 2026-07-27)

**Durchbruch:** Die Spalte **„DPS Weight"** im Simulator ist der **absolute DPS-Gewinn pro Statpunkt**.
Die Spalte „DPS EP" daneben ist nur derselbe Wert geteilt durch den Referenzstat. Verifiziert an zwei
Specs: Vergeltung Stärke 0,83 / 0,83 = EP 1,00 ✓, Beweglichkeit 0,63 / 0,83 = EP 0,76 ✓.

**Damit entfällt der Umweg über Basis-DPS und Normierung komplett.** Der absolute DPS-Zuwachs eines Items
ist schlicht `ΔDPS = Σ (Statwert × DPS-Weight)` — und diese Zahlen sind zwischen Specs direkt vergleichbar,
weil sie alle in derselben Einheit stehen: DPS pro Punkt.

Werte in DPS pro Statpunkt, Standardfehler in Klammern:

| Stat | Vergeltung | Kampf-Schurke | Jäger | Hexer | Elementar |
|---|---|---|---|---|---|
| Stärke | 0,83 | 0,42 | 0,12 | — | — |
| Beweglichkeit | 0,63 | 0,85 (0,01) | 1,14 (0,01) | — | — |
| Intelligenz | — | — | 0,01 | 0,33 (0,05) | 0,18 (0,01) |
| Angriffskraft | 0,34 | 0,38 | 0,11 | — | — |
| Fernkampf-AP | — | — | 0,40 | — | — |
| Zauberschaden | 0,14 | — | — | 1,05 (0,02) | 0,72 |
| Schatten-/Natur-ZS | — | — | — | 0,98 (0,02) | 0,72 |
| **Treffer** | **0,00** | **0,00** | **0,00** | **0,00** | 0,06 (0,01) |
| Krit | 0,65 | 0,68 (0,01) | 0,96 (0,02) | 0,81 (0,02) | 0,61 (0,02) |
| **Tempo** | 1,01 | 0,79 (0,04) | 0,87 (0,07) | **1,33 (0,06)** | **1,25 (0,03)** |
| Rüstungsdurchschlag | 0,08 | 0,12 | 0,16 | — | — |
| Waffenkunde | 1,69 (0,10) | 1,13 (0,05) | 0,42 (0,03) | — | — |
| mp5 | — | — | 0,01 | 0,28 (0,05) | 0,01 |
| Bonus-Waffenschaden | — | 3,27 | 1,79 | — | — |
| Waffen-DPS Waffenhand | 4,44 | 3,58 | — | — | — |
| Waffen-DPS Schildhand | 0,00 | 1,33 | — | — | — |
| **Fernkampf-DPS** | — | — | **4,09** | — | — |

## Was die Neuberechnung gegenüber den Presets verändert hat

**1. Treffer ist bei vier von fünf Specs exakt 0,00.** Sämtliche Sim-Ausrüstungen liegen über dem Cap
(Schurke z. B. bei 28,04 % gegen einen Dual-Wield-Weißschlag-Cap von 27 %). Die Preset-Werte von 2,15
(Vergeltung), 3,06 (Schurke) und 1,73 (Hexer) waren also **reine Cap-Artefakte** und hätten die Liste
massiv verzerrt. Treffer muss pro Spieler aus dessen echtem Gear als Stufenfunktion gerechnet werden.

**2. Fernkampf-Waffen sind für Jäger doppelt so wertvoll wie das Preset sagte** — EP 3,58 statt 1,75.
Das ist der größte inhaltliche Unterschied und betrifft Järgerlie und Kroenix direkt, weil beide noch mit
Phase-2-Bögen laufen und es in Phase 3 drei Distanzwaffen gibt.

**3. Zaubertempo beim Elementar-Schamanen springt von 1,18 auf 1,73** (+47 %). Tempo-Items sind für
Exotica deutlich wertvoller als angenommen.

**4. Waffenkunde beim Schurken fällt von 3,47 auf 2,94** — das Sim-Gear liegt mit 4,50 % näher am
6,5-%-Cap. Immer noch der höchstgewichtete Sekundärstat des Schurken.

Fazit: die Neuberechnung war notwendig. Ohne sie wäre die Endliste bei Treffer-lastigen Items und bei
Jäger-Distanzwaffen deutlich falsch geworden.

## Zweite Runde — Nahkampf, DPS pro Statpunkt

| Stat | Furor-Krieger | Verstärkung |
|---|---|---|
| Stärke | 1,09 (0,08) | 0,89 |
| Beweglichkeit | 0,79 (0,05) | 0,65 (0,02) |
| Intelligenz | — | 0,05 |
| Angriffskraft | 0,49 (0,06) | 0,40 |
| Zauberschaden | — | 0,24 (Natur 0,18) |
| **Trefferwertung** | **0,58 (0,09)** | **0,73 (0,05)** |
| Zaubertreffer | — | 0,23 |
| Krit | 1,07 (0,06) | 0,68 (0,02) |
| Zauberkrit | — | 0,05 |
| Tempo | 0,97 (0,11) | 0,65 (0,07) |
| Rüstungsdurchschlag | 0,19 | 0,12 |
| Waffenkunde | 1,42 (0,12) | 1,35 (0,06) |
| Waffen-DPS Waffenhand | 3,08 (0,15) | 3,28 |
| Waffen-DPS Schildhand | 1,58 (0,18) | 1,47 |

Bemerkenswert: Furor und Verstärkung sind die **einzigen Nahkämpfer mit einem Treffer-Gewicht über null**
(0,58 bzw. 0,73). Grund ist der Dual-Wield-Weißschlag-Cap von ~27 %, den beide im Sim-Gear noch nicht
erreichen — im Gegensatz zum Schurken, der mit 28,04 % darüber liegt.

## Zweite Runde — Caster, DPS pro Statpunkt

| Stat | Hexer | Arkan-Magier | Gleichgewicht | Elementar | Schattenpriester |
|---|---|---|---|---|---|
| **Zauberschaden (allgemein)** | **1,05 (0,02)** | 0,79 | 0,78 | 0,72 | 0,59 |
| Schulspezifischer ZS | 0,98 Schatten | 0,74 Arkan | 0,78 Arkan | 0,72 Natur | 0,59 Schatten |
| Intelligenz | 0,33 (0,05) | **1,14 (0,03)** | 0,44 (0,01) | 0,18 (0,01) | 0,03 |
| Willenskraft | — | 0,78 (0,03) | 0,09 | — | 0,06 |
| Zaubertreffer | 0,00 | 0,16 (0,01) | 0,04 (0,01) | 0,06 (0,01) | 0,00 |
| Zauberkrit | 0,81 (0,02) | 0,64 (0,02) | 0,53 (0,01) | 0,61 (0,02) | 0,11 |
| Zaubertempo | 1,33 (0,06) | **0,16 (0,03)** | 1,01 (0,04) | 1,25 (0,03) | 0,68 (0,02) |
| mp5 | 0,28 (0,05) | 0,42 (0,02) | 0,00 | 0,01 | 0,00 |

**Der Arkan-Magier fällt aus der Reihe:** Intelligenz (1,14) schlägt Zauberschaden (0,79), Willenskraft
liegt bei 0,78, Zaubertempo dagegen nur bei 0,16. Das ist kein Fehler — Arkan ist in TBC durch Mana
begrenzt, nicht durch Zauberzeit. Für Sinrakss, Lupitus und Lariesel heißt das: Items mit Intelligenz und
Willenskraft schlagen reine Zauberschaden-Items, und Tempo ist für sie praktisch wertlos. Genau umgekehrt
zu Hexer und Elementar, wo Tempo mit 1,33 bzw. 1,25 zu den stärksten Stats gehört.

**Auffälligkeit von vorhin geklärt:** Das Zaubertempo-Gewicht von 0,53 im „Phase 3"-Preset des
Gleichgewichts-Druiden war tatsächlich ein Artefakt. Die Neuberechnung liefert 1,01.

## Furor-Krieger: VIER unabhängige Läufe, gemittelt (maßgeblich)

Alle vier Krieger-Läufe liefen mit Dual-Wield-Gear, waren also Furor. Ergebnis sind vier unabhängige
Messungen derselben Konfiguration.

**Maßgebliche Furor-Gewichte:** Stärke 1,14 | Bew 0,80 | AP 0,51 | Treffer 0,60 | Krit 1,07 |
Tempo 0,99 | ArP 0,19 | Waffenkunde 1,29 | Waffen-DPS Waffenhand 3,12 | Schildhand 1,64

Einzelläufe (Str / Treffer / Waffk / MH-DPS):
A 1,09 / 0,58 / 1,42 / 3,08 — B 1,20 / 0,76 / 1,49 / 3,15 — C 1,15 / 0,50 / 1,19 / 3,12 — D 1,11 / 0,55 / 1,07 / 3,12

⚠️ **Die simulatoreigenen Standardfehler sind zu optimistisch.** Waffenkunde streute über die vier Läufe
von 1,07 bis 1,49, während der Simulator ±0,12 je Einzellauf meldet. Aus den Wiederholungen gerechnet:
Waffenkunde **1,29 ± 0,10**, Treffer **0,60 ± 0,06**. Für alle Specs gilt daher: Unterschiede unter etwa
10 % bei den verrauschten Stats (Waffenkunde, Treffer, Tempo) sind nicht signifikant.

## Waffen-Krieger — gültiger Lauf (Twinblade of the Phoenix, Schildhand leer)

Gültigkeitsprüfung bestanden: Schildhand-Gewicht 0,00.

Stärke 0,56 (0,06) | Bew 0,44 (0,03) | AP 0,24 (0,04) | Treffer 0,18 (0,03) | Krit 0,61 (0,03) |
Tempo 0,64 (0,08) | ArP 0,12 | **Waffenkunde 0,00** | Waffen-DPS Waffenhand **3,23 (0,14)** | Schildhand 0,00

⚠️ **Waffenkunde 0,00 ist wieder ein Cap-Artefakt.** Das Arms-BiS-Set enthält Gürtel der hundert Tode (25)
*und* Schulterpolster des Fremden (10) und liegt damit am 6,5-%-Cap. Moriamus hat nur den Gürtel — für ihn
ist Waffenkunde weiterhin wertvoll und muss aus seinem echten Gear gerechnet werden.

## Basis-DPS-Gegenprobe Krieger (Simulate-Lauf)

| Spec | Gesamt-DPS | Verhältnis |
|---|---|---|
| Furor | 2.364,99 (σ 106) | 100 % |
| Waffen | 1.536,32 (σ 87) | **65 %** |

Der Abstand ist **real und kein Gear-Artefakt**, fällt aber milder aus als die rohen Gewichte (≈50 % der
Furor-Werte) nahelegen. Erklärung: Waffen zieht anteilig weniger Schaden aus AP-Skalierung und mehr aus dem
Waffenschaden. Deshalb liegt das **Waffen-DPS-Gewicht mit 3,23 sogar über dem Furor-Wert von 3,12** — und
weil Zweihandwaffen viel mehr Waffen-DPS tragen, ist ein Waffenupgrade für Moriamus der größte Einzelhebel
im Raid, während er bei Rüstungsteilen nur etwa halb so viel gewinnt wie Grotschak.

## ⚠️ Offene Einschränkung: Buff-Annahmen nicht spec-übergreifend geprüft

Absolute DPS-Gewichte sind nur dann zwischen Specs vergleichbar, wenn alle Simulatoren dieselben Raidbuffs
annehmen. Verwendet wurden durchweg die Standardeinstellungen, aber das wurde **nicht Spec für Spec
verifiziert**. Abweichende Voreinstellungen würden Vergleiche um einige Prozent verschieben. Bei der
Rechnung stichprobenartig gegenprüfen und im Ergebnis vermerken.

## Stand: Schritt 3 ABGESCHLOSSEN

Absolute DPS-Gewichte liegen für **alle 13 Specs** vor. Die separate Basis-DPS-Runde entfällt, weil
„DPS Weight" bereits absolut ist. Basis-DPS bisher nur für Krieger bekannt (Furor 2.365 / Waffen 1.536);
für die optionale Prozentspalte wäre je ein Simulate-Klick pro Spec nötig, für die Leitmetrik aber nicht.
