# Schritt 3: Upgrade-Rechnung. Fuer jedes Item der Phase und jeden Spieler: DeltaDPS gegen getragenes Teil.
#
# -Phase 3 (Vorgabe) verhaelt sich exakt wie frueher: liest items.json und
# bis-listen.json, schreibt upgrades.json. -Phase 4/5 liest items-p<N>.json und
# den passenden Block aus bis-listen-phasen.json und schreibt upgrades-p<N>.json.
# Die gesamte Bewertungslogik darunter ist gemeinsam - bewusst kein zweiter
# Rechenweg, der auseinanderlaufen koennte.
param([ValidateSet(3,4,5)][int]$Phase = 3)

$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

$itemsDatei = if ($Phase -eq 3) { "items.json" } else { "items-p$Phase.json" }
if (-not (Test-Path "$base\daten\$itemsDatei")) {
    throw "$itemsDatei fehlt - erst '.\1-fetch-items.ps1 -Phase $Phase' laufen lassen."
}
$items   = Get-Content "$base\daten\$itemsDatei"  -Raw -Encoding UTF8 | ConvertFrom-Json
$players = Get-Content "$base\daten\players.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cacheRaw = Get-Content "$base\daten\cache-tooltips.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$cache = @{}
foreach ($p in $cacheRaw.PSObject.Properties) { $cache[$p.Name] = $p.Value }

# ---------------- Tooltip-Parser (identisch zu Skript 1) ----------------
function Parse-Tooltip($tt) {
    # Zeilenumbrueche normalisieren BEVOR HTML-Tags entfernt werden, damit mehrzeilige
    # Waffenwerte wie "(92.12 damage per second)" korrekt gematcht werden.
    $t = $tt -replace '[\r\n]+', ' '
    $t = $t -replace '<[^>]+>', '|'; $t = $t -replace '\|+', '|'
    # Prokk-/Nutzen-/Set-Text abschneiden, damit z.B. Dragonstrikes "Chance on hit:
    # Increases your haste rating by 212" nicht als fester Wert gezaehlt wird.
    $cut = -1
    foreach ($mark in @('Chance on hit', 'Use:', '(2) Set', '(4) Set', 'have a chance', 'chance to')) {
        $i = $t.IndexOf($mark)
        if ($i -ge 0 -and ($cut -lt 0 -or $i -lt $cut)) { $cut = $i }
    }
    if ($cut -ge 0) { $t = $t.Substring(0, $cut) }
    $st = @{}
    function Add-Stat($h,$k,$v) { if ($h.ContainsKey($k)) { $h[$k]+=$v } else { $h[$k]=$v } }
    $map = @{ Agility='Agi'; Strength='Str'; Stamina='Sta'; Intellect='Int'; Spirit='Spi' }
    foreach ($m in [regex]::Matches($t,'\+(\d+) (Agility|Strength|Stamina|Intellect|Spirit)')) {
        Add-Stat $st $map[$m.Groups[2].Value] ([int]$m.Groups[1].Value)
    }
    foreach ($m in [regex]::Matches($t,'(?:Improves|Increases)(?: your)? ([a-z ]+?) rating by \|?(\d+)')) {
        $lbl=$m.Groups[1].Value.Trim(); $v=[int]$m.Groups[2].Value
        switch -Regex ($lbl) {
            '^spell critical strike$' { Add-Stat $st 'ZKrit' $v }
            '^spell hit$'             { Add-Stat $st 'ZTreffer' $v }
            '^spell haste$'           { Add-Stat $st 'ZTempo' $v }
            '^critical strike$'       { Add-Stat $st 'Krit' $v }
            '^hit$'                   { Add-Stat $st 'Treffer' $v }
            '^haste$'                 { Add-Stat $st 'Tempo' $v }
            '^expertise$'             { Add-Stat $st 'Waffk' $v }
        }
    }
    if ($t -match 'Increases attack power by \|?(\d+)')                                      { Add-Stat $st 'AP' ([int]$Matches[1]) }
    # Allgemeines SP-Pattern (kombiniert Schaden+Heilung)
    if ($t -match 'damage and healing done by magical spells and effects by up to \|?(\d+)') { Add-Stat $st 'SP' ([int]$Matches[1]) }
    # Schul-spezifische Schadensbonus-Patterns (aeltere Items wie Frozen Shadoweave, Ritssyn etc.) - Maximum nehmen, um Doppelzählung zu vermeiden
    $schoolMax = 0
    foreach ($m in [regex]::Matches($t,'Increases damage done by (?:Shadow|Frost|Fire|Arcane|Nature|Holy) spells and effects by up to \|?(\d+)')) {
        $val = [int]$m.Groups[1].Value
        if ($val -gt $schoolMax) { $schoolMax = $val }
    }
    if ($schoolMax -gt 0) { Add-Stat $st 'SP' $schoolMax }
    # Healing-only Items herausfiltern (reiner Heilungsbonus ohne Schadensanteil = Heiler-Item)
    if ($t -match 'healing done by up to \|?(\d+)')                                          { Add-Stat $st 'Heil' ([int]$Matches[1]) }
    if ($t -match 'Restores \|?(\d+) mana per 5 sec')                                        { Add-Stat $st 'mp5' ([int]$Matches[1]) }
    if ($t -match 'ignore \|?(\d+) of your opponent')                                        { Add-Stat $st 'ArP' ([int]$Matches[1]) }
    if ($t -match '\(([\d\.]+) damage per second\)')                                          { $st['WpnDps']=[double]$Matches[1] }
    $sock=0; foreach ($c in @('Red','Yellow','Blue','Meta')) { $sock += ([regex]::Matches($t,"$c Socket")).Count }
    $st['Sockel']=$sock
    if ($t -match '\|Two-Hand\|') { $st['Is2H'] = 1 }
    if ($t -match 'Speed \|?([\d\.]+)') { $st['WpnSpeed'] = [double]$Matches[1] }
    return $st
}


# ---------------- Spec-Definitionen ----------------
# Gewichte = DPS pro Statpunkt (WoWSims, echte Neuberechnung 2026-07-27)
function NewSpec($key,$name,$armor,$rolle,$w,$gem,$spieler,$hinweis,$baseDps) {
    [pscustomobject]@{ Key=$key; Name=$name; Armor=$armor; Rolle=$rolle; W=$w; Gem=$gem; Spieler=$spieler; Hinweis=$hinweis; BaseDps=$baseDps }
}
$ARMOR_RANK = @{ ''=0; 'Cloth'=1; 'Leather'=2; 'Mail'=3; 'Plate'=4 }

