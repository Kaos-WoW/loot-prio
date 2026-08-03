# Schritt 1: Item-IDs aus der Pool-Datei lesen, Werte von Wowhead holen, als JSON sichern
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot
$cacheFile = "$base\daten\cache-tooltips.json"

# ---------- 1. Pool-Datei parsen: Boss -> Items ----------
$poolLines = Get-Content "$base\quellen\p3-item-pool-2026-07-27.md" -Encoding UTF8
$entries = @{}
$curBoss = ""
$inItemArea = $false
foreach ($ln in $poolLines) {
    if ($ln -match '^#\s+(Mount Hyjal|Black Temple)') { $inItemArea = $true; continue }
    if (-not $inItemArea) { continue }
    if ($ln -match '^##\s+(.+?)\s*$') {
        $curBoss = $Matches[1] -replace '\s*\(.*?\)\s*$', ''
        $curBoss = $curBoss.Trim()
        continue
    }
    if ($curBoss -eq "") { continue }
    foreach ($m in [regex]::Matches($ln, '([A-Za-z0-9'',\.\-\s`]+?)\((\d{5,6})\)(\[s(-?\d+),c(\d+),sc(-?\d+)\])?')) {
        $id = [int]$m.Groups[2].Value
        if ($entries.ContainsKey($id)) { continue }
        $nm = $m.Groups[1].Value.Trim() -replace '^\*+\s*', '' -replace '^(Tokens?\s+\S+:\s*)', ''
        $slotCode = -1; $classCode = -1; $subCode = -99
        if ($m.Groups[3].Success) {
            $slotCode = [int]$m.Groups[4].Value
            $classCode = [int]$m.Groups[5].Value
            $subCode = [int]$m.Groups[6].Value
        }
        $entries[$id] = [pscustomobject]@{
            Id = $id; Name = $nm; Boss = $curBoss
            SlotCode = $slotCode; ClassCode = $classCode; SubCode = $subCode
            Quelle = "Raid"
        }
    }
}
Write-Output ("Aus Pool-Datei gelesen: " + $entries.Count + " Items")

# ---------- 2. Tier-6-Teile ergaenzen ----------
$t6 = @{
    "Onslaught"          = @(30972,30979,30975,30969,30977)
    "LightbringerHoly"   = @(30988,30996,30992,30983,30994)
    "LightbringerProt"   = @(30987,30998,30991,30985,30995)
    "LightbringerRet"    = @(30989,30997,30990,30982,30993)
    "Gronnstalker"       = @(31003,31006,31004,31001,31005)
    "Slayer"             = @(31027,31030,31028,31026,31029)
    "SkyshatterNah"      = @(31015,31024,31018,31011,31021)
    "SkyshatterCaster"   = @(31014,31023,31017,31008,31020)
    "SkyshatterResto"    = @(31012,31022,31016,31019,31010)
    "Malefic"            = @(31051,31054,31052,31050,31053)
    "Tempest"            = @(31056,31059,31057,31055,31058)
    "AbsolutionHoly"     = @(31064,31070,31066,31061,31067)
    "AbsolutionShadow"   = @(31063,31069,31065,31060,31068)
    "ThunderheartCaster" = @(31040,31049,31043,31035,31046)
    "ThunderheartFeral"  = @(31039,31048,31042,31034,31044)
    "ThunderheartResto"  = @(31037,31047,31041,31033,31045)
}
foreach ($set in $t6.Keys) {
    foreach ($id in $t6[$set]) {
        if (-not $entries.ContainsKey($id)) {
            $entries[$id] = [pscustomobject]@{
                Id=$id; Name=""; Boss="Tier 6 ($set)"; SlotCode=-1; ClassCode=4; SubCode=-99; Quelle="T6"
            }
        }
    }
}

