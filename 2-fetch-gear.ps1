# Schritt 2: Ausruestung der Raider live vom Armory holen, Aenderungen melden, Item-Werte nachladen
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot
$cacheFile = "$base\daten\cache-tooltips.json"
$plFile    = "$base\daten\players.json"

$roster = Get-Content "$base\roster.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# vorherigen Stand fuer den Vergleich merken
$alt = @{}
if (Test-Path $plFile) {
    foreach ($p in (Get-Content $plFile -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        $h = @{}
        foreach ($s in $p.Slots.PSObject.Properties) { $h[$s.Name] = $s.Value }
        $alt[$p.Name] = $h
    }
}

# Der Armory braucht echte UTF-8-Bytes (sonst finden Namen mit Umlaut nichts),
# lehnt aber ein "charset=utf-8" im Content-Type mit HTTP 400 ab. Deshalb
# ByteArrayContent mit explizit gesetztem, nacktem Header statt Invoke-RestMethod.
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
function Get-Equipment($name) {
    $body  = @{ region="eu"; realm="thunderstrike"; name=$name; flavor="tbc-anniversary" } | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $c = New-Object System.Net.Http.ByteArrayContent(,$bytes)
    $c.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/json")
    $resp = $http.PostAsync("https://classic-armory.org/api/v1/character/equipment", $c).Result
    if ([int]$resp.StatusCode -ne 200) { return $null }
    return ($resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json)
}

# Lade vorhandene Tooltips für die Slot-Ermittlung
$cache = @{}
if (Test-Path $cacheFile) {
    $raw = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $cache[$p.Name] = $p.Value }
}

$rawPlayers = @()
$fehler  = @()
foreach ($r in $roster) {
    try { $resp = Get-Equipment $r.name }
    catch { $fehler += ($r.name + " (Abruf)"); continue }
    if (-not $resp -or -not $resp.equipment) { $fehler += ($r.name + " (keine Daten)"); continue }
    
    # Hole alle angelegten Item-IDs flach ab
    $itemIds = @()
    foreach ($e in $resp.equipment) {
        if ($e.item -and $e.item.id -gt 0) {
            $itemIds += [int]$e.item.id
        }
    }
    $rawPlayers += [pscustomobject]@{ Name = $r.name; Spec = $r.spec; ItemIds = $itemIds }
}
Write-Output ("Abgerufen: " + $rawPlayers.Count + " von " + $roster.Count)
if ($fehler.Count) { Write-Output ("Fehlgeschlagen: " + ($fehler -join ", ")) }

# Sicherheitsnetz
$minErforderlich = [Math]::Ceiling($roster.Count * 0.5)
if ($rawPlayers.Count -lt $minErforderlich) {
    Write-Output ""
    Write-Output "[ABBRUCH] Nur $($rawPlayers.Count) von $($roster.Count) Spielern abgerufen (Minimum: $minErforderlich)."
    Write-Output "          Armory möglicherweise nicht erreichbar. Alte players.json wird NICHT überschrieben."
    exit 0
}

# Tooltips fuer alle neuen Item-IDs nachladen
$neu = 0
foreach ($p in $rawPlayers) {
    foreach ($id in $p.ItemIds) {
        $k = [string]$id
        if ($cache.ContainsKey($k)) { continue }
        try {
            $t = Invoke-RestMethod -Uri ("https://nether.wowhead.com/tbc/tooltip/item/$k" + "?locale=0") -TimeoutSec 25
            $cache[$k] = [pscustomobject]@{ name = $t.name; tooltip = $t.tooltip }
            $neu++
        } catch { }
    }
}
$cache | ConvertTo-Json -Depth 4 -Compress | Out-File $cacheFile -Encoding utf8
Write-Output ("Neue Item-Tooltips geladen: $neu")