# Waffenkenntnisse je Klasse (TBC)
$PROF = @{
 'Warrior' = @('Sword','Axe','Mace','Dagger','Fist Weapon','Polearm','Staff','Bow','Gun','Crossbow','Thrown')
 'Paladin' = @('Sword','Axe','Mace')
 'Hunter'  = @('Sword','Axe','Polearm','Staff','Dagger','Fist Weapon','Bow','Gun','Crossbow')
 'Rogue'   = @('Sword','Mace','Dagger','Fist Weapon','Bow','Gun','Crossbow','Thrown')
 'Shaman'  = @('Axe','Mace','Dagger','Fist Weapon','Staff')
 'Mage'    = @('Sword','Dagger','Staff','Wand')
 'Warlock' = @('Sword','Dagger','Staff','Wand')
 'Priest'  = @('Mace','Dagger','Staff','Wand')
 'Druid'   = @('Mace','Dagger','Fist Weapon','Polearm','Staff')
}
# Spieler, deren Armory-Stand im Offspec erfasst wurde -> Vergleichsbasis unbrauchbar.
# Ihre Zeilen bekommen Unsicher=true und werden im Frontend ausgeblendet.
#
# Supfreshyo (03.08.): steht als Feral-TANK im Roster, ist aber im Katzen-DPS-Set ausgeloggt -
# erkennbar am 'Wolfshead Helm' (8345), dazu Guertel der hundert Tode, Ring of Lethality und
# eine PvP-Waffe. Der Wertungsvergleich in 2-fetch-gear.ps1 greift bei ihm nicht, weil beide
# Sets Leder auf aehnlichem Itemlevel sind und der Score deshalb kaum einbricht. Dagegen steht
# dort jetzt die Verraeter-Item-Regel - die verhindert aber nur KUENFTIGE Verfaelschung, der
# gespeicherte Stand ist bereits das falsche Set.
# ENTFERNEN, sobald er einmal im Tank-Set abgerufen wurde (dann meldet 2-fetch-gear.ps1 die
# Slotwechsel und 'Wolfshead Helm' ist weg).
$UNSICHER = @('Supfreshyo')

$specs = @(
 NewSpec 'FURY' 'Furor-Krieger' 'Plate' 'Nah' @{Str=1.14;Agi=0.80;AP=0.51;Treffer=0.60;Krit=1.07;Tempo=0.99;ArP=0.19;Waffk=1.29;MH=3.12;OH=1.64} @{Stat='Str';Menge=8} @('Grotschak','Valiror') '' 2100
 NewSpec 'ARMS' 'Waffen-Krieger' 'Plate' 'Nah2H' @{Str=0.56;Agi=0.44;AP=0.24;Treffer=0.18;Krit=0.61;Tempo=0.64;ArP=0.12;Waffk=1.00;MH=3.23} @{Stat='Str';Menge=8} @('Moriamus') 'Waffenkunde aus Preset abgeleitet (Sim-Set war am Cap)' 1600
 NewSpec 'RET'  'Vergeltungs-Paladin' 'Plate' 'Nah2H' @{Str=0.83;Agi=0.63;SP=0.14;AP=0.34;Treffer=1.20;Krit=0.65;Tempo=1.01;ArP=0.08;Waffk=1.69;MH=4.44} @{Stat='Str';Menge=8} @('Kaosx') '' 1600
 NewSpec 'ENH'  'Verstaerkungs-Schamane' 'Mail' 'Nah' @{Str=0.89;Agi=0.65;Int=0.05;SP=0.24;ZTreffer=0.23;ZKrit=0.05;AP=0.40;Treffer=0.73;Krit=0.68;Tempo=0.65;ArP=0.12;Waffk=1.35;MH=3.28;OH=1.47} @{Stat='Str';Menge=8} @('Chilini','Lanity') '' 1700
 NewSpec 'ROGUE' 'Kampf-Schurke' 'Leather' 'Nah' @{Str=0.42;Agi=0.85;AP=0.38;Treffer=1.40;Krit=0.68;Tempo=0.79;ArP=0.12;Waffk=1.13;MH=3.58;OH=1.33} @{Stat='Agi';Menge=8} @('Sandycheekz') '' 2000
 NewSpec 'HUNT' 'Jaeger' 'Mail' 'Fern' @{Str=0.12;Agi=1.14;Int=0.01;AP=0.11;Treffer=1.30;Krit=0.96;Tempo=0.87;ArP=0.16;Waffk=0.42;RANGED=4.09} @{Stat='Agi';Menge=8} @('J*rgerlie','Kroenix') '' 2200
 NewSpec 'WLCK' 'Hexenmeister' 'Cloth' 'Caster' @{Int=0.33;SP=1.05;ZTreffer=1.80;ZKrit=0.81;ZTempo=1.33;mp5=0.28} @{Stat='SP';Menge=12} @('Deters','Xalessa','Simondan') '' 2100
 NewSpec 'MAGE' 'Arkan-Magier' 'Cloth' 'Caster' @{Int=1.14;SP=0.79;Spi=0.78;ZTreffer=1.70;ZKrit=0.64;ZTempo=0.16;mp5=0.42} @{Stat='SP';Menge=12} @('Sinrakss','Lupitus','Lariesel') '' 1800
 NewSpec 'SPRI' 'Schattenpriester' 'Cloth' 'Caster' @{Int=0.03;SP=0.59;Spi=0.06;ZTreffer=1.50;ZKrit=0.11;ZTempo=0.68} @{Stat='SP';Menge=12} @('Pflasterelfe') '' 1200
 NewSpec 'ELE'  'Elementar-Schamane' 'Mail' 'Caster' @{Int=0.18;SP=0.72;ZTreffer=1.60;ZKrit=0.61;ZTempo=1.25;mp5=0.01} @{Stat='SP';Menge=12} @('Exotica') '' 1500
 NewSpec 'BAL'  'Gleichgewichts-Druide' 'Leather' 'Caster' @{Int=0.44;SP=0.78;Spi=0.09;ZTreffer=1.60;ZKrit=0.53;ZTempo=1.01} @{Stat='SP';Menge=12} @('Exfreya') '' 1400
 NewSpec 'PROT_PALA' 'Schutz-Paladin' 'Plate' 'Tank' @{Sta=1.5;Armor=0.05;Def=1.0;Dodge=0.8;Parry=0.8;Block=0.8;SP=0.5;Int=0.2} @{} @() '' 100
 NewSpec 'FERAL_TANK' 'Feral-Tank' 'Leather' 'Tank' @{Sta=1.5;Armor=0.10;Agi=1.2;Dodge=0.8;AP=0.4;Krit=0.6;Waffk=1.0} @{} @() '' 100
 NewSpec 'RESTO_SHAM' 'Wiederherstellungs-Schamane' 'Mail' 'Heiler' @{Heil=1.0;mp5=2.5;ZTempo=1.2;ZKrit=0.6;Int=0.4} @{} @() '' 100
 NewSpec 'HOLY_PRIEST' 'Heilig-Priester' 'Cloth' 'Heiler' @{Heil=1.0;mp5=2.0;ZTempo=1.2;ZKrit=0.5;Int=0.4;Spi=0.6} @{} @() '' 100
 NewSpec 'RESTO_DRUID' 'Wiederherstellungs-Druide' 'Leather' 'Heiler' @{Heil=1.0;mp5=2.5;ZTempo=1.0;ZKrit=0.4;Int=0.3;Spi=0.8} @{} @() '' 100
 NewSpec 'HOLY_PALA' 'Heilig-Paladin' 'Plate' 'Heiler' @{Heil=1.0;mp5=2.5;ZTempo=1.5;ZKrit=0.8;Int=0.5} @{} @() '' 100
)

