# Spec-Konfiguration für die WoWSims-Simulation

Diese drei Bausteine ergeben zusammen eine Sim-Anfrage — zusammengesetzt von `6-trinket-sim.py`:

| Datei | Inhalt |
|---|---|
| `specs.json` | je Spec: Klasse, Proto-Spec-Schlüssel, Talente, Rasse, Profil |
| `apls/<SPEC>.apl.json` | die Rotation (Priority List) |
| `raid-setup.json` | Buffs, Debuffs, Encounter, Verbrauchsgüter — **für alle Specs gleich** |

Die Ausrüstung kommt **nicht** von hier, sondern live aus `daten/players.json`.

## Warum der Raid-Aufbau für alle gleich ist

Absicht. Die DPS-Zahlen sind nur dann zwischen Specs vergleichbar, wenn alle mit identischen
Raid-Buffs rechnen — und genau das war bei den statischen Presets ein offener Punkt (siehe README,
„Buff-Annahmen"). Wer den Aufbau ändert, ändert ihn für alle.

## Woher die Werte stammen

Alles aus `github.com/wowsims/tbc-new`, damit nichts geraten ist:

- **Talente** → `ui/<klasse>/<spec>/presets.ts`, Feld `talentsString`
- **Rotationen** → `ui/<klasse>/<spec>/apls/*.apl.json`
- **Proto-Schlüssel** → `proto/api.proto`, `oneof spec`
- **Raid-Aufbau** → einmalig aus einem wowsims.com-Preset per `wowsimcli decodelink` ausgelesen

Abrufbeispiel:

```bash
gh api "repos/wowsims/tbc-new/contents/ui/warrior/dps/apls/fury.apl.json" --jq '.content' | base64 -d
```

## Drei Fallstricke

1. **Ohne APL rechnet die Sim ohne Rotation.** Der Rotationstyp `TypeSimple`, den die Teilen-Links
   von wowsims.com mitbringen, ist in dieser CLI **nicht implementiert**: er liefert exakt dasselbe
   Ergebnis wie gar keine Rotation (bei Ret 413 statt 1164 DPS). Fehlt eine `apls/<SPEC>.apl.json`,
   überspringt `6-trinket-sim.py` die Spec lieber, als eine unbrauchbare Zahl zu erzeugen.
2. **Klasse und Spec-Schlüssel müssen exakt den Protobuf-Namen entsprechen.** Die CLI meldet keinen
   Fehler bei falschen Namen, sie rechnet still ohne die Angabe.
3. **Klassengebundene Schmuckstücke bringen die Sim zum Absturz**, wenn sie an der falschen Klasse
   hängen (*Serpent-Coil Braid* am Paladin → `not mage.MageAgent`). `6-trinket-sim.py` filtert sie
   deshalb vorher über die `Classes:`-Zeile im Tooltip heraus.

## Was noch nicht stimmt

- **Rassen sind angenommen**, nicht abgerufen — `daten/players.json` enthält keine Rasse. Hinterlegt
  ist je Klasse eine plausible Allianz-Rasse. Das verschiebt Rassenboni (z. B. Waffenspezialisierung
  beim Menschen) gegenüber der Wirklichkeit.
- **Zwei Specs weichen ab:** Kroenix spielt Überleben, simuliert wird Tierherrschaft; Deters spielt
  Gebrechen, simuliert wird Zerstörung. Grund ist, dass die Rechenkette nur je eine `HUNT`- und
  `WLCK`-Spec kennt. Beides steht als `warnung` in `specs.json` und wird beim Lauf ausgegeben.
- **Verbrauchsgüter und Segen** sind grob nach Profil (physisch/zauberer) gewählt, nicht je Spec
  optimiert.