# Slot-Mapping-Tabelle anhand des Tooltip-Texts
$players = @()
foreach ($p in $rawPlayers) {
    $slots = @{}
    $fingerCount = 1
    $trinketCount = 1
    
    foreach ($id in $p.ItemIds) {
        $k = [string]$id
        if (-not $cache.ContainsKey($k)) { continue }
        
        $tooltipText = $cache[$k].tooltip -replace '[\r\n]+', ' '
        $tooltipText = $tooltipText -replace '<[^>]+>', '|'
        
        # Finde Slot im Tooltip
        $detectedSlot = $null
        foreach ($s in @('Head','Neck','Shoulder','Chest','Waist','Legs','Feet','Wrist','Hands','Finger','Trinket','Back','Main Hand','Off Hand','One-Hand','Two-Hand','Ranged','Relic','Held In Off-hand','Shield','Thrown')) {
            if ($tooltipText -match ("\|" + [regex]::Escape($s) + "\|")) {
                $detectedSlot = $s
                break
            }
        }
        
        if (-not $detectedSlot) { continue }
        
        # Sortiere in den richtigen Slot-Key ein
        $slotKey = switch ($detectedSlot) {
            'Head' { 'HEAD' }
            'Neck' { 'NECK' }
            'Shoulder' { 'SHOULDER' }
            'Chest' { 'CHEST' }
            'Waist' { 'WAIST' }
            'Legs' { 'LEGS' }
            'Feet' { 'FEET' }
            'Wrist' { 'WRIST' }
            'Hands' { 'HANDS' }
            'Back' { 'BACK' }
            'Finger' {
                $sk = "FINGER_$fingerCount"
                $fingerCount++
                $sk
            }
            'Trinket' {
                $sk = "TRINKET_$trinketCount"
                $trinketCount++
                $sk
            }
            'Main Hand' { 'MAIN_HAND' }
            'One-Hand'  { 'MAIN_HAND' }
            'Two-Hand'  { 'MAIN_HAND' }
            'Off Hand'  { 'OFF_HAND' }
            'Held In Off-hand' { 'OFF_HAND' }
            'Shield'    { 'OFF_HAND' }
            'Ranged'    { 'RANGED' }
            'Relic'     { 'RANGED' }
            'Thrown'    { 'RANGED' }
        }
        
        if ($slotKey) {
            $slots[$slotKey] = $id
        }
    }
    
    $players += [pscustomobject]@{ Name = $p.Name; Spec = $p.Spec; Slots = $slots }
}

# --- Generischer Plausibilitätscheck für alle Spieler ---
$SPEC_WEIGHTS = @{
    'FURY' = @{Str=1.14;Agi=0.80;AP=0.51;Treffer=0.60;Krit=1.07;Tempo=0.99;ArP=0.19;Waffk=1.29;MH=3.12;OH=1.64}
    'ARMS' = @{Str=0.56;Agi=0.44;AP=0.24;Treffer=0.18;Krit=0.61;Tempo=0.64;ArP=0.12;Waffk=1.00;MH=3.23}
    'RET'  = @{Str=0.83;Agi=0.63;SP=0.14;AP=0.34;Treffer=0.00;Krit=0.65;Tempo=1.01;ArP=0.08;Waffk=1.69;MH=4.44}
    'ENH'  = @{Str=0.89;Agi=0.65;Int=0.05;SP=0.24;ZTreffer=0.23;ZKrit=0.05;AP=0.40;Treffer=0.73;Krit=0.68;Tempo=0.65;ArP=0.12;Waffk=1.35;MH=3.28;OH=1.47}
    'ROGUE' = @{Str=0.42;Agi=0.85;AP=0.38;Treffer=0.00;Krit=0.68;Tempo=0.79;ArP=0.12;Waffk=1.13;MH=3.58;OH=1.33}
    'HUNT' = @{Str=0.12;Agi=1.14;Int=0.01;AP=0.11;Treffer=0.00;Krit=0.96;Tempo=0.87;ArP=0.16;Waffk=0.42;RANGED=4.09}
    'WLCK' = @{Int=0.33;SP=1.05;ZTreffer=0.00;ZKrit=0.81;ZTempo=1.33;mp5=0.28}
    'MAGE' = @{Int=1.14;SP=0.79;Spi=0.78;ZTreffer=0.16;ZKrit=0.64;ZTempo=0.16;mp5=0.42}
    'SPRI' = @{Int=0.03;SP=0.59;Spi=0.06;ZTreffer=0.00;ZKrit=0.11;ZTempo=0.68}
    'ELE'  = @{Int=0.18;SP=0.72;ZTreffer=0.06;ZKrit=0.61;ZTempo=1.25;mp5=0.01}
    'BAL'  = @{Int=0.44;SP=0.78;Spi=0.09;ZTreffer=0.04;ZKrit=0.53;ZTempo=1.01}
    'PROT_PALA' = @{Sta=1.5;Armor=0.05;Def=1.0;Dodge=0.8;Parry=0.8;Block=0.8;SP=0.5;Int=0.2}
    'FERAL_TANK' = @{Sta=1.5;Armor=0.10;Agi=1.2;Dodge=0.8;AP=0.4;Krit=0.6;Waffk=1.0}
    'RESTO_SHAM' = @{Heil=1.0;mp5=2.5;ZTempo=1.2;ZKrit=0.6;Int=0.4}
    'HOLY_PRIEST' = @{Heil=1.0;mp5=2.0;ZTempo=1.2;ZKrit=0.5;Int=0.4;Spi=0.6}
    'RESTO_DRUID' = @{Heil=1.0;mp5=2.5;ZTempo=1.0;ZKrit=0.4;Int=0.3;Spi=0.8}
    'HOLY_PALA' = @{Heil=1.0;mp5=2.5;ZTempo=1.5;ZKrit=0.8;Int=0.5}
}