# Spielerzuordnung aus roster.json ziehen statt sie hier zu pflegen.
# (Umlaute lassen sich in einer .ps1 nicht zuverlaessig literal schreiben, in UTF-8-JSON schon.)
$roster = Get-Content "$base\roster.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$TIER   = Get-Content "$base\tier-boni.json" -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($sp in $specs) {
    $sp.Spieler = @($roster | Where-Object { $_.spec -eq $sp.Key } | ForEach-Object { $_.name })
}
Write-Output ("Specs mit Spielern belegt: " + (($specs | Where-Object { $_.Spieler.Count -gt 0 }).Count) + " von " + $specs.Count)

# ---------------- Slot-Zuordnung ----------------
$SLOTMAP = @{
 'Head'='HEAD'; 'Neck'='NECK'; 'Shoulder'='SHOULDER'; 'Chest'='CHEST'; 'Waist'='WAIST'
 'Legs'='LEGS'; 'Feet'='FEET'; 'Wrist'='WRIST'; 'Hands'='HANDS'; 'Back'='BACK'
 'Finger'='FINGER'; 'Trinket'='TRINKET'; 'Ranged'='RANGED'; 'Relic'='RANGED'
 'Main Hand'='MAIN_HAND'; 'One-Hand'='MAIN_HAND'; 'Two-Hand'='TWOHAND'
 'Off Hand'='OFF_HAND'; 'Held In Off-hand'='OFF_HAND'
}

# ---------------- Wertfunktion ----------------
$simWeights = @{}
$simWeightsFile = "$base\daten\sim-weights.json"
if (Test-Path $simWeightsFile) {
    $rawSim = Get-Content $simWeightsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $rawSim.PSObject.Properties) {
        $pWeights = @{}
        foreach ($s in $p.Value.PSObject.Properties) {
            $pWeights[$s.Name] = [double]$s.Value
        }
        $simWeights[$p.Name] = $pWeights
    }
}

# Basis-DPS des Spielers fuer die Prozentanzeige. Bevorzugt den in 7-stat-gewichte.py
# GEMESSENEN Wert (_basisDps); nur wenn der fehlt, den hartcodierten Spec-Schaetzwert.
# Vorher lief der Nenner immer gegen den Schaetzwert, waehrend der Zaehler (Delta) je
# Spieler simuliert war - fuer Kaosx 1600 statt gemessener ~1456, also rund 10 % daneben.
function Get-BasisDps($playerName, $spec) {
    if ($playerName -and $simWeights.ContainsKey($playerName)) {
        $sw = $simWeights[$playerName]
        if ($sw.ContainsKey('_basisDps')) {
            $v = [double]$sw['_basisDps']
            if ($v -gt 0) { return $v }
        }
    }
    return [double]$spec.BaseDps
}
function Test-BasisGemessen($playerName) {
    if ($playerName -and $simWeights.ContainsKey($playerName)) {
        $sw = $simWeights[$playerName]
        if ($sw.ContainsKey('_basisDps') -and [double]$sw['_basisDps'] -gt 0) { return $true }
    }
    return $false
}

function Value-Item($stats, $spec, $slotKind, $playerName=$null) {
    $w = $spec.W
    # Falls simulierte Gewichte fuer diesen Spieler existieren, diese bevorzugen
    if ($playerName -and $simWeights.ContainsKey($playerName)) {
        $sw = $simWeights[$playerName]
        # Hilfsfunktion: PowerShell ConvertFrom-Json liefert Hashtables ODER PSObjects.
        $holen = {
            param($k)
            if ($sw.PSObject.Properties[$k]) { return [double]$sw.$k }
            elseif ($sw.ContainsKey -and $sw.ContainsKey($k)) { return [double]$sw[$k] }
            return 0.0
        }

        # ★ Skalenfaktor bestimmen, BEVOR irgendetwas gemischt wird.
        # Simulierte Gewichte haengen an der absoluten DPS des Spielers und liegen deshalb je
        # Spieler auf einer anderen Skala als das statische Preset (gemessen: 0,48x bis 1,16x).
        # Wer den Preset-Wert unveraendert als Untergrenze einsetzt, mischt zwei Skalen:
        # Erikadirks Trefferwertung bekaeme das Preset-Gewicht 1,40, waehrend alles andere bei
        # ihm auf 0,48x laeuft - Treffer waere damit fast dreifach ueberbewertet. Genau das hat
        # den Regressionstest bei allen physischen Specs einbrechen lassen.
        # Der Faktor wird aus den Stats gebildet, die NICHT am Cap sind (Cap-Stats sind 0 und
        # wuerden ihn nach unten ziehen).
        $verhaeltnisse = @()
        foreach ($k in $spec.W.Keys) {
            if ($k -eq 'Treffer' -or $k -eq 'Waffk' -or $k -eq 'ZTreffer') { continue }
            $sv = & $holen $k
            $pv = [double]$spec.W[$k]
            if ($sv -gt 0 -and $pv -gt 0) { $verhaeltnisse += ($sv / $pv) }
        }
        $skala = 1.0
        if ($verhaeltnisse.Count -gt 0) {
            $sortiert = $verhaeltnisse | Sort-Object
            $skala = $sortiert[[int]($sortiert.Count / 2)]   # Median, robust gegen Ausreisser
        }

        $w = @{}
        foreach ($k in $spec.W.Keys) {
            $simVal = & $holen $k

            # Sicherheitsnetz für Cap-Stats: Um den "De-gearing"-Effekt zu verhindern, dürfen
            # Waffenkunde, Trefferwertung und Zaubertrefferwertung niemals unter ihr statisches
            # "Below-Cap"-Gewicht fallen - dieses aber auf die Skala des Spielers umgerechnet.
            if ($k -eq 'Treffer' -or $k -eq 'Waffk' -or $k -eq 'ZTreffer') {
                $w[$k] = [math]::Max($simVal, [double]$spec.W[$k] * $skala)
            } else {
                if ($simVal -le 0.0) {
                    $w[$k] = [double]$spec.W[$k] * $skala   # Fallback, ebenfalls skaliert
                } else {
                    $w[$k] = $simVal
                }
            }
        }
    }
    
    $v = 0.0
    foreach ($k in $stats.Keys) {
        if ($k -eq 'WpnDps' -or $k -eq 'Sockel' -or $k -eq 'WpnSpeed') { continue }
        if ($w.ContainsKey($k)) { $v += [double]$stats[$k] * $w[$k] }
    }
    if ($stats.ContainsKey('Sockel') -and $stats['Sockel'] -gt 0) {
        $gs = $spec.Gem.Stat
        if ($gs -and $w.ContainsKey($gs)) { $v += [double]$stats['Sockel'] * $spec.Gem.Menge * $w[$gs] }
    }
    if ($stats.ContainsKey('WpnDps')) {
        $wd = [double]$stats['WpnDps']
        $speed = 3.6
        if ($stats.ContainsKey('WpnSpeed')) { $speed = [double]$stats['WpnSpeed'] }
        
        # Waffentempo-Normierung: Nur für RET Paladin wichtig (Crusader Strike / Seal of Blood)
        if ($spec.Key -eq 'RET') {
            if ($slotKind -eq 'MAIN_HAND' -or $slotKind -eq 'OFF_HAND' -or $slotKind -eq 'TWOHAND') {
                # Normierung auf 3.6 Tempo für 2H, 2.6 Tempo für 1H/Schildhand
                $is2H = ($slotKind -eq 'TWOHAND' -or ($stats.ContainsKey('Is2H') -and $stats['Is2H'] -eq 1))
                $normSpeed = if ($is2H) { 3.6 } else { 2.6 }
                $wd = $wd * ($speed / $normSpeed)
            }
        }

        # FIX: Distanzslot zaehlt Waffenschaden NUR bei Jaegern.
        if ($slotKind -eq 'RANGED') {
            if ($w.ContainsKey('RANGED')) { $v += $wd * $w['RANGED'] }
        } elseif ($slotKind -eq 'OFF_HAND') {
            if ($w.ContainsKey('OH')) { $v += $wd * $w['OH'] }
        } elseif ($slotKind -eq 'MAIN_HAND' -or $slotKind -eq 'TWOHAND') {
            if ($w.ContainsKey('MH')) { $v += $wd * $w['MH'] }
        }
    }
    return $v
}