# ---------- 3. Marken-Items (Keine neuen Marken-Items in Phase 3) ----------
$badge = @()
foreach ($id in $badge) {
    if (-not $entries.ContainsKey($id)) {
        $entries[$id] = [pscustomobject]@{
            Id=$id; Name=""; Boss="Marken"; SlotCode=-1; ClassCode=4; SubCode=-99; Quelle="Marken"
        }
    }
}

# ---------- 3.5 Legacy BiS Raid-Items (Phase 1 & 2) ----------
$legacyRaid = @{
    30106 = "Lady Vashj (SSC)"
    28830 = "Gruul"
    30627 = "Leotheras (SSC)"
    30107 = "Lady Vashj (SSC)"
    28823 = "Gruul"
    28789 = "Magtheridon"
    28785 = "Terestian Illhoof (Karazhan)"
    28528 = "Moroes (Karazhan)"
    30015 = "Kael'thas (TK)"
    30017 = "Al'ar (TK)"
    30055 = "Fathom-Lord (SSC)"
    30720 = "Fathom-Lord (SSC)"
    30450 = "The Lurker Below (SSC)"
    29993 = "Kael'thas (TK)"
    30083 = "Solarian (TK)"
    30007 = "Void Reaver (TK)"
    30081 = "Doomwalker"
    30105 = "Lady Vashj (SSC)"
    29383 = "Händler (Abzeichen)"
    29370 = "Händler (Abzeichen)"
    29376 = "Händler (Abzeichen)"
    33829 = "Zul'Aman (Hex)"
    32492 = "Mutter Shahraz (BT)"
    32487 = "Mutter Shahraz (BT)"
    32488 = "Mutter Shahraz (BT)"
    28121 = "Dungeon (BM Heroisch)"
    30626 = "Leotheras (SSC)"
    28727 = "Arans Schemen (Karazhan)"
}
foreach ($id in $legacyRaid.Keys) {
    if (-not $entries.ContainsKey($id)) {
        $entries[$id] = [pscustomobject]@{
            Id=$id; Name=""; Boss=$legacyRaid[$id]; SlotCode=-1; ClassCode=4; SubCode=-99; Quelle="Raid"
        }
    }
}

Write-Output ("Gesamt inkl. T6, Marken und Legacy BiS: " + $entries.Count)

# ---------- 4. Tooltips holen (mit Cache) ----------
$cache = @{}
if (Test-Path $cacheFile) {
    $raw = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $cache[$p.Name] = $p.Value }
    Write-Output ("Cache geladen: " + $cache.Count)
}
$fetched = 0; $failed = @()
foreach ($id in $entries.Keys) {
    $k = [string]$id
    if ($cache.ContainsKey($k)) { continue }
    try {
        $r = Invoke-RestMethod -Uri ("https://nether.wowhead.com/tbc/tooltip/item/$id" + "?locale=0") -TimeoutSec 25
        $cache[$k] = [pscustomobject]@{ name = $r.name; tooltip = $r.tooltip }
        $fetched++
    } catch { $failed += $id }
}
Write-Output ("Neu geholt: $fetched | Fehler: " + $failed.Count)
if ($failed.Count -gt 0) { Write-Output ("Fehlgeschlagen: " + ($failed -join ", ")) }
$cache | ConvertTo-Json -Depth 4 -Compress | Out-File $cacheFile -Encoding utf8
Write-Output "Cache gespeichert."

