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
3. `python 7-stat-gewichte.py` → Stat-Gewichte für **alle** DPS-Spieler → `daten/sim-weights.json`
   (gemessen 2026-08-09: rund 10 min für 18 Spieler, also ~30 s je Spieler). Schreibt zusätzlich die
   gemessene Basis-DPS als `_basisDps` mit — Nenner der Prozentanzeige, s. u.
   **Löst `wowsims-cli.ps1` ab**, das nur Kaosx konnte und dessen Aufbau
   drei stille Fehler enthielt (s. u.). Das alte Skript liegt noch da, wird aber nicht mehr gerufen.
3b. `python 6-trinket-sim.py` → Schmuckstücke per Differenzsimulation → `daten/trinket-werte.json`
   (alle DPS-Specs mit Eintrag in `spec-sims/specs.json`; rund 49 s je Spieler)

**Beide Sim-Schritte teilen sich die Konfiguration in `spec-sims/`** (eigene README dort) und damit
denselben Raid-Aufbau — nur deshalb liegen Stat-Gewichte und Schmuckstück-Werte auf derselben Skala.
Wer den Raid-Aufbau ändert, muss **beide** neu rechnen, sonst passen sie nicht mehr zusammen.
4. `.\3-compute.ps1` → Upgrades berechnen (nutzt `trinket-werte.json` und `sim-weights.json` wo
   vorhanden, sonst statische Presets bzw. Näherung) → `daten/upgrades.json`, `daten/payload.json`
5. `.\4-bis-check.ps1` → alle Rollen und alle Phasen gegen `daten/bis-listen-phasen.json` prüfen
   (Konsolen-Report, keine Dateiausgabe). Die Datei wird nicht bei jedem Lauf neu geholt, sondern
   von Hand aufgefrischt: `python daten/scrape-bis-wowhead.py`.
   **★ BiS-Quelle ist ausschließlich Wowhead — Warcraft Tavern nicht mehr verwenden**
   (ausdrückliche Vorgabe des Nutzers, 2026-08-10). Die alten Skripte `scrape_bis.py`
   (warcrafttavern) und `scrape_wowhead_final.py` (nur Phase 3) sowie die von ihnen erzeugte
   `bis-listen.json` sind entfernt. Dieselbe Datei ist auch das BiS-Gate in `3-compute.ps1`,
   ein Quellenwechsel wirkt sich also nicht nur auf den Bericht aus, sondern auf die Empfehlungen.
6. `.\5-build-payload.ps1` → HTML-Ausgabeseite bauen → `ausgabe/loot-prio-p3.html`, `index.html`

**Schritt 3 lädt bei Bedarf `bin/wowsimcli-windows.exe` herunter** (Quelle:
`github.com/wowsims/tbc-new/releases/latest`). Simuliert werden alle Spieler, deren Spec in
`spec-sims/specs.json` steht — das sind die DPS-Specs. Tank und Heiler fallen weiterhin auf die
statischen Presets in `3-compute.ps1` zurück; dort ist die Leitmetrik ohnehin prozentual.

**`wowsims-cli.ps1` ist abgelöst** und wird nicht mehr gerufen. Die Datei liegt noch da, weil sie den
alten Aufbau dokumentiert; wer sie startet, überschreibt `sim-weights.json` mit einem Stand, der nur
Kaosx enthält.

Realer Ablauf laut `.github/workflows/sync.yml` (automatisiert, täglich 03:00 UTC):
```powershell
.\0-import-roster.ps1
.\2-fetch-gear.ps1
# Guard: bricht ab, wenn daten/players.json < 5 Einträge hat (verhindert Publish bei kaputtem Abruf)
python 7-stat-gewichte.py
.\3-compute.ps1
.\4-bis-check.ps1
.\5-build-payload.ps1
# git add roster.json daten/players.json daten/cache-tooltips.json daten/payload.json
#         index.html ausgabe/loot-prio-p3.html daten/bis-listen.json daten/sim-weights.json
# git commit + push, wenn sich etwas geändert hat
```

---

## 2. Bekannte Fallen & Konventionen

* **★ Primärquelle für Gear seit 2026-08-29: Blizzards eigene Classic-Armory.** Blizzard hat unter
  `worldofwarcraft.blizzard.com/<locale>/classicann/<region>/armory/character/<realm>/<name>`
  eine offizielle, oeffentlich per einfachem `GET` abrufbare Armory-Seite fuer Classic-Inhalte
  freigeschaltet (keine Battle.net-API, kein OAuth). Das komplette Gear steckt im HTML als
  JS-Variable `characterProfileInitialState` (`Get-BlizzardEquipment` in `2-fetch-gear.ps1`
  extrahiert sie per Regex). Vorteil gegenueber `classic-armory.org`: Slots kommen bereits
  korrekt typisiert (`slot.type`, z. B. `FINGER_1`, `TRINKET_2`, `MAIN_HAND`) — der
  Armory-Slot-Bug (naechster Punkt) tritt hier nicht auf, das Tooltip-basierte Slot-Raten
  entfaellt fuer diese Spieler komplett. `classic-armory.org` bleibt als Fallback
  (`Get-ClassicArmoryEquipment`) fuer den Fall, dass die Blizzard-Seite mal nicht erreichbar ist
  oder ein Charakter dort nicht gefunden wird (liefert dann HTTP 500 statt 404 — kein Fehler,
  einfach `$null` und weiter zum Fallback). Getestet 2026-08-29 gegen den kompletten Kader:
  alle 28 Spieler liefen ueber Blizzard, kein Fallback noetig. Verzauberungen und Sockel stehen
  in der Blizzard-Antwort ebenfalls strukturiert zur Verfuegung (`gear.*.enchantments[]`,
  `gear.*.sockets[]`) — bisher ungenutzt, waere aber die Grundlage, um die unter "Cap-Stat-
  Abwaertsspirale" beschriebene fehlende Sockel/Verzauberungs-Info irgendwann sauber zu loesen.
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
  des echten Typs aus dem Wowhead-Tooltip ein. ⚠️ Betrifft seit dem Wechsel auf Blizzards eigene
  Armory (s. o.) nur noch den Fallback-Pfad — die Blizzard-Antwort liefert den Slot bereits korrekt.