# Schmuckstueck-Bewertung, Methode A: statische Uptime-Approximation.
#
# Der Wert eines Schmuckstuecks steckt fast ganz in Prokks und Nutzeneffekten, die der
# Tooltip-Parser bewusst abschneidet (siehe Parse-Tooltip). Hier wird deshalb je Item ein
# Ersatz-Statblock hinterlegt, der den Prokk als Dauerwert mittelt:
#
#     Eintrag = statischer Equip-Wert  +  Prokk-Wert * Uptime
#     Uptime bei Nutzeneffekten = Wirkdauer / Abklingzeit (z.B. 20s / 120s = 16,7 %)
#
# ACHTUNG, zwei Fallen:
#  1. Der Eintrag ERSETZT den geparsten Statblock vollstaendig. Die statischen Equip-Werte
#     muessen also mit drin stehen, sonst verschwinden sie stillschweigend.
#  2. Nur Schluessel, die eine Spec auch gewichtet, zaehlen. Ein Tippfehler wie 'Ausw' statt
#     'Dodge' ergibt stumm den Wert 0 und laesst das Schmuckstueck wertlos aussehen, obwohl es
#     als bewertbar markiert ist. Der Check direkt unter dieser Tabelle faengt genau das ab.
#
# Die Kommentare nennen die Rechnung, damit sie gegen den Tooltip nachpruefbar bleibt.
$TRINKET_EFFECTS = @{
    # --- Nahkampf / Distanz ---
    28830 = @{ AP = 40; Tempo = 91 }                   # Dragonspine Trophy: 40 AP + 325 Tempo * ~28% Uptime
    32505 = @{ Treffer = 20; AP = 84; ArP = 135 }      # Madness of the Betrayer: 20 Treffer + 84 AP + 300 ArP * ~45%
    30627 = @{ Treffer = 10; Krit = 38; AP = 68 }      # Tsunami Talisman: 10 Treffer + 38 Krit + 340 AP * ~20%
    29383 = @{ AP = 118 }                              # Bloodlust Brooch: 72 AP + 278 AP * 20s/120s
    28121 = @{ Treffer = 30; ArP = 100 }               # Icon of Unyielding Courage: 30 Treffer + 600 ArP * 20s/120s
    32492 = @{ Krit = 130 }                            # Ashtongue Lethality (Schurke): 145 Krit * ~90% (Finisher-getaktet)
    32487 = @{ AP = 124 }                              # Ashtongue Swiftness (Jaeger): 275 AP * ~45% (Zielschuss-Prokk)
    30450 = @{ Treffer = 21; ArP = 400 }               # Warp-Spring Coil (Schurke): 21 Treffer + 1000 ArP * ~40%

    # --- Zauberer ---
    32483 = @{ SP = 55; ZTreffer = 25; ZTempo = 29 }   # Skull of Gul'dan: 55 SP + 25 ZAUBERTREFFER + 175 ZTempo * 20s/120s
    33829 = @{ SP = 88 }                               # Hex Shrunken Head: 53 SP + 211 SP * 20s/120s
    29370 = @{ SP = 69 }                               # Icon of the Silver Crescent: 43 SP + 155 SP * 20s/120s
    28785 = @{ SP = 70 }                               # The Lightning Capacitor: Schadensprokk, grob als 70 SP angesetzt
    32488 = @{ ZTempo = 58 }                           # Ashtongue Insight (Magier): 145 ZAUBERTEMPO * ~40%
    30626 = @{ ZKrit = 40; SP = 47.5 }                 # Sextant of Unstable Currents: 40 ZKrit + 190 SP * ~25%
    30720 = @{ ZTreffer = 12; ZKrit = 30; SP = 28 }    # Serpent-Coil Braid (Magier): + 225 SP * ~12,5% (Manastein-getaktet)
    28789 = @{ SP = 58 }                               # Eye of Magtheridon: 54 SP + Prokk nur bei Resists (am Trefferkap fast tot)

    # --- Heiler ---
    29376 = @{ Heil = 133 }                            # Essence of the Martyr: 84 Heil + 297 Heil * 20s/120s
    32496 = @{ Heil = 118; mp5 = 15 }                  # Memento of Tyrande: 118 Heil + 76 mp5 * ~20%
    28727 = @{ Int = 40; mp5 = 9 }                     # Pendant of the Violet Eye: 40 Int + gestapelte mp5, grob gemittelt
    28823 = @{ Heil = 44; mp5 = 3 }                    # Eye of Gruul: 44 Heil + seltene Manaersparnis (2% Prokk)

    # --- Tank ---
    28528 = @{ Dodge = 63 }                            # Moroes' Lucky Pocket Watch: 38 Ausweichen + 300 * 10s/120s
    32501 = @{ Def = 36; Dodge = 32; Sta = 19 }        # Shadowmoon Insignia: 36 Vert + 32 Ausw + 1750 Leben (~175 Ausd) * 20s/180s
}

# Simulierte Schmuckstueck-Werte aus 6-trinket-sim.py, falls vorhanden. Sie ersetzen die
# Naeherung oben spielerweise: dort steht je Spieler und Item bereits der fertige DPS-Unterschied
# aus einer echten Differenzsimulation, gemessen gegen sein tatsaechliches Gear.
$trinketWerte = @{}
$twFile = "$base\daten\trinket-werte.json"
if (Test-Path $twFile) {
    $raw = Get-Content $twFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $trinketWerte[$p.Name] = $p.Value }
    Write-Output ("Simulierte Schmuckstueck-Werte geladen: " + $trinketWerte.Count + " Spieler")
} else {
    Write-Output "Keine trinket-werte.json - Schmuckstuecke laufen auf der statischen Naeherung."
}

# Schutz gegen stumme Tippfehler: jeder Statschluessel oben muss von mindestens einer Spec
# gewichtet werden, sonst ist der Eintrag wirkungslos (das Schmuckstueck gilt dann als
# bewertet, kommt aber auf 0 heraus). Genau so war 'Ausw' statt 'Dodge' monatelang unbemerkt.
$knownStatKeys = @{}
foreach ($sp in $specs) { foreach ($k in $sp.W.Keys) { $knownStatKeys[$k] = $true } }
foreach ($tid in $TRINKET_EFFECTS.Keys) {
    foreach ($k in $TRINKET_EFFECTS[$tid].Keys) {
        if (-not $knownStatKeys.ContainsKey($k)) {
            Write-Warning ("TRINKET_EFFECTS[" + $tid + "]: Statschluessel '" + $k + "' wird von keiner Spec gewichtet und zaehlt daher 0.")
        }
    }
}

