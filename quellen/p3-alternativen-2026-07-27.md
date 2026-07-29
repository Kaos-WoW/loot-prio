# Alternativ-Inventar (Schritt 4) — Stand 2026-07-27

Zweck: Grundlage für die Knappheitsspalten. Ein Raid-Item ist nur dann knapp, wenn es für die Spec keine
gleichwertige Alternative aus Marken, Tier-Token, Handwerk oder BoE gibt.

Abruf: Wowhead-Itemseite → Listview `id: 'currency-for'` (Tauschliste einer Währung/eines Tokens).
Phasenzuordnung über den Tooltip-Endpunkt, der eine „Phase N"-Markierung mitliefert.

---

## 1. Markenhändler (Abzeichen der Gerechtigkeit)

245 Einträge insgesamt, davon 237 Rüstung/Waffen. Phasenverteilung laut Wowhead:

| Phase | Anzahl |
|---|---|
| Phase 1 | 58 |
| Phase 2 | 45 |
| **Phase 3** | **28** |
| Phase 4 (Zul'Aman) | 57 |
| Phase 5 (Sunwell) | 47 |
| ohne Angabe | 2 |

In Phase 3 verfügbar sind also Phase 1 + 2 + 3 = **131 Items**, nicht die vollen 245.

### ⚠️ Die Phasenzuordnung der Quelle ist widersprüchlich

Items derselben ID-Reihe und Gegenstandsstufe werden unterschiedlich einsortiert:
`33222 Nyn'jah's Tabi Boots` (ilvl 128) = **Phase 3**, aber `33501 Bloodthirster's Wargreaves` (ilvl 128)
= **Phase 4**. Beide gehören zum Zul'Aman-Markensortiment. Ebenso ist `34944 Girdle of Seething Rage`
(ilvl 141) als Phase 3 markiert, während `34891` derselben Reihe Phase 5 ist.

**Das muss im Spiel gegengeprüft werden**, sobald Phase 3 live ist. Es ist entscheidungsrelevant: Wenn die
ilvl-141-Platten-Teile per Marken kaufbar sind, sind Brust, Beine und Gürtel für Grotschak, Valiror,
Moriamus und Kaosx **kein knappes Gut mehr** — sie können sie sich schlicht erfarmen. Das würde die
Knappheitsspalte für diese Slots komplett umwerfen.

### Phase-3-Marken-Items mit DPS-Relevanz

**Platte (Krieger, Vergeltung):**
- 34942 Breastplate of Ire i141 — Str52 Sta64+3 **Tempo51**
- 34943 Legplates of Unending Fury i141 — Str52 Sta48+3 Treffer25 **Tempo43**
- 34944 Girdle of Seething Rage i141 — Str40 Sta55+2 Tempo30

**Leder (Schurke):**
- 33538 Shallow-grave Trousers i128 — Agi45 Sta46 Tempo30 AP92
- 33539 Trickster's Stickyfingers i128 — Agi30 Sta28 Tempo25 AP68
- 33222 Nyn'jah's Tabi Boots i128 — Agi29 Sta21 Treffer22 AP60
- 33540 Master Assassin Wristwraps i128 — Agi17 Sta22 Krit18 AP50

**Leder Caster (Gleichgewicht):**
- 33566 Blessed Elunite Coverings i128 — Sta33 Int34 Z-Krit22 SP54 mp5:7
- 33559 Starfire Waistband i128 — Sta20 Int23 Z-Krit22 SP40 mp5:6
- 33577 Moon-walkers i128 — Sta30 Int28 Z-Treffer20 SP34

Aus Phase 1 und 2 relevant bleiben praktisch nur die Schmuckstücke (Icon of the Silver Crescent 29370,
Bloodlust Brooch 29383, Essence of the Martyr 29376) — die trägt euer Raid ohnehin schon.

---

## 2. Tier 6 — Teile je Spec

Tokens: Kopf (Archimonde), Hände (Azgalor), Schultern (Mutter Shahraz), Brust (Illidan),
Beine (Illidari-Rat). Token-Gruppen: **Conqueror** = Paladin/Priester/Hexer, **Vanquisher** =
Schurke/Magier/Druide, **Protector** = Krieger/Jäger/Schamane.

| Spec | Set | Kopf | Schulter | Brust | Hände | Beine |
|---|---|---|---|---|---|---|
| Furor / Waffen | Onslaught | 30972 | 30979 | 30975 | 30969 | 30977 |
| Vergeltung | Lightbringer | 30989 | 30997 | 30990 | 30982 | 30993 |
| Jäger | Gronnstalker | 31003 | 31006 | 31004 | 31001 | 31005 |
| Kampf-Schurke | Slayer | 31027 | 31030 | 31028 | 31026 | 31029 |
| Verstärkung | Skyshatter (Nahkampf) | 31015 | 31024 | 31018 | 31011 | 31021 |
| Elementar | Skyshatter (Caster) | 31014 | 31023 | 31017 | 31008 | 31020 |
| Hexer | Malefic | 31051 | 31054 | 31052 | 31050 | 31053 |
| Arkan-Magier | Tempest | 31056 | 31059 | 31057 | 31055 | 31058 |
| Schattenpriester | Absolution | 31064 | 31070 | 31065 | 31061 | 31067 |
| Gleichgewicht | Thunderheart (Caster) | 31040 | 31049 | 31043 | 31035 | 31046 |

Werte (Auswahl der DPS-Sets):
- Onslaught: Helm Str54 Agi41 Sta54+4 · Brust Str53 Agi34 Sta54 Tref16 · Beine Str62 Agi41 Sta55+2 Tref14 · Hände Str41 Agi30 Sta49 · Schulter Str39 Agi39 Sta34
- Lightbringer: Helm Str61 Sta60 Int32 Krit23 · Brust Str56 Sta48 Int31 Tref21 Krit31 · Beine Str68 Sta48 Int22 Krit38 · Hände Str51 Sta37 Int25 Krit19 · Schulter Str50 Sta37 Int17 Krit19
- Slayer: Helm Agi45 Sta55 Tref15 Krit28 AP92 · Brust identisch · Beine Agi46 Sta54 Krit45 AP94 · Hände Agi34 Sta36 Tref18 AP68 · Schulter Agi34 Sta37 AP68
- Gronnstalker: Helm Agi45 Sta45 Int29 AP90 · Brust Agi40 Sta52 Int37+4 Krit19 AP90 · Beine Agi37 Sta43 Int28+2 Krit19 AP106 · Hände Agi35 Sta31 Int21 Krit13 AP62 · Schulter Agi34 Sta39 Int17 AP68
- Malefic: Hood Sta55 Int36 Z-Tref16 Z-Krit32 SP63 · Robe Sta66 Int29 Z-Tref28 SP63 · Beine Sta55 Int44 Z-Tref19 Z-Krit37 SP62 · Hände Sta57 Int27 Z-Tref11 Z-Krit19 SP46 · Schulter Sta45 Int22 Z-Tref21 Z-Krit13 SP46
- Tempest: Cowl Sta30 Int40 Spi28+6 Z-Tref13 Z-Krit29 SP62 · Robe Sta36 Int39 Spi31 Z-Tref13 Z-Krit23 SP62 · Beine Sta36 Int47 Spi29 Z-Tref20 Z-Krit29 SP62 · Hände Sta30 Int26 Spi21 Z-Tref20 Z-Krit19 SP46 · Schulter Sta27 Int27 Spi21 Z-Krit21 SP46

---

## 3. ★ T6-Set-Boni — und warum sie sehr ungleich wertvoll sind

| Set | 2er-Bonus | 4er-Bonus |
|---|---|---|
| Onslaught (Krieger) | Hinrichten kostet 3 Wut weniger | **+5 % Schaden auf Tödlicher Stoß und Blutdurst** |
| Lightbringer (Vergeltung) | 20 % Chance auf 50 Mana bei Nahkampfangriff | **+10 % Schaden auf Hammer des Zorns** |
| Gronnstalker (Jäger) | Aspekt der Viper gibt zusätzlich 5 % des Intellekts | **+10 % Schaden auf Zielschuss** |
| Slayer (Schurke) | +5 % Tempo aus Blutungen (Slice and Dice) | **+6 % auf Wundstoß, Meucheln, Blutsturz** |
| Skyshatter Nahkampf | Schocks kosten 10 % weniger Mana | **Sturmschlag gibt 70 AP für 12 s** |
| Skyshatter Caster | Mit allen vier Totems: +15 mp5, +35 Zauberkrit, +45 Zauberschaden | **+5 % Schaden auf Blitzschlag** |
| Malefic (Hexer) | Verderbnis/Feuerbrand heilen 70 Leben pro Tick | **+6 % auf Schattenblitz und Verbrennen** |
| Tempest (Magier) | Hervorrufung 2 s länger | **+5 % auf Feuerball, Frostblitz und Arkane Geschosse** |
| Absolution (Schatten) | Schattenwort: Schmerz 3 s länger | **+10 % Schaden auf Gedankenschlag** |
| Thunderheart Caster | Mondfeuer 3 s länger | **+5 % Kritchance auf Sternenfeuer** |

### Drei Boni, die eure Vergabe direkt betreffen

**1. Der Vergeltungs-4er ist praktisch wertlos.** „+10 % Schaden auf Hammer des Zorns" — und Hammer des
Zorns ist nur unter 20 % Bossleben einsetzbar. Über eine ganze Begegnung gerechnet bleibt davon fast
nichts übrig. Für Kaosx heißt das: **Tier-Tokens haben für ihn kaum Set-Wert**, er sollte statt dessen
das jeweils statistisch beste Teil nehmen. Das ist einer der schwächsten 4er-Boni im ganzen Spiel.

**2. Der Magier-4er greift bei Arkan kaum.** Er erhöht Feuerball, Frostblitz und Arkane Geschosse — aber
**nicht Arkane Explosion**, die zentrale Fähigkeit eines Arkan-Magiers. Für Sinrakss, Lupitus und Lariesel
bleibt nur der Anteil aus Arkanen Geschossen. Der Bonus sieht auf dem Papier stark aus und ist es für sie nicht.

**3. Der Hexer-4er bevorzugt Zerstörung vor Gebrechen.** „+6 % auf Schattenblitz und Verbrennen" ist für
Xalessa und Simondan (Zerstörung, Schattenblitz-lastig) deutlich mehr wert als für Deters, seit er auf
Gebrechen gewechselt ist und einen großen Teil seines Schadens über Dots fährt.

Umgekehrt sind **Gronnstalker (+10 % Zielschuss)** für beide Jäger und **Slayer (+6 % Wundstoß)** für
Sandycheekz sehr stark — dort lohnt es, Tokens zu priorisieren.

---

---

## 4. Handwerk und BoE — Ergebnis: **keine Konkurrenz auf Phase-3-Niveau**

Geprüft über den Tooltip-Endpunkt (Gegenstandsstufe, Phase, Bindung):

| Item | ilvl | Phase | Bindung |
|---|---|---|---|
| Spellfire Robe / Belt | 105 | 1 | BoP |
| Frozen Shadoweave Robe | 105 | 1 | BoP |
| Spellstrike Hood / Pants | 105 | 1 | BoE |
| Vengeance Wrap | 105 | 1 | BoE |
| Bracers of Havok | 112 | 1 | BoE |
| Fel Leather Boots / Leggings | 112 | 1 | BoE |
| Netherstrike Belt / Bracers | 115 | 1 | BoP |
| Windhawk Belt | 115 | 1 | BoP |
| Netherstrike Breastplate | 120 | 1 | BoP |
| Primalstrike Belt | 120 | 1 | BoP |
| Furious Gizmatic Goggles | 127 | 2 | BoP |
| Deathblow X11 Goggles | 127 | 2 | BoP |
| Belt of Blasting | 128 | 2 | BoE |
| Boots of Blasting | 128 | 2 | BoP |
| Red Belt of Battle | 128 | 2 | BoE |
| **Dragonstrike** | **136** | 1 | BoP |

**Handwerk endet bei ilvl 128**, einzige Ausnahme Dragonstrike mit 136. Phase-3-Rezepte gibt es nicht.
Gegen Hyjal- und BT-Drops mit ilvl 141–156 ist davon **nichts konkurrenzfähig**.

**Folge für das Modell:** Handwerks- und BoE-Teile zählen **nicht** als Alternativen in der Knappheitsspalte.
Sie sind ausschließlich für die **Baseline** relevant — nämlich als Hinweis darauf, welche Slots bei einem
Spieler derzeit schwach besetzt sind. Genau das ist bei mehreren eurer Leute der Fall (Belt/Boots of
Blasting bei Lupitus, Lariesel, Simondan, Deters, Xalessa; Netherstrike-Gürtel bei Exotica; Fel Leather
Boots bei Moriamus; Bracers of Havok bei Lariesel und Xalessa). Diese Slots sind damit besonders große
Upgrade-Hebel.

## 5. BT-Trash-Items sind BoP, nicht BoE

Alle neun Trash-Drops sind **„Wird beim Aufheben gebunden"** — sie lassen sich also nicht kaufen oder
weitergeben und müssen wie jeder andere Loot vergeben werden. Meine frühere Formulierung, sie seien „kaum
umkämpft", stimmt nur beim Angebot: sie fallen wiederholt, weil Trash mehrfach gelegt wird. Sie sind
trotzdem echte Vergabeentscheidungen.

Bemerkenswert: **Band of Devastation (32526) hat ilvl 151** — dasselbe Niveau wie BT-Bossloot. Ein
Trash-Ring auf Bossniveau ist für die Knappheitsrechnung im Fingerslot bedeutsam.
Treads of the Den Mother, Girdle of the Lightbearer und Swiftsteel Bludgeon liegen bei ilvl 141.

---

## Zusammenfassung: Woraus besteht der Alternativen-Pool wirklich?

1. **Raid-Drops** aus Hyjal und BT (174 Boss-Items)
2. **BT-Trash** (9 Items, ilvl 141–151, BoP)
3. **Tier 6** über Tokens — Set-Boni je nach Spec sehr unterschiedlich wertvoll
4. **Marken-Items** — **nur falls** die Phase-3-Zuordnung stimmt (offene Frage, siehe oben)
5. Handwerk, BoE, PvP-Gear: **irrelevant**, zu niedrige Gegenstandsstufe

## Offen

- **Phasenzuordnung des Markenhändlers im Spiel gegenprüfen**, sobald Phase 3 live ist. Das ist der einzige
  verbliebene Unsicherheitsfaktor im Alternativen-Pool und betrifft vor allem Brust, Beine und Gürtel der
  Plattenträger.