* **Stat-Gewichte (wowsims.com):** Immer die absolute „DPS Weight“ (Gewinn pro Statpunkt) verwenden,
  niemals die relative „DPS EP“ — letztere ist nicht klassenübergreifend vergleichbar.
* **★★ Cap-Stat-Abwärtsspirale (De-gearing) — der Schutz greift NUR bei gemessener Null.**
  Wird ein Spieler am Hit- oder Waffenkunde-Cap simuliert, fällt das Gewicht für diesen Stat auf 0 —
  die Formel will dann fälschlich Cap-Gear ablegen. Dagegen setzt `Value-Item` (`3-compute.ps1`) das
  auf die Spielerskala umgerechnete Preset-Gewicht ein.
  ⚠️ **Bis 2026-08-10 lief das als `Max(simVal, preset*skala)`** und überschrieb damit auch ehrlich
  gemessene, bloß niedrige Werte — der Spieler war gar nicht am Cap, bekam aber trotzdem das
  generische Gewicht. Gegenstände **mit** Trefferwertung wurden dadurch pauschal überbewertet:
  Lariesel (Magierin, ZTreffer gemessen **0,353**) bekam den Schutzwert **1,33** aufgedrückt, wodurch
  *Tempest of Chaos* (BT, i151) mit 22,6 statt 6,0 Punkten die höherwertige Sunwell-Waffe *Sunflare*
  (i164) schlug.
  **Die Sim klemmt negative Gewichte auf exakt 0** — genau dann, und nur dann, trägt die Messung
  keine Information. Jeder Wert > 0 ist die Grenzbewertung für DIESEN Spieler und gilt unverändert.
  Damit gilt für alle Stats dieselbe Regel, der Sonderfall für `Treffer`/`Waffk`/`ZTreffer` ist weg.
  **Wirkung, über die Gegenprobe gemessen:** DPS Phase 3 von 61/81 % auf **70/86 %**, Phase 4 von
  52/63 % auf **59/69 %**, Phase 5 von 56/66 % auf **68/79 %**. Tank/Heiler unverändert (nutzen keine
  simulierten Gewichte).
  ⚠️ Die eigentlich saubere Lösung wäre eine Stufenfunktion aus dem echten Gear („würde dieser Tausch
  mich unter den Cap drücken?"). Sie scheitert derzeit daran, dass `daten/players.json` nur
  Slot → Item-ID speichert: **Sockel und Verzauberungen fehlen**, die Cap-Summe wäre also
  systematisch zu niedrig. Die Armory liefert beides, `2-fetch-gear.ps1` verwirft es nur.
* **Waffentempo-Normierung:** Da in TBC fast alle physischen Spezialangriffe (Mortal Strike, Stormstrike, Sinister Strike) normiert sind, wird die Waffentempo-Normierung in `Value-Item` (`3-compute.ps1`) nur für **RET-Paladine** (wegen Crusader Strike / Seal of Blood) angewendet, und zwar **linear** (`speed / normSpeed`) statt quadratisch, um eine krasse Überbewertung langsamer Waffen (wie *Torch of the Damned* vs. *Cataclysm's Edge* bei Arms) zu verhindern.
* **Bereits ausgerüstete Items (alreadyEquipped):** Damit Spieler, die ein Item bereits tragen, das in ihrer BiS-Liste steht, auf der Seite als „Bereits ausgerüstet“ gelistet werden, trackt `3-compute.ps1` die getragenen Item-IDs in `$wornIds` (der alte Check lief fälschlich gegen die stats-Hashtable) und schreibt diese Zeilen mit `Delta = 0.0` in `upgrades.json` (sowohl für DPS- als auch für Tank/Heilspezialisierungen).
* **Plausibilitäts-Check (Hashtables):** Die Funktion `Get-GearScore` in `2-fetch-gear.ps1` prüft live abgerufene Ausrüstung (die als `Hashtables` vorliegt) sowie gespeicherte Ausrüstung aus `players.json` (die als `PSCustomObjects` geladen wird). Sie iteriert universell über die Keys, um Rechenfehler (die den PvP/Offspec-Schutz durch 0-Wertungen umgehen würden) zu verhindern.
* **Legacy-BiS- und T6-Ergänzungen:** Wichtige Phase 1/2 Raid-Items, die in Phase 3 absolute BiS-Items bleiben (wie *Belt of One-Hundred Deaths* von Lady Vashj oder *Dragonspine Trophy* von Gruul), sowie alle spezialisierungsspezifischen T6-Sets sind in `1-fetch-items.ps1` hinterlegt, damit das Modell für diese Gegenstände Upgrades berechnet.
* **Fähigkeitsnamen nicht selbst übersetzen:** In `tier-boni.json` stehen sie bewusst englisch wie in
  der Quelle (*Arcane Blast* ≠ „Arkane Explosion“, das ist Arkanschlag; *Mutilate* ≠ „Blutsturz“, das
  ist Verstümmeln).
* **★ Tier-6-Tokens niemals über eine hartcodierte ID-Liste gruppieren.** Ein Token (z. B. *Helm of the
  Forgotten Vanquisher*) wird von **drei Klassen** geteilt; wer darauf würfelt, muss klassenübergreifend
  gezählt werden (`bc`). Die früher in `5-build-payload.ps1` gepflegte ID-Liste war massiv falsch:
  5 IDs existierten gar nicht, 10 lagen im falschen Slot, 2 sogar im falschen Token (*Lightbringer
  Gauntlets* = Paladin/Eroberer stand unter Bezwinger), und 33 von 78 T6-Teilen fehlten komplett.
  Ergebnis: `bc` war für dasselbe Token je Zeile unterschiedlich. **Jetzt wird die Zuordnung aus
  `items.json` abgeleitet** — Setname aus dem Boss-Feld (`Tier 6 (LightbringerRet)`) → Token-Typ, plus
  `Slot`. Kommt ein Set oder Slot hinzu, zieht das automatisch mit; das Skript warnt bei unbekannten Sets.
  Zuordnung: Eroberer = Paladin/Priester/Hexer, Beschützer = Krieger/Jäger/Schamane,
  Bezwinger = Schurke/Magier/Druide.
* **Die Token-Gegenstände selbst erzeugen keine Upgrade-Zeilen.** IDs 31089–31103 („… of the Forgotten
  …“) stehen zwar in `items.json`, haben aber weder Slot noch Werte — `3-compute.ps1` überspringt sie.
  Gelistet wird immer das **eingetauschte** Rüstungsteil mit `Quelle = T6` und `Boss = "Tier 6 (Set)"`.
  `5-build-payload.ps1` sammelt die Token separat als `payload.tokens` (Name + echter Drop-Boss) ein und
  hängt jeder T6-Zeile ihren Gruppenschlüssel als Feld `tk` an. Der Boss-Filter im Frontend matcht
  deshalb zusätzlich gegen den Token-Drop-Boss, sonst fände man T6-Kopfteile nie unter „Archimonde“.
* **★★ WoWSims-CLI ignoriert falsch platzierte Felder stillschweigend — immer gegenprüfen.** Die CLI
  meldet weder Fehler noch Warnung, wenn ein Feld an der falschen Stelle steht; sie rechnet einfach
  ohne. Drei belegte Fälle in diesem Projekt:
  1. **`talents` im Spec-Block statt `talentsString` am Spieler** — die Sim lief dadurch **komplett
     talentlos**: 614 statt 1456 DPS. Die daraus abgeleiteten Stat-Gewichte für Kaosx waren um Faktor
     2,4–3,5 zu klein und lagen so **live auf der Produktivseite** (seine ΔDPS-Werte waren dadurch
     systematisch zu niedrig, er wirkte im Loot-Rat fälschlich als jemand, der wenig profitiert).
     Behoben. **Gegenprobe bei jeder Änderung am Sim-Aufbau: mit leerem Talentstring muss die DPS
     einbrechen. Bleibt sie gleich, greift das Feld nicht.**
  2. **Ein Feld `encounter.targets[0].armor` gibt es nicht** — es wurde gesetzt und verworfen, die Sim
     lief dadurch gegen ein Ziel mit **null Rüstung** (1373 statt 1137 DPS, rund 17 % zu hoch).
     **Die Rüstung steht im Ziel-Statarray auf Index 31.** Behoben, Werte aus dem WoWSims-Preset
     „Raid Target“: `stats[17]=320` (Angriffskraft), `stats[27]=54`, `stats[31]=7685` (Rüstung),
     `stats[33]=6070400` (Leben). Dort gehört der **ungedebuffte** Grundwert hinein — die
     Rüstungs-Debuffs stehen im `debuffs`-Block und werden von der Sim selbst abgezogen.
     Gegenprobe: mit `stats[31]=0` muss die DPS deutlich steigen.
  3. **Folgefehler daraus: Rüstungsdurchschlag wurde immer mit 0 gewichtet.** Stat-Index 23 *ist*
     korrekt ArP — er zeigte nur keine Wirkung, weil das Ziel keine Rüstung hatte. Mit Rüstung 7685
     bringen +2000 ArP +109,5 DPS. Nach der Korrektur liegt Kaosx' ArP-Gewicht bei 0,047
     (statisches Preset: 0,08) statt bei 0.
  **Plausibilitätsprobe nach jeder Änderung am Sim-Aufbau:** Zaubermacht muss mit und ohne Bossrüstung
  **identisch** herauskommen (Heiligschaden ignoriert Rüstung), alle physischen Gewichte müssen fallen.
  Genau so verhält es sich jetzt (SP 0,121 in beiden Fällen, Stärke 0,786 → 0,641).
* **★ Der Wertungsvergleich beim Gear-Abruf erkennt Doppelspec-Wechsel NICHT.** `2-fetch-gear.ps1`
  verwirft einen Stand, wenn der PvE-Wert um mehr als 20 % einbricht — das fängt PvP-Sets, greift
  aber nicht bei einem **Feral-Druiden, der Tank und Katze spielt**: beide Sets sind Leder auf
  ähnlichem Itemlevel, der Score bleibt hoch, das Gear ist trotzdem das falsche. Supfreshyo war so
  im kompletten Katzen-DPS-Set erfasst, inklusive PvP-Waffe, und wurde als Tank bewertet.
  Dagegen gibt es jetzt in `2-fetch-gear.ps1` die Tabelle **`$VERRAETER`**: Item-IDs, deren blosse
  Anwesenheit den Offspec verrät, unabhängig vom Score. Erster Eintrag ist **`8345` Wolfshead Helm**
  für `FERAL_TANK` (reines Katzen-Teil). Weitere Doppelspec-Spieler brauchen einen eigenen Marker —
  am besten beim Spieler erfragen, welches Teil eindeutig nur im Offspec vorkommt.
  ⚠️ Die Regel schützt nur **künftige** Abrufe. Ist der gespeicherte Stand schon falsch, hilft nur
  `$UNSICHER` in `3-compute.ps1` (blendet die Zeilen aus), bis der Spieler einmal korrekt erfasst wird.
* **★★ Simulierte Gewichte und Preset-Gewichte liegen auf VERSCHIEDENEN Skalen — niemals unbesehen
  mischen.** Ein simuliertes Gewicht ist ein absoluter DPS-Gewinn pro Statpunkt und hängt damit an der
  DPS des Spielers. Gemessen über den Kader: **0,48× bis 1,16×** des jeweiligen Presets. Die *relativen*
  Verhältnisse stimmen dagegen fast perfekt (Grotschak: Sim `MH/Str` = 2,73, Preset 2,74) — das ist die
  beste Bestätigung, dass die Sim sauber rechnet.
  Der Cap-Schutz in `Value-Item` setzte den **absoluten** Preset-Wert als Untergrenze für
  `Treffer`/`Waffk`/`ZTreffer` ein. Da diese Stats am Cap als 0 gemessen werden, griff die Untergrenze
  immer — und mischte damit bei jedem simulierten Spieler zwei Skalen. Erikadirks Trefferwertung bekam
  das Preset-Gewicht 1,40, während alles andere bei ihm auf 0,48× lief: **fast dreifach überbewertet.**
  Der Regressionstest fiel dadurch von 60 % auf 54 %, konzentriert auf die physischen Specs.
  **Jetzt wird die Untergrenze mit dem Skalenfaktor des Spielers multipliziert** (Median der
  Verhältnisse `sim/preset` über alle Stats, die *nicht* am Cap sind). Danach: 58 % / 79 %.
  Dieselbe Skalierung gilt für den Fallback, wenn ein Stat gar nicht simuliert wurde.
* **★ Waffenkoeffizienten (`MH`/`OH`/`RANGED`) lassen sich nicht als Stat messen.** Waffenschaden ist
  kein Eintrag im `bonusStats`-Array, es gibt also keine Probe dafür. `7-stat-gewichte.py` rechnet sie
  deshalb aus dem gemessenen AP-Gewicht hoch, im selben Verhältnis, das das statische Preset in
  `3-compute.ps1` vorgibt (RET 13,06 · ARMS 13,46 · ROGUE 9,42 · ENH 8,20 · FURY 6,12 · HUNT 37,18).
  Diese Verhältnisse werden zur Laufzeit **aus `3-compute.ps1` geparst**, bewusst nicht in
  `specs.json` dupliziert — eine zweite Kopie liefe unbemerkt auseinander. Ändert sich das Format der
  `NewSpec`-Zeilen, bricht das Parsen laut ab statt still falsche Werte zu liefern.
* **★ Stat-Indizes stehen in `proto/common.proto`, `enum Stat` — nicht raten.** Die Reihenfolge ist
  nicht intuitiv: 31 ist die Rüstung, 23 der Rüstungsdurchschlag, 35 mp5, 12/13/14 sind
  Zaubertreffer/-krit/-tempo, 20/21/22 die Nahkampf-Entsprechungen. Abrufbar mit
  `gh api "repos/wowsims/tbc-new/contents/proto/common.proto" --jq '.content' | base64 -d`.
* **★ Stat-Gewichte nie mit einer Probe von 30 Punkten messen.** Tempo wirkt in TBC über
  Angriffstempo-Schwellen, nicht linear. Bei Kaosx: **+30 Tempo → −1,4 DPS** (Gewicht wurde auf 0
  geklemmt, „Tempo ist wertlos“), **+100 Tempo → +47,6 DPS** (Gewicht 0,476, also so wertvoll wie
  Krit). Die Probengröße steht jetzt auf 100; lineare Stats ändern sich dadurch nicht (Krit liefert bei
  +30 und +100 identisch 0,483). Negative Gewichte werden weiterhin auf 0 geklemmt, aber **mit
  Warnung** — das stille Klemmen hatte den Fehler lange verdeckt.
* **`bin/sim_input.json` ist kein Eingabe-, sondern ein Ausgabestand.** Die Datei wird bei *jeder*
  Sim überschrieben und enthält danach die Bonus-Stats der zuletzt gemessenen Probe. Wer sie als
  Vorlage für eigene Experimente lädt, erbt diese Reste und misst gegen eine falsche Basis
  (bei mir: 1406 statt 1373 DPS). Vor eigenen Läufen `bonusStats.stats` ausdrücklich auf 0 setzen.
* **★ Schmuckstück-Näherung (Methode A) — zwei Fallen.** `$TRINKET_EFFECTS` in `3-compute.ps1`
  hinterlegt je Schmuckstück einen Ersatz-Statblock nach der Formel
  `statischer Equip-Wert + Prokk-Wert × Uptime` (bei Nutzeneffekten `Wirkdauer / Abklingzeit`).
  1. Der Eintrag **ersetzt** den geparsten Statblock vollständig — die statischen Equip-Werte müssen
     mit drinstehen, sonst verschwinden sie stillschweigend.
  2. Nur Schlüssel, die eine Spec auch **gewichtet**, zählen. `Ausw` statt `Dodge` ergab bei *Moroes'
     Lucky Pocket Watch* stumm den Wert 0, das Schmuckstück galt aber als „bewertet“. Dagegen läuft
     jetzt ein Check direkt unter der Tabelle, der jeden unbekannten Schlüssel als Warnung meldet.
  Die Werte gehören **gegen den echten Tooltip** geprüft, nicht aus dem Gedächtnis gesetzt: gefunden
  wurden dabei *Skull of Gul'dan* (25 ist Zauber**treffer**, war als `ZKrit` codiert — bei Gewichten
  1,50–1,80 gegen 0,11–0,81 ein grober Fehler), *Ashtongue Talisman of Insight* (gibt Zauber**tempo**,
  war als `SP` codiert) und *Icon of Unyielding Courage* (28121), dessen Werte zu einem **ganz anderen
  Item** gehörten (*Hourglass of the Unraveller*, 28034).
* **Es gibt nur noch EINE Ausgabefassung.** Bis zur Abnahme der Schmuckstück-Simulation baute
  `5-build-payload.ps1` zwei Seiten aus derselben Nutzlast, unterschieden durch einen `__BETA__`-
  Schalter: `index.html` ohne Schmuckstücke, `index-beta.html` mit ihnen. Seit der Freigabe am
  03.08.2026 sind Schmuckstücke normaler Teil der Liste; Schalter, Beta-Dateien und der Hinweis
  „Keine Schmuckstücke" sind entfernt. Wer wieder etwas stufenweise ausrollen will, findet das
  Muster in der Git-Historie (Commit `d3c4085`).
* **Zuwachszahlen sind rollenübergreifend nicht vergleichbar.** `d` ist bei DPS absoluter ΔDPS, bei
  Tank/Heiler ein roher Stat-Score (die vergleichbare Größe ist dort `p` in Prozent). Beim Eroberer-Token
  konkurrieren Heilig-Priester, Schutz-Paladin und Hexer im selben Topf — eine gemeinsame Rangliste nach
  `d` wäre schlicht falsch. Die Token-Tabelle gruppiert deshalb nach Rolle und sortiert je Block nach der
  Größe, die dort auch angezeigt wird.
* **★ `p` (Prozent) hat je Rolle einen ANDEREN Nenner — das gehört an der Oberfläche dazugeschrieben.**
  Bei DPS ist `p` der Anteil an der Gesamt-DPS des Spielers, bei Tank/Heiler der Anteil am Gesamtwert
  der getragenen Ausrüstung. Die Haupttabelle zeigte beides als nacktes „%" in derselben Spalte, also
  zweimal dasselbe Zeichen für zwei verschiedene Bezugsgrößen. Jetzt steht die Bezugsgröße unter der
  Zahl (`+117.5 DPS / 8.29% von 1418 DPS` gegen `+1.88% der Ausrüstung`), und bei DPS ist der absolute
  ΔDPS die Hauptzahl — der stand vorher überhaupt nicht auf der Seite, obwohl die ganze WoWSims-Kette
  nur existiert, um ihn zu berechnen. Die Felder dafür heißen im Payload `pb` (Bezug: `dps`/`gear`),
  `bd` (Basis-DPS) und `bsim` (Basis gemessen oder Schätzwert).
* **★ Der Nenner der DPS-Prozentzahl war ein hartcodierter Spec-Schätzwert.** `Pct` lief gegen
  `$spec.BaseDps` aus `3-compute.ps1` (RET 1600, FURY 2100 …), während der Zähler je Spieler simuliert
  ist — für Kaosx also 1600 statt gemessener ~1456. `7-stat-gewichte.py` misst die Basis-DPS ohnehin
  bei jedem Lauf (Variable `basis`), hat sie aber nur ausgegeben und weggeworfen. Sie steht jetzt als
  `_basisDps` in `sim-weights.json`; `Get-BasisDps` in `3-compute.ps1` bevorzugt sie und fällt nur ohne
  sie auf das Preset zurück. **Schlüssel mit `_`-Präfix sind dort keine Statgewichte** — `Value-Item`
  iteriert nur über `$spec.W.Keys` und fasst sie deshalb nicht an. Zeilen ohne gemessene Basis sind auf
  der Seite mit `*` markiert.
* **Anwärter-Aufklappung in der Haupttabelle:** Der Knopf „👥 n Anwärter" listet **alle** Spieler zu
  einem Item, unabhängig von den aktiven Filtern und vom BiS-Schutz — das ist die eigentliche Frage
  beim Drop und war vorher nur zu beantworten, indem man den BiS-Schutz abschaltete und neu suchte.
  Der Handler ist an `#tbody` delegiert, weil der Tabellenkörper bei jedem Filterwechsel komplett neu
  geschrieben wird; direkt gebundene Handler wären danach weg. Gefiltert wird auf `id` **und** `s`
  (Slot), weil die Warglaives unter derselben Item-ID auch als Waffenhand/Schildhand/Paar auftauchen.
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
  einen Scroll-Sprung. Die Mindesthöhe von `65vh` sitzt seit dem Panel-Umbau (s. u.) auf
  `.upgrades-panel`, nicht mehr auf `#main-tablewrap` — dort steht jetzt `min-height: 0`, weil ein
  Flex-Kind sonst nicht unter seine Inhaltshöhe schrumpft und damit gar nicht intern scrollt.
* **★★ `overflow-x: auto` macht ein Element in BEIDEN Achsen zum Scrollcontainer — und killt
  `position: sticky` darin.** Der Kopf der Haupttabelle klebte nie, obwohl `thead th` korrekt auf
  `position: sticky; top: 0` stand. Ursache: `.tablewrap` hat `overflow-x: auto`; laut CSS-Spec
  rechnet der Browser `overflow-y` dann ebenfalls auf `auto` hoch (nachgemessen: `overflowY: "auto"`,
  obwohl nirgends gesetzt). Sticky klebt an dessen Scrollport — der war bei 687 Zeilen rund
  **46.000 px** hoch, scrollte selbst nie und wanderte mit der Seite weg. Der Kopf war nach wenigen
  Zeilen endgültig verschwunden. **Ein sticky-Element klebt immer am nächsten scrollenden Vorfahren,
  nicht am Viewport — wenn der Vorfahre so hoch ist wie sein Inhalt, klebt gar nichts.**
* **★ Zwei sticky-Elemente auf `top: 0` verdecken sich gegenseitig.** Filterleiste (`.controls`) und
  Tabellenkopf standen beide auf `top: 0`; nach dem Fix oben klebte der Kopf zwar, lag aber unter der
  154 px hohen Leiste. Gelöst nicht durch Offsets (die Leiste umbricht je nach Fensterbreite, ihre
  Höhe ist nicht konstant), sondern strukturell: `.upgrades-panel` (die Sektion) ist jetzt EIN
  sticky Block in Viewport-Höhe mit `display: flex; flex-direction: column`. Die Leiste steht
  statisch oben darin, `#main-tablewrap` füllt mit `flex: 1; min-height: 0; overflow: auto` den Rest
  und scrollt intern. Bewusst `max-height: 100vh` statt `height`, damit das Panel bei kurzer
  Trefferliste mitschrumpft und keinen leeren Kasten stehen lässt (gemessen: volle Liste 900 px,
  auf einen Treffer gefiltert 367 px). Nebeneffekt: die Seite ist von **49.000 px auf 4.200 px**
  geschrumpft.
* **Dropdown-Einklappen (`.hidden`):** `.ms-dropdown` nutzt `display: flex`, das HTML-Attribut `hidden`
  wird durch CSS-Spezifität überschrieben. Steuerung deshalb über `.classList.toggle('hidden')`, CSS
  definiert `.ms-dropdown.hidden { display: none !important; }`.
* **PowerShell-Funktionen mit `Write-Output` UND Rückgabewert vertragen sich nicht mit
  Variablenzuweisung.** `4-bis-check.ps1` rief ursprünglich eine Hilfsfunktion mit `$result =
  Test-BisMatches ...` auf, die zeilenweise Diagnosetext per `Write-Output` UND am Ende ein
  `[PSCustomObject]` zurückgab — PowerShell sammelt aber *alles*, was eine Funktion in die Pipeline
  schreibt, in den Rückgabewert. Der Diagnosetext landete komplett in `$result` statt auf der Konsole,
  nur die Zusammenfassung erschien. Fix: Zähler per `[ref]`-Parameter durchreichen statt per
  Rückgabewert, damit die Funktion nichts zurückgibt und `Write-Output` wieder auf der Konsole landet.

---

## 3. Offene Punkte & TODOs

* **★ Schmuckstücke werden simuliert, nicht mehr genähert (`6-trinket-sim.py`).** Das Skript tauscht
  das Schmuckstück im echten Gear des Spielers aus und misst die DPS-Differenz direkt — damit
  entfällt die Uptime-Frage vollständig. Ergebnis nach `daten/trinket-werte.json`;
  `3-compute.ps1` nimmt einen dort vorhandenen Wert **direkt als `Delta`** (er ist bereits ein
  DPS-Unterschied und darf nicht nochmal über Statgewichte laufen) und fällt nur sonst auf
  `$TRINKET_EFFECTS` zurück. Konfiguration in `spec-sims/` (eigene README dort).
  Rund 49 Sekunden je Spieler. Zwei Fallen beim Nachbauen:
  – **Negative Sim-Werte müssen raus.** Die Sim liefert auch Rückschritte; der reguläre Filter
    `$delta -le 0 { continue }` läuft im Skript *vor* der Übernahme des Sim-Werts, muss danach also
    nochmal greifen. `0` bleibt stehen (bereits getragene Teile).
  – **Ein gefilterter Lauf darf die Datei nicht überschreiben.** `python 6-trinket-sim.py Kaosx`
    ergänzt jetzt, statt alle anderen Spieler zu verwerfen.
  ⚠️ **Die Werte veralten mit dem übrigen Gear.** Gemessen wird der Unterschied gegenüber der
  Ausrüstung, die der Spieler **zum Zeitpunkt der Simulation** trug. Ändert sich sein Gear spürbar,
  stimmt die Zahl nicht mehr. Deshalb läuft der Schritt **bewusst nicht im Nachtlauf** (gut 15 Minuten
  für den Kader, und die Werte ändern sich selten) — er wird von Hand angestoßen, die Ergebnisse
  werden vom Workflow nur mitcommittet. Nach einem Raid mit vielen Neuteilen neu laufen lassen.
* **Alte Richtungsentscheidung (erledigt, als Begründung erhalten):** Die statische Näherung
  ist gegen die Sim gemessen worden und **taugt nicht**: für Kaosx sagt das Modell bei drei
  Schmuckstücken „Upgrade“, die Sim sagt bei allen dreien klar „Downgrade“
  (Madness of the Betrayer +30,0 gegen −21,4 · Icon of Unyielding Courage +27,4 gegen −49,2 ·
  Tsunami Talisman +13,5 gegen −15,5). An den Uptime-Konstanten zu drehen hilft nicht — ein
  Vorzeichenfehler dieser Größe ist kein Kalibrierproblem, sondern ein Methodenproblem (lineare
  Gewichte × flach gemittelter Prokk bilden Burst-Cooldowns und Rüstungsdurchschlag nicht ab).
  Geplanter Weg: je Spec einmal alle Schmuckstücke per Differenzsim gegen eine gemeinsame Basis
  messen (Trinket-ID im `equipment.items`-Array tauschen, ΔDPS ablesen) und das Ergebnis als
  gemessene Werte in eine `trinket-werte.json` schreiben, die `3-compute.ps1` statt `$TRINKET_EFFECTS`
  liest. **Eine Sim dauert rund 2 Sekunden**, 22 Schmuckstücke je Spieler also gut 40 Sekunden —
  Rechenzeit ist nicht der Engpass. Der Engpass ist die **Spec-Konfiguration**: `wowsims-cli.ps1` hat
  Klasse, Talente, Buffs, Verbrauchsgüter und APL für Kaosx hart verdrahtet; jede weitere Spec braucht
  ihre eigene — dafür ist `wowsimcli decodelink` das richtige Werkzeug, siehe nächster Punkt.
* **★ Spec-Konfigurationen über `wowsimcli decodelink` beschaffen, nicht von Hand bauen (erprobt).**
  Auf `wowsims.com/tbc/<klasse>/<spec>/` gibt es unter **Export → Link** einen Teilen-Link, der den
  kompletten Zustand kodiert. `wowsimcli decodelink "<link>"` gibt daraus ein vollständiges
  Einstellungs-JSON aus — mit korrektem `talentsString`, `rotation`, `class`, Spec-Block,
  `consumables`, `buffs`, `debuffs` **und** dem richtig befüllten `encounter.targets[0].stats`
  (so wurde der Rüstungsfehler oben überhaupt gefunden). Die Spec-Pfade heißen nicht wie die Specs:
  Krieger und Schurke, Magier, Hexer, Jäger und Schattenpriester laufen alle über `/dps/`
  (`/tbc/warrior/dps/`, `/tbc/rogue/dps/`, `/tbc/mage/dps/`, `/tbc/warlock/dps/`, `/tbc/hunter/dps/`,
  `/tbc/priest/dps/`), der Rest ist benannt (`/paladin/retribution/`, `/shaman/enhancement/`,
  `/shaman/elemental/`, `/druid/balance/`, `/druid/feralbear/`, `/paladin/protection/` …).
  ⚠️ **Das decodelink-Ergebnis ist kein RaidSimRequest.** Es hat `player` (Einzahl) auf oberster Ebene;
  die CLI braucht für `sim` aber `raid.parties[0].players[0]` plus `raid.buffs` / `raid.debuffs` /
  `raid.parties[0].buffs`. Das muss umgehängt werden. In der UI gibt es zusätzlich einen Punkt
  **„CLI Export“**, der vermutlich direkt das richtige Format liefert — noch nicht geprüft.
  Ebenfalls beachten: die Presets nutzen `rotation.type = "TypeSimple"` mit `specRotationJson`, nicht
  die APL-Dateien in `spec-sims/apls/`, die unsere Sim-Skripte verwenden.
* **Abgenommen und live seit 03.08.2026.** Die simulierten Schmuckstück-Werte sind freigegeben und
  Teil der normalen Liste. Die Näherung `$TRINKET_EFFECTS` bleibt als Rückfall für alles, was nicht
  simuliert wird — praktisch also für Tank und Heiler. Dort sind weiterhin unsicher:
  *The Lightning Capacitor* (Schadensprokk, pauschal 70 SP), *Ashtongue Talisman of Lethality*
  (~90 % Uptime ist optimistisch), *Pendant of the Violet Eye* (gestapelte mp5 grob gemittelt) und
  *Shadowmoon Insignia* (Notfall-Leben als Ausdauer gemittelt — methodisch fragwürdig, weil es ein
  Überlebens-Cooldown ist, kein Durchsatz).
* **Die Tabelle deckt den Pool derzeit exakt ab** (22 Schmuckstücke im Pool, 22 hinterlegt, kein toter
  Eintrag). Kommt über `1-fetch-items.ps1` ein neues Schmuckstück dazu, fällt es automatisch auf
  `NichtBewertbar` zurück — dann Eintrag in `$TRINKET_EFFECTS` nachziehen. Gegenprobe:
  Pool-IDs mit `Slot -eq 'Trinket'` gegen die Schlüssel der Tabelle abgleichen.
* **★★ Sunwell (Phase 5) bringt eine ZWEITE Tier-Token-Familie.** Neben Tier 6 gibt es
  „Bracers/Belt/Boots of the Forgotten Conqueror/Protector/Vanquisher" (ilvl 154). Die Token droppen
  bei den ersten drei Sunwell-Bossen (Armschienen Kalecgos, Gürtel Brutallus, Stiefel Felmyst), das
  Rüstungsteil holt man damit bei **Theremis (NPC 25976)**, der 51 klassenspezifische Teile führt.
  Struktur also identisch zu Tier 6 — und damit gilt dieselbe Falle: **niemals über hartcodierte
  Item-IDs gruppieren**, sondern aus `items.json` ableiten. Wer die Phasen-Umschaltung fertigbaut,
  muss die T6-Token-Logik in `5-build-payload.ps1` für diese Familie mitziehen, sonst zählt `bc`
  (Anzahl Anwärter) für Sunwell-Token falsch.
* **⚠️ Der Drop-Tabellen-Schlüssel heißt auf Wowhead mal `data: [` und mal `data:[`.** Diese Datei
  warnte bisher nur vor der Variante ohne Leerzeichen; auf den NPC-Seiten ist es genau umgekehrt.
  `daten/scrape-pool-wowhead.py` matcht deshalb `data:\s*\[`. Ein Muster auf nur eine Form scheitert
  stumm mit leerem Ergebnis.
* **Token haben `slot: 0` und fallen durch jeden „nur ausrüstbare Items"-Filter.** Genau das ist mir
  beim ersten Lauf des Pool-Scrapers passiert: die Sunwell-Token fehlten komplett, ohne Fehlermeldung.
  Der Filter lässt sie jetzt ausdrücklich über den Namen durch.
* **★ Knappheitsspalten sind VERWORFEN — nicht erneut vorschlagen.** Einmal gebaut und wieder
  entfernt (Commit `a413a14`), am 2026-08-09 vom Nutzer endgültig abgelehnt: In Phase 3 gibt es je
  Slot meist gar keine und sonst genau eine Alternative. Eine Spalte, die fast überall „0" oder „1"
  zeigt, trägt keine Entscheidung und kostet nur Breite. Die Rohdaten in
  `quellen/p3-alternativen-*.md` bleiben als Rechercheunterlage liegen. Nicht zu verwechseln mit dem
  Hinweis „Alternative: …" unter Tier-Zeilen (`getAlternativesNote` in `vorlage.html`) — der nennt
  das konkrete Ausweichteil samt Zuwachs und bleibt.
* **Buff-Annahmen stichprobenartig prüfen:** Die statischen Preset-Gewichte sind nicht spec-übergreifend
  auf identische Raid-Buffs verifiziert (siehe
  [p3-stat-gewichte-2026-07-27.md](quellen/p3-stat-gewichte-2026-07-27.md)).
* **`bin/`-Inhalte wachsen mit jedem Lauf:** `sim_input.json`/`sim_output.json` werden bei jeder
  Simulation überschrieben und mitcommittet.

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
  Tier-6-Tokens sind ausgeschlossen (die stehen in der eigenen Token-Tabelle), Schmuckstücke als
  (BiS)/(Bedarf) integriert.
* **[x] Tier-6-Token-Konkurrenz korrekt gerechnet und sichtbar gemacht:** Gruppen werden aus `items.json`
  abgeleitet statt hartcodiert (alle 78 T6-Teile in 15 Gruppen statt vorher 45 teils falsch zugeordnete).
  Neue Tabelle „Tier-6-Tokens“ dreht die Sicht um: pro Token alle Anwärter der drei Klassen, nach Rolle
  getrennt und nach Zuwachs sortiert, mit BiS-Markierung, Anzahl Anwärter/BiS-Kandidaten und echtem
  Drop-Boss. T6-Zeilen sind zusätzlich über den Token-Drop-Boss filterbar.
* **[x] WoWSims-CLI-Integration & dynamische Simulation:** Vollautomatische Simulation für Kaosx zur
  Ermittlung individueller Stat-Gewichte, inklusive automatischem CLI-Download und
  Workflow-Integration.
* **[x] Globale Waffentempo- & Cap-Stat-Sicherungen:** Mechanisch korrekte Bewertung von
  Zweihandwaffen und Schutz der Cap-Gegenstände vor fälschlichem Ablegen (De-gearing).
* **[x] Interaktiver Multi-Select-Spieler-Filter:** Gleichzeitige Auswahl mehrerer Raider inklusive
  Suchfeld, ohne Scroll-Sprung beim Filtern.
* **[x] Aufräumen Tabellendesign:** Grüne Verlaufsbalken hinter den Prozentwerten entfernt.
* **[x] Regressionstest für Tank und Heiler** (2026-08-09): `4-bis-check.ps1` prüft beide Rollen
  gegen die Wowhead-Guides, sortiert dort nach `Pct` statt `Delta`. Stand 70 / 77 % / 90 %.
* **[x] Repo aufgeräumt** (2026-08-09): einmalige Scrape-/Debug-Skripte, `raw.html`, `temp.csv`,
  `task.md`, `implementation_plan.md` und die leere `bin/template.json` entfernt; `temp.csv` fliegt
  auch nicht mehr in den Auto-Commit. ⚠️ `daten/scrape_bis.py` und `daten/scrape_wowhead_final.py`
  sahen dabei wie Einmalwerkzeuge aus, sind aber die **Erzeuger von `bis-listen.json`** — sie waren
  schon gelöscht und mussten zurückgeholt werden.
* **[x] Haupttabelle lesbar gemacht** (2026-08-09): klebender Spaltenkopf repariert (Panel-Layout,
  Seite 49.000 → 4.300 px), absoluter ΔDPS wieder sichtbar mit ausgewiesener Bezugsgröße,
  Prozentnenner auf die gemessene Basis-DPS umgestellt, Anwärter-Aufklappung je Item,
  Filter-zurücksetzen-Knopf.