# Tier-5-Set-Namen je Klasse, um den aktuellen Set-Stand eines Spielers zu erkennen
$T5NAME = @{
 'Warrior'='Destroyer'; 'Paladin'='Crystalforge'; 'Hunter'='Rift Stalker'; 'Rogue'='Deathmantle'
 'Shaman'='Cataclysm'; 'Mage'='Tirisfal'; 'Warlock'='Corruptor'; 'Priest'='Avatar'; 'Druid'='Nordrassil'
}
# Mindestgeschwindigkeit der Waffenhand fuer Specs, deren Rotation auf langsame Waffen baut
$MIN_MH_SPEED = @{ 'ENH'=2.4; 'ROGUE'=2.4 }

# Statistiken der getragenen Teile vorberechnen
$wornStats = @{}
$wornIds = @{}
foreach ($pl in $players) {
    $h = @{}
    $ids = @{}
    foreach ($p in $pl.Slots.PSObject.Properties) {
        $id = [string]$p.Value
        if ($id) {
            $ids[$p.Name] = [int]$id
            if ($cache.ContainsKey($id)) {
                $itemStats = Parse-Tooltip $cache[$id].tooltip
                $idKey = [int]$id
                if ($p.Name -like 'TRINKET*' -and $TRINKET_EFFECTS.ContainsKey($idKey)) {
                    $itemStats = $TRINKET_EFFECTS[$idKey]
                }
                $h[$p.Name] = $itemStats
            }
        }
    }
    $wornStats[$pl.Name] = $h
    $wornIds[$pl.Name] = $ids
}

# Treffer-Diagnose je Spieler
$hitDiag = @{}
foreach ($pn in $wornStats.Keys) {
    $ht = 0; $ex = 0; $zh = 0
    foreach ($s in $wornStats[$pn].Keys) {
        $st = $wornStats[$pn][$s]
        if ($st.ContainsKey('Treffer'))  { $ht += $st['Treffer'] }
        if ($st.ContainsKey('Waffk'))    { $ex += $st['Waffk'] }
        if ($st.ContainsKey('ZTreffer')) { $zh += $st['ZTreffer'] }
    }
    $hitDiag[$pn] = [pscustomobject]@{ Treffer=$ht; Waffk=$ex; ZTreffer=$zh }
}

# ---------------- Upgrade-Rechnung ----------------
# Phase 3 liest weiter die alte flache Datei, damit die Ausgabe bitgleich bleibt.
# Phase 4/5 holt ihren Block aus der phasenweisen Datei; die Form darunter
# ({ SPEC = [Eintraege] }) ist in beiden Faellen dieselbe.
if ($Phase -eq 3) {
    $bisListen = Get-Content "$base\daten\bis-listen.json" -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $phasenDatei = "$base\daten\bis-listen-phasen.json"
    if (-not (Test-Path $phasenDatei)) {
        throw "bis-listen-phasen.json fehlt - erst 'python daten\scrape-bis-wowhead.py' laufen lassen."
    }
    $alleBis = Get-Content $phasenDatei -Raw -Encoding UTF8 | ConvertFrom-Json
    $bisListen = $alleBis."$Phase"
    if (-not $bisListen) { throw "bis-listen-phasen.json enthaelt keinen Block fuer Phase $Phase." }
}
$results = @()