function Parse-Tooltip($tt) {
    $t = $tt -replace '[\r\n]+', ' '
    $t = $t -replace '<[^>]+>', '|'; $t = $t -replace '\|+', '|'
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
    if ($t -match 'Increases attack power by \|?(\d+)') { Add-Stat $st 'AP' ([int]$Matches[1]) }
    if ($t -match 'damage and healing done by magical spells and effects by up to \|?(\d+)') { Add-Stat $st 'SP' ([int]$Matches[1]) }
    $schoolMax = 0
    foreach ($m in [regex]::Matches($t,'Increases damage done by (?:Shadow|Frost|Fire|Arcane|Nature|Holy) spells and effects by up to \|?(\d+)')) {
        $val = [int]$m.Groups[1].Value
        if ($val -gt $schoolMax) { $schoolMax = $val }
    }
    if ($schoolMax -gt 0) { Add-Stat $st 'SP' $schoolMax }
    if ($t -match 'healing done by up to \|?(\d+)') { Add-Stat $st 'Heil' ([int]$Matches[1]) }
    if ($t -match 'Restores \|?(\d+) mana per 5 sec') { Add-Stat $st 'mp5' ([int]$Matches[1]) }
    if ($t -match 'ignore \|?(\d+) of your opponent') { Add-Stat $st 'ArP' ([int]$Matches[1]) }
    if ($t -match '\(([\d\.]+) damage per second\)') { $st['WpnDps']=[double]$Matches[1] }
    if ($t -match 'Speed \|?([\d\.]+)') { $st['WpnSpeed'] = [double]$Matches[1] }
    return $st
}