# ---------- 5. Tooltip -> Werte ----------
function Parse-Tooltip($tt) {
    # Zeilenumbrueche normalisieren BEVOR HTML-Tags entfernt werden
    $t = $tt -replace '[\r\n]+', ' '
    $t = $t -replace '<[^>]+>', '|'
    $t = $t -replace '\|+', '|'
    $voll = $t
    # WICHTIG: Prokk-, Nutzen- und Set-Bonus-Text abschneiden, BEVOR Werte gelesen werden.
    # Sonst wird z.B. Dragonstrikes "Chance on hit: Increases your haste rating by 212"
    # als dauerhafte Tempowertung gezaehlt. In WoW-Tooltips stehen feste Equip-Werte
    # immer vor diesen Bloecken, daher ist Abschneiden sicher.
    # Nur echte Prokk-/Nutzen-Marker schneiden. NICHT nach "Equip: Your" schneiden -
    # dauerhafte Effekte wie "Your attacks ignore 335 armor" beginnen genauso und
    # muessen erhalten bleiben.
    $cut = -1
    foreach ($mark in @('Chance on hit', 'Use:', '(2) Set', '(4) Set', 'have a chance', 'chance to')) {
        $i = $t.IndexOf($mark)
        if ($i -ge 0 -and ($cut -lt 0 -or $i -lt $cut)) { $cut = $i }
    }
    if ($cut -ge 0) { $t = $t.Substring(0, $cut) }
    $st = @{}
    function Add-Stat($h, $k, $v) { if ($h.ContainsKey($k)) { $h[$k] += $v } else { $h[$k] = $v } }
    foreach ($m in [regex]::Matches($t, '\+(\d+) (Agility|Strength|Stamina|Intellect|Spirit)')) {
        $map = @{ Agility='Agi'; Strength='Str'; Stamina='Sta'; Intellect='Int'; Spirit='Spi' }
        Add-Stat $st $map[$m.Groups[2].Value] ([int]$m.Groups[1].Value)
    }
    foreach ($m in [regex]::Matches($t, '(?:Improves|Increases)(?: your)? ([a-z ]+?) rating by \|?(\d+)')) {
        $lbl = $m.Groups[1].Value.Trim(); $v = [int]$m.Groups[2].Value
        switch -Regex ($lbl) {
            '^spell critical strike$' { Add-Stat $st 'ZKrit' $v }
            '^spell hit$'             { Add-Stat $st 'ZTreffer' $v }
            '^spell haste$'           { Add-Stat $st 'ZTempo' $v }
            '^critical strike$'       { Add-Stat $st 'Krit' $v }
            '^hit$'                   { Add-Stat $st 'Treffer' $v }
            '^haste$'                 { Add-Stat $st 'Tempo' $v }
            '^expertise$'             { Add-Stat $st 'Waffk' $v }
            '^armor penetration$'     { Add-Stat $st 'ArPRating' $v }
            '^defense$'               { Add-Stat $st 'Vert' $v }
            '^dodge$'                 { Add-Stat $st 'Ausw' $v }
            '^parry$'                 { Add-Stat $st 'Parr' $v }
            '^resilience$'            { Add-Stat $st 'Abh' $v }
        }
    }
    if ($t -match 'Increases attack power by \|?(\d+)')                                        { Add-Stat $st 'AP' ([int]$Matches[1]) }
    if ($t -match 'damage and healing done by magical spells and effects by up to \|?(\d+)')   { Add-Stat $st 'SP' ([int]$Matches[1]) }
    # Schul-spezifische Schadensbonus-Patterns (aeltere Items) - Maximum nehmen, um Doppelzählung (z.B. Frozen Shadoweave) zu vermeiden
    $schoolMax = 0
    foreach ($m in [regex]::Matches($t,'Increases damage done by (?:Shadow|Frost|Fire|Arcane|Nature|Holy) spells and effects by up to \|?(\d+)')) {
        $val = [int]$m.Groups[1].Value
        if ($val -gt $schoolMax) { $schoolMax = $val }
    }
    if ($schoolMax -gt 0) { Add-Stat $st 'SP' $schoolMax }
    if ($t -match 'healing done by up to \|?(\d+)')                                            { Add-Stat $st 'Heil' ([int]$Matches[1]) }
    if ($t -match 'Restores \|?(\d+) mana per 5 sec')                                          { Add-Stat $st 'mp5' ([int]$Matches[1]) }
    if ($t -match 'ignore \|?(\d+) of your opponent')                                          { Add-Stat $st 'ArP' ([int]$Matches[1]) }
    if ($t -match '\(([\d\.]+) damage per second\)')                                           { $st['WpnDps'] = [double]$Matches[1] }
    if ($t -match 'Speed \|?([\d\.]+)')                                                        { $st['WpnSpeed'] = [double]$Matches[1] }
    $sock = 0
    foreach ($c in @('Red','Yellow','Blue','Meta')) {
        $sock += ([regex]::Matches($t, "$c Socket")).Count
    }
    $st['Sockel'] = $sock
    $ilvl = 0; if ($t -match 'Item Level \|?(\d+)') { $ilvl = [int]$Matches[1] }
    $ph = ""; if ($t -match '(Phase \d(?:\.\d)?)') { $ph = $Matches[1] }
    $slotTxt = ""
    foreach ($s in @('Head','Neck','Shoulder','Chest','Waist','Legs','Feet','Wrist','Hands','Finger','Trinket','Back','Main Hand','Off Hand','One-Hand','Two-Hand','Ranged','Relic','Held In Off-hand','Shield','Thrown')) {
        if ($t -match ("\|" + [regex]::Escape($s) + "\|")) { $slotTxt = $s; break }
    }
    $armorTxt = ""
    foreach ($a in @('Cloth','Leather','Mail','Plate','Shield')) {
        if ($t -match ("\|" + $a + "\|")) { $armorTxt = $a; break }
    }
    $cls = ""
    if ($t -match 'Classes: \|?([A-Za-z, \|]+?)\|Requires') { $cls = ($Matches[1] -replace '\|','').Trim() }
    # Waffentyp (steht direkt hinter dem Slot)
    $wtype = ""
    foreach ($wt in @('Sword','Axe','Mace','Dagger','Fist Weapon','Polearm','Staff','Bow','Gun','Crossbow','Wand','Thrown')) {
        if ($t -match ("\|" + [regex]::Escape($wt) + "\|")) { $wtype = $wt; break }
    }
    # Angriffskraft nur in Tierform (Feral-Waffen) -> fuer alle anderen wertlos
    $formOnly = ($t -match 'forms only' -or $t -match 'in Cat, Bear')
    return [pscustomobject]@{ Stats=$st; Ilvl=$ilvl; Phase=$ph; SlotTxt=$slotTxt; ArmorTxt=$armorTxt; Classes=$cls; WeaponType=$wtype; FormOnly=$formOnly }
}