foreach ($it in $items) {
    if (-not $it.Slot) { continue }
    if (-not $SLOTMAP.ContainsKey($it.Slot)) { continue }
    $slotKey = $SLOTMAP[$it.Slot]
    $istats = @{}
    foreach ($p in $it.Stats.PSObject.Properties) { $istats[$p.Name] = $p.Value }
    
    # Ueberschreibe Stats, falls es ein unterstuetztes Schmuckstueck ist
    $idKey = [int]$it.Id
    if ($slotKey -eq 'TRINKET' -and $TRINKET_EFFECTS.ContainsKey($idKey)) {
        $istats = $TRINKET_EFFECTS[$idKey]
    }
    
    # Feral-Attackpower auf Waffen ignorieren wir
    if ($it.FormOnly -and $it.Slot -ne 'Two-Hand') { continue }

    foreach ($spec in $specs) {
        # Rollenspezifischer Filter
        $isHealerSpec = ($spec.Rolle -eq 'Heiler')
        $isTankSpec = ($spec.Rolle -eq 'Tank')
        $isDpsSpec = ($spec.Rolle -ne 'Heiler' -and $spec.Rolle -ne 'Tank')

        # Heiler-Items nur fuer Heiler zulassen, Heiler wollen auch nur Heilungs-Items
        $hasHeal = $istats.ContainsKey('Heil') -or $it.Name -like "*Pendant of Quiet* " -or $it.Name -like "*Signet of Yin*"
        if ($hasHeal -and -not $isHealerSpec) { continue }
        if ($isHealerSpec -and -not $hasHeal -and $slotKey -ne 'FINGER' -and $slotKey -ne 'TRINKET' -and $slotKey -ne 'BACK' -and $slotKey -ne 'NECK') {
            # Heiler koennen manche Caster-Umhaenge, Ringe etc. tragen, aber keine reinen DPS-Rüstungsteile/Waffen
            continue 
        }

        # Schilde nur fuer Prot-Paladin zulassen
        if (($it.Slot -eq 'Shield' -or $it.Armor -eq 'Shield') -and $spec.Key -ne 'PROT_PALA') { continue }

        # Ruestungsklasse
        if ($it.Armor -ne '') {
            if ($ARMOR_RANK[$it.Armor] -gt $ARMOR_RANK[$spec.Armor]) { continue }
        }
        
        $klasse = switch ($spec.Key) {
            'FURY' {'Warrior'} 'ARMS' {'Warrior'} 'RET' {'Paladin'} 'ENH' {'Shaman'}
            'ROGUE' {'Rogue'} 'HUNT' {'Hunter'} 'WLCK' {'Warlock'} 'MAGE' {'Mage'}
            'SPRI' {'Priest'} 'ELE' {'Shaman'} 'BAL' {'Druid'}
            'PROT_PALA' {'Paladin'} 'FERAL_TANK' {'Druid'}
            'RESTO_SHAM' {'Shaman'} 'HOLY_PRIEST' {'Priest'} 'RESTO_DRUID' {'Druid'} 'HOLY_PALA' {'Paladin'}
        }
        
        # Klassenbindung des Items
        if ($it.Classes -ne '' -and $it.Classes -ne $null) {
            if ($it.Classes -notmatch $klasse) { continue }
        }
        # Waffenkenntnis der Klasse
        if ($it.WeaponType -ne '' -and $it.WeaponType -ne $null) {
            if (-not ($PROF[$klasse] -contains $it.WeaponType)) { continue }
        }
        # Waffenhand zu schnell fuer Rotationen, die auf langsame Waffen bauen
        if ($slotKey -eq 'MAIN_HAND' -and $MIN_MH_SPEED.ContainsKey($spec.Key)) {
            if ($istats.ContainsKey('WpnSpeed') -and [double]$istats['WpnSpeed'] -lt $MIN_MH_SPEED[$spec.Key]) { continue }
        }
        # Waffenregeln nach Rolle
        if ($slotKey -eq 'TWOHAND' -and ($spec.Rolle -eq 'Nah' -or $spec.Rolle -eq 'Caster' -or $spec.Rolle -eq 'Heiler')) { continue }
        if ($slotKey -eq 'MAIN_HAND' -and $spec.Rolle -eq 'Nah2H') { continue }
        if ($slotKey -eq 'OFF_HAND' -and $spec.Rolle -eq 'Nah2H') { continue }
        # Jaeger: Distanzslot nur echte Schusswaffen, kein Zauberstab
        if ($spec.Rolle -eq 'Fern' -and $slotKey -eq 'RANGED') {
            if (-not (@('Bow','Gun','Crossbow') -contains $it.WeaponType)) { continue }
        }

        # Jetzt Upgrades pruefen
        foreach ($pn in $spec.Spieler) {
            if (-not $wornStats.ContainsKey($pn)) { continue }
            $ws = $wornStats[$pn]
            $curSlot = $slotKey

            # Pruefen ob Item in der BiS-Liste des Specs ist
            $bisItem = $null
            if ($bisListen.$($spec.Key)) {
                $bisItem = $bisListen.$($spec.Key) | Where-Object { $_.Id -eq $it.Id } | Select-Object -First 1
            }

            # Prüfen ob bereits ausgerüstet
            $alreadyEquipped = $false
            $pIds = $wornIds[$pn]
            if ($slotKey -eq 'FINGER' -or $slotKey -eq 'TRINKET') {
                $a = $slotKey + '_1'; $b = $slotKey + '_2'
                if (($pIds.ContainsKey($a) -and $pIds[$a] -eq $it.Id) -or ($pIds.ContainsKey($b) -and $pIds[$b] -eq $it.Id)) { $alreadyEquipped = $true }
            } else {
                if ($pIds.ContainsKey($slotKey) -and $pIds[$slotKey] -eq $it.Id) { $alreadyEquipped = $true }
            }

            if ($alreadyEquipped) {
                # Bereits ausgerüstete Items nur in der Liste führen, wenn sie in der BiS-Liste des Specs sind
                if (-not $bisItem) { continue }
                $delta = 0.0
            } else {
                # Falls Tank oder Heiler: Stat-Zuwachs gerechnet über Tank/Heil-Multiplikatoren + BiS-Listen-Bonus
                if ($isTankSpec -or $isHealerSpec) {
                    if (-not $bisItem) { continue } # Nicht in der BiS-Liste des Tanks/Heilers -> nicht anzeigen

                    # 1. Stat-basierten Score berechnen
                    $newVal = Value-Item $istats $spec $slotKey

                    # 2. Score des aktuell getragenen Items bestimmen
                    $curVal = 0.0; $curItem = $null; $curItemId = 0
                    if ($slotKey -eq 'FINGER' -or $slotKey -eq 'TRINKET') {
                        $a = $slotKey + '_1'; $b = $slotKey + '_2'
                        $va = 0.0; $vb = 0.0
                        if ($ws.ContainsKey($a)) { $va = Value-Item $ws[$a] $spec $slotKey }
                        if ($ws.ContainsKey($b)) { $vb = Value-Item $ws[$b] $spec $slotKey }
                        if ($va -le $vb) { 
                            $curVal = $va; $curSlot = $a 
                            if ($ws.ContainsKey($a)) { $curItem = $ws[$a]; $curItemId = $pIds[$a] }
                        } else { 
                            $curVal = $vb; $curSlot = $b 
                            if ($ws.ContainsKey($b)) { $curItem = $ws[$b]; $curItemId = $pIds[$b] }
                        }
                    } elseif ($slotKey -eq 'TWOHAND') {
                        $va = 0.0; $vb = 0.0
                        if ($ws.ContainsKey('MAIN_HAND')) { $va = Value-Item $ws['MAIN_HAND'] $spec 'MAIN_HAND' }
                        if ($ws.ContainsKey('OFF_HAND'))  { $vb = Value-Item $ws['OFF_HAND']  $spec 'OFF_HAND' }
                        $curVal = $va + $vb; $curSlot = 'MAIN_HAND+OFF_HAND'
                    } elseif ($slotKey -eq 'OFF_HAND') {
                        if ($ws.ContainsKey('MAIN_HAND') -and $ws['MAIN_HAND'].ContainsKey('Is2H')) { continue }
                        if ($ws.ContainsKey($slotKey)) { 
                            $curVal = Value-Item $ws[$slotKey] $spec $slotKey 
                            $curItem = $ws[$slotKey]; $curItemId = $pIds[$slotKey]
                        }
                    } else {
                        if ($ws.ContainsKey($slotKey)) { 
                            $curVal = Value-Item $ws[$slotKey] $spec $slotKey 
                            $curItem = $ws[$slotKey]; $curItemId = $pIds[$slotKey]
                        }
                    }

                    # 3. BiS-Bonus-Punkte bestimmen
                    $bisBonus = 0
                    if ($bisItem) {
                        if ($bisItem.Rank -eq 0) { $bisBonus += 100 } # BiS #1 bekommt 100 Punkte
                        else { $bisBonus += 50 } # Alternative bekommt 50 Punkte
                    }

                    # Getragenes Item in BiS-Liste? Wenn ja, Bonus abziehen
                    if ($curItemId -and $bisListen.$($spec.Key)) {
                        $curBis = $bisListen.$($spec.Key) | Where-Object { $_.Id -eq $curItemId } | Select-Object -First 1
                        if ($curBis) {
                            if ($curBis.Rank -eq 0) { $bisBonus -= 100 }
                            else { $bisBonus -= 50 }
                        }
                    }

                    $delta = ($newVal - $curVal) + $bisBonus
                    if ($delta -le 0) { $delta = 0.1 } # Immer anzeigen, wenn es in der BiS-Liste ist
                } else {
                    # Normaler DPS-Raider
                    $newVal = Value-Item $istats $spec $slotKey $pn
                    $curVal = 0.0
                    if ($slotKey -eq 'FINGER' -or $slotKey -eq 'TRINKET') {
                        $a = $slotKey + '_1'; $b = $slotKey + '_2'
                        $va = 0.0; $vb = 0.0
                        if ($ws.ContainsKey($a)) { $va = Value-Item $ws[$a] $spec $slotKey $pn }
                        if ($ws.ContainsKey($b)) { $vb = Value-Item $ws[$b] $spec $slotKey $pn }
                        if ($va -le $vb) { $curVal = $va; $curSlot = $a } else { $curVal = $vb; $curSlot = $b }
                    } elseif ($slotKey -eq 'TWOHAND') {
                        $va = 0.0; $vb = 0.0
                        if ($ws.ContainsKey('MAIN_HAND')) { $va = Value-Item $ws['MAIN_HAND'] $spec 'MAIN_HAND' $pn }
                        if ($ws.ContainsKey('OFF_HAND'))  { $vb = Value-Item $ws['OFF_HAND']  $spec 'OFF_HAND' $pn }
                        $curVal = $va + $vb; $curSlot = 'MAIN_HAND+OFF_HAND'
                    } elseif ($slotKey -eq 'OFF_HAND') {
                        if ($ws.ContainsKey('MAIN_HAND') -and $ws['MAIN_HAND'].ContainsKey('Is2H')) { continue }
                        if ($ws.ContainsKey($slotKey)) { $curVal = Value-Item $ws[$slotKey] $spec $slotKey $pn }
                    } else {
                        if ($ws.ContainsKey($slotKey)) { $curVal = Value-Item $ws[$slotKey] $spec $slotKey $pn }
                    }
                    $delta = $newVal - $curVal
                    if ($delta -le 0) { continue }
                }
            }
            # Set-Stand: wie viele T5-Teile traegt der Spieler aktuell?
            $t5 = 0
            $t5n = $T5NAME[$klasse]
            if ($t5n) {
                foreach ($sn in $ws.Keys) {
                    $wid = $null
                    foreach ($pp in ($players | Where-Object { $_.Name -eq $pn })) {
                        $wid = $pp.Slots.PSObject.Properties[$sn].Value
                    }
                    if ($wid -and $cache.ContainsKey([string]$wid)) {
                        if ($cache[[string]$wid].name -like ("*" + $t5n + "*")) { $t5++ }
                    }
                }
            }
            $nichtBewertbar = ($slotKey -eq 'TRINKET' -and -not $TRINKET_EFFECTS.ContainsKey([int]$it.Id))
            $hinweis = ""
            if ($slotKey -eq 'TRINKET') {
                # Gemessener Wert schlaegt Naeherung: Liegt fuer diesen Spieler und dieses
                # Schmuckstueck ein simulierter Wert vor (6-trinket-sim.py), wird der DIREKT als
                # Delta verwendet - er ist bereits ein DPS-Unterschied und muss nicht ueber
                # Statgewichte gerechnet werden. Die Naeherung bleibt nur der Rueckfall.
                $simWert = $null
                if ($trinketWerte.ContainsKey($pn)) {
                    $tw = $trinketWerte[$pn]
                    $idStr = [string]$it.Id
                    if ($tw.PSObject.Properties[$idStr]) { $simWert = [double]$tw.$idStr }
                }
                if ($null -ne $simWert) {
                    # Die Sim liefert auch negative Werte (das Schmuckstueck waere ein Rueckschritt).
                    # Die gehoeren nicht in eine Upgrade-Liste - die uebrige Kette filtert solche
                    # Zeilen weiter oben mit '$delta -le 0 { continue }' weg, was hier aber schon
                    # gelaufen ist. Deshalb hier nachziehen. 0 bleibt stehen: das sind die bereits
                    # getragenen Teile, die als "Bereits ausgeruestet" sichtbar bleiben sollen.
                    if ($simWert -lt 0) { continue }
                    $delta = $simWert
                    $nichtBewertbar = $false
                    $hinweis = "Simuliert (WoWSims-Differenzsimulation)"
                } elseif ($nichtBewertbar) {
                    $hinweis = "Schmuck: Prokk- und Nutzeneffekte sind nicht bewertbar"
                } else {
                    $hinweis = "Statische Uptime-Approximation (Beta)"
                }
            }
            elseif ($it.Quelle -eq 'T6') {
                # Wie viele T6-Teile traegt er schon?
                $t6 = 0
                $t6n = if ($TIER.$klasse) { $TIER.$klasse.t6 } else { $null }
                if ($t6n) {
                    foreach ($sn in $ws.Keys) {
                        $wid = $null
                        foreach ($pp in ($players | Where-Object { $_.Name -eq $pn })) { $wid = $pp.Slots.PSObject.Properties[$sn].Value }
                        if ($wid -and $cache.ContainsKey([string]$wid)) {
                            if ($cache[[string]$wid].name -like ("*" + $t6n + "*")) { $t6++ }
                        }
                    }
                }
                # Ersetzt dieses Teil ein T5-Stueck? Dann sinkt der T5-Zaehler.
                $ersetztT5 = $false
                if ($ws.ContainsKey($slotKey)) {
                    $wid = $null
                    foreach ($pp in ($players | Where-Object { $_.Name -eq $pn })) { $wid = $pp.Slots.PSObject.Properties[$slotKey].Value }
                    $t5n = if ($TIER.$klasse) { $TIER.$klasse.t5 } else { $null }
                    if ($wid -and $t5n -and $cache.ContainsKey([string]$wid)) {
                        if ($cache[[string]$wid].name -like ("*" + $t5n + "*")) { $ersetztT5 = $true }
                    }
                }
                $t5neu = if ($ersetztT5) { $t5 - 1 } else { $t5 }
                $t6neu = $t6 + 1
                $teile = @()
                $teile += ("T5 " + $t5 + "->" + $t5neu + ", T6 " + $t6 + "->" + $t6neu)
                if ($TIER.$klasse) {
                    $tb = $TIER.$klasse
                    if ($t5 -ge 4 -and $t5neu -lt 4) { $teile += ("VERLIERT T5-4er: " + $tb.t5_4.text + " [" + $tb.t5_4.wert + "]") }
                    if ($t5 -ge 2 -and $t5neu -lt 2) { $teile += ("VERLIERT T5-2er: " + $tb.t5_2.text + " [" + $tb.t5_2.wert + "]") }
                    # Was bleibt erhalten? Nur nennen, wenn es fuer DPS ueberhaupt zaehlt.
                    if ($t5neu -ge 4 -and $tb.t5_4.wert -ne 'keiner') { $teile += ("behaelt T5-4er: " + $tb.t5_4.text + " [" + $tb.t5_4.wert + "]") }
                    if ($t5neu -ge 2 -and $t5neu -lt 4 -and $tb.t5_2.wert -ne 'keiner') { $teile += ("behaelt T5-2er: " + $tb.t5_2.text + " [" + $tb.t5_2.wert + "]") }
                    if ($t6neu -eq 2) { $teile += ("SCHALTET T6-2er FREI: " + $tb.t6_2.text + " [" + $tb.t6_2.wert + "]") }
                    if ($t6neu -eq 4) { $teile += ("SCHALTET T6-4er FREI: " + $tb.t6_4.text + " [" + $tb.t6_4.wert + "]") }
                }
                $hinweis = "Set-Boni nicht in der Zahl enthalten. " + ($teile -join " -- ")
            }
            $results += [pscustomobject]@{
                ItemId=$it.Id; Item=$it.Name; Boss=$it.Boss; Quelle=$it.Quelle; Ilvl=$it.Ilvl
                Slot=$it.Slot; Armor=$it.Armor
                Spec=$spec.Name; SpecKey=$spec.Key; Spieler=$pn
                Delta=[math]::Round($delta,1); Ersetzt=$curSlot
                Pct = if ($isTankSpec -or $isHealerSpec) {
                    $statDelta = $newVal - $curVal
                    if ($statDelta -lt 0) { $statDelta = 0.0 }
                    $totalWorn = 0.0
                    foreach ($slotName in $ws.Keys) {
                        $slotKind = $slotName
                        if ($slotName -like 'FINGER_*') { $slotKind = 'FINGER' }
                        if ($slotName -like 'TRINKET_*') { $slotKind = 'TRINKET' }
                        $totalWorn += Value-Item $ws[$slotName] $spec $slotKind
                    }
                    if ($totalWorn -le 0) { $totalWorn = 1000.0 }
                    [math]::Round(($statDelta / $totalWorn) * 100, 2)
                } else {
                    [math]::Round(($delta / (Get-BasisDps $pn $spec)) * 100, 2)
                }
                # Bezugsgroesse der Prozentzahl mitgeben. Sie bedeutet je Rolle etwas
                # anderes (DPS: Anteil an der Gesamt-DPS, Tank/Heiler: Anteil am
                # Ausruestungswert) - ohne diese Angabe steht auf der Seite zweimal
                # dasselbe Prozentzeichen fuer zwei verschiedene Bezugsgroessen.
                PctBasis = if ($isTankSpec -or $isHealerSpec) { 'gear' } else { 'dps' }
                BasisDps = if ($isTankSpec -or $isHealerSpec) { 0 } else { [math]::Round((Get-BasisDps $pn $spec),0) }
                BasisSim = if ($isTankSpec -or $isHealerSpec) { $false } else { (Test-BasisGemessen $pn) }
                Unsicher=($UNSICHER -contains $pn)
                Speed=$(if ($istats.ContainsKey('WpnSpeed')) { $istats['WpnSpeed'] } else { 0 })
                ProSchlag=$(if ($istats.ContainsKey('WpnSpeed') -and $istats.ContainsKey('WpnDps')) { [math]::Round([double]$istats['WpnDps'] * [double]$istats['WpnSpeed'],0) } else { 0 })
                Rolle=$spec.Rolle
                Hinweis=$hinweis
                NichtBewertbar=$nichtBewertbar
                T5Teile=$t5
            }
        }
    }
}