function Get-GearScore($slots, $specKey) {
    $specWeights = $SPEC_WEIGHTS[$specKey]
    if (-not $specWeights) { return 0.0 }
    $score = 0.0
    
    # Ermittle alle Slot-Namen (Keys bei Hashtable, Properties bei PSCustomObject)
    $keys = @()
    if ($slots -is [System.Collections.IDictionary]) {
        $keys = $slots.Keys
    } else {
        foreach ($p in $slots.PSObject.Properties) {
            $keys += $p.Name
        }
    }
    
    foreach ($name in $keys) {
        $id = $null
        if ($slots -is [System.Collections.IDictionary]) {
            $id = $slots[$name]
        } else {
            $id = $slots.$name
        }
        $id = [string]$id
        
        if ($id -and $cache.ContainsKey($id)) {
            $stats = Parse-Tooltip $cache[$id].tooltip
            $slotKind = $name
            if ($name -like 'FINGER_*') { $slotKind = 'FINGER' }
            if ($name -like 'TRINKET_*') { $slotKind = 'TRINKET' }
            foreach ($k in $stats.Keys) {
                if ($k -eq 'WpnDps' -or $k -eq 'Sockel' -or $k -eq 'WpnSpeed') { continue }
                if ($specWeights.ContainsKey($k)) { $score += [double]$stats[$k] * $specWeights[$k] }
            }
            if ($stats.ContainsKey('WpnDps')) {
                $wd = [double]$stats['WpnDps']
                if ($slotKind -eq 'RANGED') {
                    if ($specWeights.ContainsKey('RANGED')) { $score += $wd * $specWeights['RANGED'] }
                } elseif ($slotKind -eq 'OFF_HAND') {
                    if ($specWeights.ContainsKey('OH')) { $score += $wd * $specWeights['OH'] }
                } elseif ($slotKind -eq 'MAIN_HAND' -or $slotKind -eq 'TWOHAND') {
                    if ($specWeights.ContainsKey('MH')) { $score += $wd * $specWeights['MH'] }
                }
            }
        }
    }
    return $score
}

# Vergleiche neu geladenes Gear mit altem Stand
foreach ($p in $players) {
    if (-not $alt.ContainsKey($p.Name)) { continue }
    
    # Sonderregel für Prot Paladin: falls kein Schild getragen wird, verwerfen
    if ($p.Spec -eq 'PROT_PALA' -and -not $p.Slots.ContainsKey('OFF_HAND')) {
        Write-Output "  [WARNUNG] $($p.Name) (PROT_PALA) hat kein Schild angelegt! Behalte alten Stand."
        $p.Slots = $alt[$p.Name]
        continue
    }

    $newScore = Get-GearScore $p.Slots $p.Spec
    $oldScore = Get-GearScore $alt[$p.Name] $p.Spec

    # Falls der neue Score signifikant niedriger ist als der alte Stand (z.B. < 80%),
    # verwerfen wir das neue Gear (sehr wahrscheinlich PvP- oder Offspec-Ausrüstung).
    if ($oldScore -gt 50 -and $newScore -lt ($oldScore * 0.80)) {
        Write-Output "  [WARNUNG] $($p.Name) ($($p.Spec)) hat verdächtiges Gear angelegt (PvE-Wertung: $newScore vs. alt: $oldScore)! PvP/Offspec vermutet. Behalte alten Stand."
        $p.Slots = $alt[$p.Name]
    }
}

# Aenderungen gegenueber dem letzten Stand
Write-Output ""
Write-Output "=== AENDERUNGEN SEIT DEM LETZTEN ABRUF ==="
$anzahl = 0
foreach ($p in ($players | Sort-Object Name)) {
    if (-not $alt.ContainsKey($p.Name)) { Write-Output ("  " + $p.Name + ": neu erfasst"); continue }
    $vorher = $alt[$p.Name]
    $zeilen = @()
    foreach ($s in ($p.Slots.Keys | Sort-Object)) {
        $neuId = $p.Slots[$s]
        $altId = $null
        if ($vorher.ContainsKey($s)) { $altId = [int]$vorher[$s] }
        if ($altId -ne $neuId) {
            $nName = if ($cache.ContainsKey([string]$neuId)) { $cache[[string]$neuId].name } else { "Item $neuId" }
            $aName = if ($altId -and $cache.ContainsKey([string]$altId)) { $cache[[string]$altId].name } else { "(leer)" }
            $zeilen += ("      {0,-12} {1}  ->  {2}" -f $s, $aName, $nName)
        }
    }
    if ($zeilen.Count) {
        $anzahl += $zeilen.Count
        Write-Output ("  " + $p.Name + ":")
        $zeilen | ForEach-Object { Write-Output $_ }
    }
}
if ($anzahl -eq 0) { Write-Output "  keine" } else { Write-Output ("`n  insgesamt $anzahl Slotwechsel") }

$players | ConvertTo-Json -Depth 4 | Out-File $plFile -Encoding utf8
Write-Output ""
Write-Output "players.json aktualisiert."