$out = @()
foreach ($id in ($entries.Keys | Sort-Object)) {
    $k = [string]$id
    if (-not $cache.ContainsKey($k)) { continue }
    $c = $cache[$k]
    $p = Parse-Tooltip $c.tooltip
    $e = $entries[$id]
    $out += [pscustomobject]@{
        Id=$id; Name=$c.name; Boss=$e.Boss; Quelle=$e.Quelle
        Ilvl=$p.Ilvl; Phase=$p.Phase; Slot=$p.SlotTxt; Armor=$p.ArmorTxt; Classes=$p.Classes
        WeaponType=$p.WeaponType; FormOnly=$p.FormOnly
        SlotCode=$e.SlotCode; Stats=$p.Stats
    }
}
$out | ConvertTo-Json -Depth 5 | Out-File "$base\daten\items.json" -Encoding utf8
Write-Output ("Geschrieben: items.json mit " + $out.Count + " Items")
Write-Output ""
Write-Output "--- Stichprobe ---"
foreach ($id in @(30902,32235,32837,31052,30975,34942,32505)) {
    $it = $out | Where-Object { $_.Id -eq $id }
    if ($it) {
        $s = ($it.Stats.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
        Write-Output ("{0} {1} | i{2} {3} | {4}/{5} | {6}" -f $it.Id,$it.Name,$it.Ilvl,$it.Phase,$it.Slot,$it.Armor,$s)
    }
}