# ---------------- Sonderfall: Warglaive-Paar ----------------
# Der 2er-Bonus greift nur mit beiden Klingen, deshalb muss das Paar als eine
# Entscheidung gerechnet werden. Bonus laut Tooltip:
#   - Nahkampfangriffe koennen Tempowertung um 450 fuer 10 s erhoehen (45 s Abklingzeit)
#   - +200 Angriffskraft gegen Daemonen
$WG_MH = 32837; $WG_OH = 32838
$wgMh = $items | Where-Object { $_.Id -eq $WG_MH }
$wgOh = $items | Where-Object { $_.Id -eq $WG_OH }
if ($wgMh -and $wgOh) {
    $mhStats = @{}; foreach ($p in $wgMh.Stats.PSObject.Properties) { $mhStats[$p.Name] = $p.Value }
    $ohStats = @{}; foreach ($p in $wgOh.Stats.PSObject.Properties) { $ohStats[$p.Name] = $p.Value }
    $uptime = 10.0 / 45.0     # Prokk-Laufzeit geteilt durch Abklingzeit
    foreach ($spec in $specs) {
        if ($spec.Rolle -ne 'Nah') { continue }                       # nur Dual-Wield-Specs
        $kl = switch ($spec.Key) { 'FURY' {'Warrior'} 'ROGUE' {'Rogue'} default {''} }
        if ($kl -eq '') { continue }
        $w = $spec.W
        $bonusTempo  = 450.0 * $uptime * $(if ($w.ContainsKey('Tempo')) { $w['Tempo'] } else { 0 })
        $bonusAP     = 200.0 * $(if ($w.ContainsKey('AP')) { $w['AP'] } else { 0 })
        $bonus       = $bonusTempo + $bonusAP
        foreach ($pn in $spec.Spieler) {
            if (-not $wornStats.ContainsKey($pn)) { continue }
            $ws = $wornStats[$pn]
            $neu = (Value-Item $mhStats $spec 'MAIN_HAND') + (Value-Item $ohStats $spec 'OFF_HAND') + $bonus
            $alt = 0.0
            if ($ws.ContainsKey('MAIN_HAND')) { $alt += Value-Item $ws['MAIN_HAND'] $spec 'MAIN_HAND' }
            if ($ws.ContainsKey('OFF_HAND'))  { $alt += Value-Item $ws['OFF_HAND']  $spec 'OFF_HAND' }
            $d = $neu - $alt
            if ($d -le 0) { continue }
            $results += [pscustomobject]@{
                ItemId=$WG_MH; Item="Warglaives of Azzinoth (Paar)"; Boss="Illidan Sturmgrimm"; Quelle="Raid"; Ilvl=156
                Slot="Waffenpaar"; Armor=""
                Spec=$spec.Name; SpecKey=$spec.Key; Spieler=$pn
                Delta=[math]::Round($d,1); Ersetzt="MAIN_HAND+OFF_HAND"
                Pct=[math]::Round(($d / (Get-BasisDps $pn $spec)) * 100, 2)
                PctBasis='dps'
                BasisDps=[math]::Round((Get-BasisDps $pn $spec),0)
                BasisSim=(Test-BasisGemessen $pn)
                Unsicher=($UNSICHER -contains $pn)
                Speed=0; ProSchlag=0; Rolle=$spec.Rolle
                Hinweis=("beide Klingen zusammen, inkl. 2er-Bonus (+" + [math]::Round($bonus,0) + " DPS: 450 Tempo zu " + [math]::Round($uptime*100,0) + " % Laufzeit, dazu 200 AP gegen Daemonen)")
                NichtBewertbar=$false; T5Teile=0
            }
        }
    }
}

