# Phase-3-Item-Werte (Schritt 2) — 183 Items, Stand 2026-07-27

Quelle: `https://nether.wowhead.com/tbc/tooltip/item/<ID>?locale=0`, Item-Liste aus den Boss-NPC-Seiten
(siehe [p3-item-pool-2026-07-27.md](p3-item-pool-2026-07-27.md)).

Format: `ID Name iLvl Slot Rüstungsart || Basiswerte | Wertungen | AP/SP/Heil/mp5/Waffen-dps | Sockel | Klassenbindung`
Kürzel: Krit, Treffer, Tempo, Waffk (Waffenkunde), ArP, Vert (Verteidigung), Ausw (Ausweichen), Parr, Block,
`Z-` = Zauber-Variante. Sockel `[R2Y1B1M1]` = rot/gelb/blau/Meta.

---

## ⚠️ Befund 1: Rüstungsdurchschlag ist in TBC KEINE Wertung

Er steht als **flacher Wert** direkt auf dem Item („Deine Angriffe ignorieren X Rüstung") und existiert in
Phase 3 auf genau **8 Items**, alle für physischen Schaden:

| Item | Boss | Wert |
|---|---|---|
| Leggings of Divine Retribution (32341) | Gurtogg | 350 |
| Cataclysm's Edge (30902) | Archimonde | 335 |
| Soul Cleaver (32348) | Teron | 315 |
| Boundless Agony (30901) | Azgalor | 210 |
| Shady Dealer's Pantaloons (30898) | Azgalor | 175 |
| Grips of Silent Justice (32278) | Shade of Akama | 175 |
| Stormrage Signet Ring (32497) | Illidan | 126 |
| Madness of the Betrayer (32505) | Illidari-Rat | 300 als Prokk, 10 s |

Folge fürs Modell: kein Rating-zu-Prozent-Umweg, keine abnehmenden Erträge auf der Wertungsseite. Der Wert
muss gegen die **gedebuffte** Bossrüstung gerechnet werden (nach 5× Zerreißen, Feenfeuer, Fluch der
Tollkühnheit bleiben grob 3.700 statt 7.700). Blutungen profitieren nicht — relevant für Schurke.

Hinweis: `Hatefury Mantle(30884)` hat **Zauberdurchschlag** (23), nicht Rüstungsdurchschlag. Nicht verwechseln.

## ⚠️ Befund 2: Tempo ist der eigentliche neue Stat

Tempo taucht breit auf: Belt of Seething Fury (38), Pillager's Gauntlets (38), Torch of the Damned (50),
Girdle of Lordaeron's Fallen (Z-38), Fists of Mukoa (37), Shadow-walker's Cord (37), Grips of Damnation (37),
Valestalker Girdle (36), Band of Devastation (31), Girdle of the Lightbearer (32), Swiftsteel Bludgeon (27),
dazu viele Z-Tempo-Teile für Caster und Heiler.

## Prokk- und Nutzen-Effekte (nur diese 9 Items im ganzen Pool)

- **Warglaive of Azzinoth (32837/32838)** — 2-Set: Nahkampfangriffe können Tempo um 450 für 10 s erhöhen (45 s CD), zusätzlich +200 AP gegen Dämonen
- **Madness of the Betrayer (32505)** — Prokk: 300 Rüstung ignorieren, 10 s
- **The Skull of Gul'dan (32483)** — Nutzen: +175 Zaubertempo, 20 s
- **Shadowmoon Insignia (32501)** — Nutzen: +1750 max. Leben, 20 s (Tank)
- **Bulwark of Azzinoth (32375)** — 2 % Chance auf +2000 Rüstung, 10 s (Tank)
- **Memento of Tyrande (32496)** — Prokk: bis 76 mp5, 15 s (Heiler)
- **Idol of the White Stag (32257)** — Verwüsten gibt +94 AP, 20 s (Feral)
- **Tome of the Lightbringer (32368)** — Richturteil gibt +186 Blockwert, 5 s (Schutz-Pala)

Alles andere im Pool ist reine Statistik ohne Prokk — die Rechnung bleibt damit überschaubar.

---

## Vollständige Werte

30861 Furious Shackles i141 Handgel Platte || Str35 Sta3 | Krit19 | [Y1]
30862 Blessed Adamantite Bracers i141 Handgel Platte || Sta3 Int22 | Z-Krit21 | Heil62 | [Y1]
30863 Deadly Cuffs i141 Handgel Leder || Sta3 | Treffer12 Krit28 | AP58 | [Y1]
30864 Bracers of the Pathfinder i141 Handgel Kette || Agi25 Sta24 Int24 | AP48 | [B1]
30865 Tracker's Blade i141 1H || Treffer20 Krit23 | AP44 dps100.33/1.5
30866 Blood-stained Pauldrons i141 Schulter Platte || Str47 Sta34 | Treffer23 Krit32
30868 Rejuvenating Bracers i141 Handgel Leder || Sta16 Int20 Spi28 | Heil64 | [B1]
30869 Howling Wind Bracers i141 Handgel Kette || Sta29 Int21 | Heil62 mp5:8 | [B1]
30870 Cuffs of Devastation i141 Handgel Stoff || Sta3 Int20 Spi19 | Z-Krit14 | SP34 | [Y1]
30871 Bracers of Martyrdom i141 Handgel Stoff || Sta15 Int20 Spi28 | Heil64 | [B1]
30872 Chronicle of Dark Secrets i141 Nebenhand || Sta16 Int12 | Z-Treffer17 Z-Krit23 | SP42
30873 Stillwater Boots i141 Fuesse Kette || Sta39 Int36 | Heil84 mp5:10
30874 The Unbreakable Will i141 1H || Sta33 | Vert21 | dps100.31/1.6
30878 Glimmering Steel Mantle i141 Schulter Platte || Sta26 Int27 | Z-Krit29 | Heil84 | [Y1B1]
30879 Don Alejandro's Money Belt i141 Taille Leder || Agi29 Sta4 | Krit19 | AP76 | [R1Y1]
30880 Quickstrider Moccasins i141 Fuesse Kette || Agi3 Sta30 Int31 | Treffer15 | AP58 | [R1Y1]
30881 Blade of Infamy i141 1H || Agi28 | AP56 dps100.19/2.6
30882 Bastion of Light i141 Schild Schild || Sta28 Int28 | Heil62 | [R1]
30883 Pillar of Ferocity i141 2H || Str47 Sta96 | AP1059 dps71.5/3
30884 Hatefury Mantle i141 Schulter Stoff || Sta15 Int18 | Z-Krit24 | SP55 | [Y1B1] (+23 Zauberdurchschlag)
30885 Archbishop's Slippers i141 Fuesse Stoff || Sta29 Int30 Spi37 | Heil84
30886 Enchanted Leather Sandals i141 Fuesse Leder || Sta34 Int29 Spi37 | Heil84
30887 Golden Links of Restoration i141 Brust Kette || Sta51 Int35 | Heil118 mp5:19
30888 Anetheron's Noose i141 Taille Stoff || Sta22 Int23 | Z-Krit24 | SP55 | [Y1B1]
30889 Kaz'rogal's Hardened Heart i141 Schild Schild || Sta3 | Vert28 Treffer21 | [Y1]
30891 Black Featherlight Boots i141 Fuesse Leder || Sta41 | Treffer34 | AP98
30892 Beast-tamer's Shoulders i141 Schulter Kette || Agi39 Sta38 | AP78
30893 Sun-touched Chain Leggings i141 Beine Kette || Sta39 Int28 | Heil110 mp5:16 | [Y1B2]
30894 Blue Suede Shoes i141 Fuesse Stoff || Sta37 Int32 | Z-Treffer18 | SP56
30895 Angelista's Sash i141 Taille Stoff || Sta29 Int30 | Z-Tempo37 | Heil84
30896 Glory of the Defender i141 Brust Platte || Sta75 | Vert35 Ausw51 Treffer34
30897 Girdle of Hope i141 Taille Platte || Sta38 Int3 | Z-Krit21 | Heil84 | [Y2]
30898 Shady Dealer's Pantaloons i141 Beine Leder || Agi50 Sta61 | AP102 (ArP 175)
30899 Don Rodrigo's Poncho i141 Brust Leder || Sta39 Int31 Spi52 | Heil118
30900 Bow-stitched Leggings i141 Beine Kette || Agi42 Sta28 Int28 | Krit20 | AP100 | [R1Y1B1]
30901 Boundless Agony i141 1H || Krit24 | dps100.28/1.8 (ArP 210)
30902 Cataclysm's Edge i151 2H || Str75 Sta49 | dps138/3.5 (ArP 335)
30903 Legguards of Endless Rage i151 Beine Platte || Str70 Sta61 | Treffer19 Krit46
30904 Savior's Grasp i151 Brust Platte || Sta69 Int48 | Z-Krit46 | Heil106
30905 Midnight Chestguard i151 Brust Leder || Sta64 | Treffer29 Krit46 | AP106 | [R1Y1B1]
30906 Bristleblitz Striker i151 Distanz || Sta28 | Krit25 | dps95.83/3
30907 Mail of Fevered Pursuit i151 Brust Kette || Agi49 Sta66 | Krit29 | AP108 mp5:8
30908 Apostle of Argus i151 2H || Sta62 Int59 | Heil486 mp5:23 dps73.28/3.2
30909 Antonidas's Aegis of Rapt Concentration i151 Schild Schild || Sta28 Int20 | Z-Krit20 | SP42
30910 Tempest of Chaos i151 Waffenhand || Sta30 Int22 | Z-Treffer17 Z-Krit24 | SP259 dps40.83/1.8
30911 Scepter of Purification i151 Nebenhand || Sta24 Int17 Spi25 | Heil77
30912 Leggings of Eternity i151 Beine Stoff || Sta45 Int38 | Heil121 mp5:16 | [B3]
30913 Robes of Rhonin i151 Brust Stoff || Sta55 Int38 | Z-Treffer27 Z-Krit24 | SP81
30914 Belt of the Crescent Moon i141 Taille Leder || Sta25 Int27 Spi19 | Z-Tempo36 | SP44
30915 Belt of Seething Fury i141 Taille Platte || Str48 Sta37 | Tempo38
30916 Leggings of Channeled Elements i141 Beine Stoff || Sta25 Int28 Spi28 | Z-Treffer18 Z-Krit34 | SP59 | [Y2B1]
30917 Razorfury Mantle i141 Schulter Leder || Agi28 Sta55 | Krit23 | AP76
30918 Hammer of Atonement i141 Waffenhand || Sta31 Int21 | Z-Krit23 | Heil443 dps41.39/1.8
30919 Valestalker Girdle i141 Taille Kette || Agi27 Sta25 Int18 | Tempo36 | AP76
31089 Chestguard of the Forgotten Conqueror — Token Brust || Paladin, Priester, Hexenmeister
31090 Chestguard of the Forgotten Vanquisher — Token Brust || Schurke, Magier, Druide
31091 Chestguard of the Forgotten Protector — Token Brust || Krieger, Jäger, Schamane
31092 Gloves of the Forgotten Conqueror — Token Hände || Paladin, Priester, Hexenmeister
31093 Gloves of the Forgotten Vanquisher — Token Hände || Schurke, Magier, Druide
31094 Gloves of the Forgotten Protector — Token Hände || Krieger, Jäger, Schamane
31095 Helm of the Forgotten Protector — Token Kopf || Krieger, Jäger, Schamane
31096 Helm of the Forgotten Vanquisher — Token Kopf || Schurke, Magier, Druide
31097 Helm of the Forgotten Conqueror — Token Kopf || Paladin, Priester, Hexenmeister
31098 Leggings of the Forgotten Conqueror — Token Beine || Paladin, Priester, Hexenmeister
31099 Leggings of the Forgotten Vanquisher — Token Beine || Schurke, Magier, Druide
31100 Leggings of the Forgotten Protector — Token Beine || Krieger, Jäger, Schamane
31101 Pauldrons of the Forgotten Conqueror — Token Schulter || Paladin, Priester, Hexenmeister
31102 Pauldrons of the Forgotten Vanquisher — Token Schulter || Schurke, Magier, Druide
31103 Pauldrons of the Forgotten Protector — Token Schulter || Krieger, Jäger, Schamane
32232 Eternium Shell Bracers i141 Handgel Platte || Sta52 | Vert24 Ausw26
32234 Fists of Mukoa i141 Haende Kette || Agi25 Sta24 Int17 | Tempo37 | AP76
32235 Cursed Vision of Sargeras i151 Kopf Leder || Agi39 Sta6 | Treffer21 Krit38 | AP108 | [Y1M1]
32236 Rising Tide i141 1H || Sta33 | Treffer21 | AP44 dps100.19/2.6
32237 The Maelstrom's Fury i141 Waffenhand || Sta33 Int21 | Z-Krit22 | SP236 dps41.39/1.8
32238 Ring of Calming Waves i141 Finger || Sta19 Int27 | Z-Krit24 | Heil64
32239 Slippers of the Seacaller i141 Fuesse Stoff || Sta25 Int18 Spi18 | Z-Krit29 | SP44 | [Y1B1]
32240 Guise of the Tidal Lurker i141 Kopf Leder || Sta39 Int35 | Heil103 mp5:15 | [R1M1]
32241 Helm of Soothing Currents i141 Kopf Kette || Sta40 Int42 | Heil118 mp5:10 | [B1M1]
32242 Boots of Oceanic Fury i141 Fuesse Kette || Sta28 Int36 | Z-Krit26 | SP55
32243 Pearl Inlaid Boots i141 Fuesse Platte || Sta37 Int27 | Z-Krit28 | Heil84 mp5:8
32245 Tide-stomper's Greaves i141 Fuesse Platte || Sta4 | Vert19 Ausw29 | SP30 | [R1Y1]
32247 Ring of Captured Storms i141 Finger || Z-Treffer19 Z-Krit29 | SP42
32248 Halberd of Desolation i141 2H || Agi51 Sta57 | Treffer30 | AP100 dps130.43/3.5
32250 Pauldrons of Abyssal Fury i141 Schulter Platte || Sta72 | Vert28 Ausw36
32251 Wraps of Precise Flight i141 Handgel Kette || Agi18 Sta28 Int20 | Krit19 | AP58
32252 Nether Shadow Tunic i141 Brust Leder || Agi36 Sta52 | Treffer35 | AP86 | [R1Y1B1]
32253 Legionkiller i141 Distanz || Agi21 Sta30 | dps90.69/2.9
32254 The Brutalizer i141 1H || Sta33 | Vert22 Waffk21 | dps100.31/1.6
32255 Felstone Bulwark i141 Schild Schild || Sta28 Int21 | Z-Krit27 | Heil64
32256 Waistwrap of Infinity i141 Taille Stoff || Sta31 Int22 | Z-Tempo32 | SP56
32257 Idol of the White Stag i141 Relikt || (Prokk: Verwüsten +94 AP, 20 s)
32258 Naturalist's Preserving Cinch i141 Taille Kette || Sta29 Int30 | Z-Tempo37 | Heil84
32259 Bands of the Coming Storm i141 Handgel Kette || Sta28 Int28 | Z-Krit21 | SP34
32260 Choker of Endless Nightmares i141 Hals || Treffer21 Krit27 | AP72
32261 Band of the Abyssal Lord i141 Finger || Sta53 | Vert27 Treffer21
32262 Syphon of the Nathrezim i141 1H || AP50 dps100.18/2.8
32263 Praetorian's Legguards i141 Beine Platte || Sta6 | Ausw35 Parr43 Treffer18 | [R1Y2]
32264 Shoulders of the Hidden Predator i141 Schulter Kette || Agi38 Sta37 | Krit26 | AP76
32265 Shadow-walker's Cord i141 Taille Leder || Agi27 Sta38 | Tempo37 | AP76
32266 Ring of Deceitful Intent i141 Finger || Agi21 Sta42 | Treffer19 | AP58
32268 Myrmidon's Treads i141 Fuesse Platte || Sta56 | Vert30 Ausw26 Treffer17 | [R1Y1]
32269 Messenger of Fate i141 1H || Agi22 Sta31 | AP44 dps100.36/1.4
32270 Focused Mana Bindings i141 Handgel Stoff || Sta27 Int20 | Z-Treffer19 | SP42
32271 Kilt of Immortal Nature i141 Beine Leder || Sta40 Int42 | Heil118 mp5:10 | [Y1B2]
32273 Amice of Brilliant Light i141 Schulter Stoff || Sta38 Int27 Spi37 | Heil84
32275 Spiritwalker Gauntlets i141 Haende Kette || Sta38 Int27 | Z-Tempo37 | Heil84
32276 Flashfire Girdle i141 Taille Kette || Sta27 Int26 | Z-Krit18 Z-Tempo37 | SP44
32278 Grips of Silent Justice i141 Haende Platte || Str40 Sta4 | Treffer15 | [R2] (ArP 175)
32279 The Seeker's Wristguards i141 Handgel Platte || Sta43 | Vert21 Blockwert28 | SP22
32280 Gauntlets of Enforcement i141 Haende Platte || Sta70 | Vert32 Waffk21
32323 Shadowmoon Destroyer's Drape i141 Ruecken || Sta24 | Treffer17 Krit24 | AP72
32324 Insidious Bands i141 Handgel Leder || Agi2 Sta28 | Treffer12 | AP58 | [Y1]
32325 Rifle of the Stoic Guardian i141 Distanz || Sta31 | Ausw20 | dps90.53/1.9
32326 Twisted Blades of Zarak i141 Wurf || Agi23 | Krit16 | dps90.36/1.4
32327 Robe of the Shadow Council i141 Brust Stoff || Sta37 Int36 Spi26 | Z-Krit28 | SP73
32328 Botanist's Gloves of Growth i141 Haende Leder || Sta22 Int21 | Z-Tempo37 | Heil84 | [Y1B1]
32329 Cowl of Benevolence i141 Kopf Stoff || Sta39 Int27 Spi42 | Heil118 | [B1M1]
32330 Totem of Ancestral Guidance i141 Relikt ||
32331 Cloak of the Illidari Council i141 Ruecken || Sta24 Int16 | Z-Krit25 | SP42
32332 Torch of the Damned i141 2H || Str51 Sta45 | Krit38 Tempo50 | dps130.39/3.8
32333 Girdle of Stability i141 Taille Platte || Sta4 | Vert19 Ausw18 | [R1Y1]
32334 Vest of Mounting Assault i141 Brust Kette || Agi58 Sta27 Int18 | AP116
32335 Unstoppable Aggressor's Ring i141 Finger || Str36 Sta28 | Krit30
32336 Black Bow of the Betrayer i151 Distanz || AP26 dps95.83/3
32337 Shroud of Forgiveness i141 Ruecken || Sta27 Int19 Spi20 | Heil79
32338 Blood-cursed Shoulderpads i141 Schulter Stoff || Sta25 Int19 | Z-Treffer18 Z-Krit25 | SP55
32339 Belt of Primal Majesty i141 Taille Leder || Sta34 Int29 | Z-Tempo37 | Heil84
32340 Garments of Temperance i141 Brust Stoff || Sta51 Int34 | Heil118 mp5:20
32341 Leggings of Divine Retribution i141 Beine Platte || Str51 Sta51 | Krit35 (ArP 350)
32342 Girdle of Mighty Resolve i141 Taille Platte || Sta56 | Vert26 Blockwert25 | SP30 | [Y1B1]
32343 Wand of Prismatic Focus i141 Distanz || Sta21 | Z-Treffer13 | SP25 dps184.33/1.5
32344 Staff of Immaculate Recovery i141 2H || Sta73 Int51 Spi35 | Heil443 mp5:14 dps71.41/3.2
32345 Dreadboots of the Legion i141 Fuesse Platte || Str3 Sta40 | Treffer18 Krit30 | [Y2]
32346 Boneweave Girdle i141 Taille Kette || Agi38 Int26 | Treffer17 Krit24 | AP76
32347 Grips of Damnation i141 Haende Leder || Agi27 Sta38 | Tempo37 | AP76
32348 Soul Cleaver i141 2H || Str65 Sta63 | dps130.41/3.7 (ArP 315)
32349 Translucent Spellthread Necklace i141 Hals || Z-Treffer15 Z-Krit24 | SP46
32350 Touch of Inspiration i141 Nebenhand || Sta24 Int21 | Heil64 mp5:12
32351 Elunite Empowered Bracers i141 Handgel Leder || Sta27 Int22 | Z-Treffer19 | SP34 mp5:6
32352 Naturewarden's Treads i141 Fuesse Leder || Sta39 Int18 | Z-Krit26 | SP44 mp5:7 | [Y1B1]
32353 Gloves of Unfailing Faith i141 Haende Stoff || Sta25 Int33 | Heil75 mp5:11 | [R1B1]
32354 Crown of Empowered Fate i141 Kopf Platte || Sta39 Int27 | Z-Krit42 | Heil118 | [B1M1]
32361 Blind-Seers Icon i141 Nebenhand || Sta25 Int16 | Z-Treffer24 | SP42
32362 Pendant of Titans i141 Hals || Sta43 | Vert21 Ausw25 Treffer20
32363 Naaru-Blessed Life Rod i141 Distanz || Sta12 Int12 Spi16 | Heil37 dps184.33/1.5
32365 Heartshatter Breastplate i141 Brust Platte || Str63 Sta45 | Treffer30 Krit44
32366 Shadowmaster's Boots i141 Fuesse Leder || Agi30 Sta38 | Krit17 | AP76 | [R1Y1]
32367 Leggings of Devastation i141 Beine Stoff || Sta40 Int42 | Z-Treffer26 | SP60 | [Y2B1]
32368 Tome of the Lightbringer i141 Relikt || (Prokk: Richturteil +186 Blockwert, 5 s)
32369 Blade of Savagery i141 1H || Sta19 | Treffer15 Krit22 | AP44 dps100.36/1.4
32370 Nadina's Pendant of Purity i141 Hals || Sta16 Int14 | Z-Krit19 | Heil79 mp5:8
32373 Helm of the Illidari Shatterer i141 Kopf Platte || Str51 Sta6 | Treffer34 Krit42 | [Y1M1]
32374 Zhar'doom, Greatstaff of the Devourer i151 2H || Sta70 Int47 | Z-Krit36 Z-Tempo55 | SP259 dps73.28/3.2
32375 Bulwark of Azzinoth i151 Schild Schild || Sta60 | Vert29 (Prokk: +2000 Rüstung)
32376 Forest Prowler's Helm i141 Kopf Kette || Agi42 Sta29 Int28 | Krit20 | AP100 | [R1M1]
32377 Mantle of Darkness i141 Schulter Leder || Sta34 | Treffer22 Krit33 | AP94
32471 Shard of Azzinoth i151 1H || AP64 dps106.05/1.9
32483 The Skull of Gul'dan i151 Schmuck || Z-Treffer25 | SP55 (Nutzen: +175 Zaubertempo, 20 s)
32496 Memento of Tyrande i151 Schmuck || Heil118 (Prokk: bis 76 mp5)
32497 Stormrage Signet Ring i151 Finger || Sta33 | Treffer30 | AP66 (ArP 126)
32500 Crystal Spire of Karabor i151 Waffenhand || Sta22 Int15 | Heil486 mp5:6 dps40.83/1.8
32501 Shadowmoon Insignia i141 Schmuck || Vert36 Ausw32 (Nutzen: +1750 Leben)
32505 Madness of the Betrayer i141 Schmuck || Treffer20 | AP84 (Prokk: ArP 300, 10 s)
32510 Softstep Boots of Tracking i141 Fuesse Kette || Agi27 Int29 | Treffer17 Krit26 | AP76
32512 Girdle of Lordaeron's Fallen i141 Taille Platte || Sta32 Int32 | Z-Tempo38 | Heil70
32513 Wristbands of Divine Influence i141 Handgel Stoff || Sta24 Int21 Spi28 | Heil62
32517 The Wavemender's Mantle i141 Schulter Kette || Sta37 Int26 | Heil84 mp5:15
32518 Veil of Turning Leaves i141 Schulter Leder || Sta29 Int29 Spi38 | Heil84
32519 Belt of Divine Guidance i141 Taille Stoff || Sta35 Int24 Spi32 | Heil73 | [Y1B1]
32521 Faceplate of the Impenetrable i151 Kopf Platte || Sta6 | Vert30 Ausw38 Blockwert29 | [R1M1]
32524 Shroud of the Highborne i151 Ruecken || Sta24 Int23 | Z-Tempo32 | Heil68
32525 Cowl of the Illidari High Lord i151 Kopf Stoff || Sta33 Int31 | Z-Treffer21 Z-Krit47 | SP64 | [B1M1]
32526 Band of Devastation i151 Finger (Trash) || Sta44 | Tempo31 | AP66
32527 Ring of Ancient Knowledge i151 Finger (Trash) || Sta30 Int20 | Z-Tempo31 | SP39
32528 Blessed Band of Karabor i151 Finger (Trash) || Sta20 Int20 | Z-Tempo30 | Heil73 mp5:6
32593 Treads of the Den Mother i141 Fuesse Leder (Trash) || Str38 Agi32 Sta47 Int14
32606 Girdle of the Lightbearer i141 Taille Platte (Trash) || Str49 Sta33 Int21 | Tempo32
32608 Pillager's Gauntlets i141 Haende Platte (Trash) || Str38 Sta45 | Treffer18 Tempo38
32837 Warglaive of Azzinoth i156 Waffenhand || Agi22 Sta29 | Treffer21 | AP44 dps109.29/2.8 | Krieger, Schurke
32838 Warglaive of Azzinoth i156 Schildhand || Agi21 Sta28 | Krit23 | AP44 dps109.29/1.4 | Krieger, Schurke
32943 Swiftsteel Bludgeon i141 1H (Trash) || Treffer19 Tempo27 | AP40 dps100.33/1.5
34011 Illidari Runeshield i141 Schild (Trash) || Sta45 Int27 | SP34
34012 Shroud of the Final Stand i141 Ruecken (Trash) || Sta24 Int22 | Heil64 mp5:11