Write-Output ("Upgrade-Kombinationen berechnet: " + $results.Count)
$zielUpgrades = if ($Phase -eq 3) { "upgrades.json" } else { "upgrades-p$Phase.json" }
$results | ConvertTo-Json -Depth 4 | Out-File "$base\daten\$zielUpgrades" -Encoding utf8

Write-Output ""
Write-Output "--- Treffer-/Waffenkunde-Diagnose (nur aus Items, ohne Sockel/Verzauberung/Talente) ---"
foreach ($pn in ($hitDiag.Keys | Sort-Object)) {
    $d = $hitDiag[$pn]
    Write-Output ("{0,-14} Treffer {1,4}  Waffenkunde {2,3}  Zaubertreffer {3,3}" -f $pn,$d.Treffer,$d.Waffk,$d.ZTreffer)
}

Write-Output ""
Write-Output "--- Top 25 Einzel-Upgrades (ohne Offspec-Spieler) ---"
$results | Where-Object { -not $_.Unsicher } | Sort-Object Delta -Descending | Select-Object -First 25 | ForEach-Object {
    Write-Output ("{0,7:N1} DPS  {1,-13} {2,-34} {3,-22} ({4})" -f $_.Delta, $_.Spieler, $_.Item, $_.Boss, $_.Slot)
}
Write-Output ""
Write-Output "--- Groesster Hebel je Spieler ---"
$results | Where-Object { -not $_.Unsicher } | Group-Object Spieler | ForEach-Object {
    $b = $_.Group | Sort-Object Delta -Descending | Select-Object -First 1
    [pscustomobject]@{ Spieler=$_.Name; Delta=$b.Delta; Item=$b.Item; Boss=$b.Boss }
} | Sort-Object Delta -Descending | ForEach-Object {
    Write-Output ("{0,-13} {1,6:N1} DPS  {2,-34} {3}" -f $_.Spieler, $_.Delta, $_.Item, $_.Boss)
}
