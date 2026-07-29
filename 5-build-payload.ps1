# Schritt 5: kompakte Datennutzlast fuer die HTML-Seite erzeugen
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

$upg    = Get-Content "$base\daten\upgrades.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$items  = Get-Content "$base\daten\items.json"   -Raw -Encoding UTF8 | ConvertFrom-Json
$roster = Get-Content "$base\roster.json"        -Raw -Encoding UTF8 | ConvertFrom-Json

# Kompakter Item-Namen-Cache fuer das Frontend (id -> name)
# Quelle 1: items.json (Raid-Items, Array mit Id/Name Feldern)
$itemNames = @{}
foreach ($item in $items) {
    if ($item.Id -and $item.Name) {
        $itemNames[[string]$item.Id] = $item.Name
    }
}
# Quelle 2: cache-tooltips.json (getragene Items aus Armory, Objekt id -> {name, tooltip})
$tooltipFile = "$base\daten\cache-tooltips.json"
if (Test-Path $tooltipFile) {
    $tooltips = Get-Content $tooltipFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $tooltips.PSObject.Properties) {
        $id = $prop.Name
        $nm = if ($prop.Value.name) { $prop.Value.name } else { "" }
        if ($nm -and -not $itemNames.ContainsKey($id)) { $itemNames[$id] = $nm }
    }
}
$rawB  = Get-Content "$base\daten\bis-listen.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$bis = @{}; foreach ($p in $rawB.PSObject.Properties) { $bis[$p.Name] = $p.Value }

# BiS-Rang je Spec+Item
$bisRank = @{}
foreach ($k in $bis.Keys) {
    foreach ($e in $bis[$k]) {
        $key = $k + "|" + $e.Id
        if (-not $bisRank.ContainsKey($key) -or $bisRank[$key] -gt $e.Rank) { $bisRank[$key] = $e.Rank }
    }
}

# Helper: Prüfen ob ein Slot 2 Plätze hat (Ringe, Trinkets)
function Is-2Slot($slot) {
    return ($slot -eq 'Finger' -or $slot -eq 'FINGER' -or $slot -eq 'Trinket' -or $slot -eq 'TRINKET')
}

# T6 Token-Gruppen: Jedes Tier-6-Item gehoert zu einem der drei Token-Typen pro Slot.
# Token-Typ: Conqueror (Paladin/Priest/Warlock), Protector (Hunter/Shaman/Warrior), Vanquisher (Druid/Mage/Rogue)
# Items die denselben Token teilen konkurrieren miteinander — bc muss ALLE Token-Konkurrenten zaehlen.
$tokenGroupMap = @{}
@(
    # VANQUISHER: Rogue (Slayer) / Druid-Balance (Thunderheart) / Mage (Tempest of Chaos)
    @{ids=@(31027,31040,30986); grp="VANQ|Head"},
    @{ids=@(31030,31049,30988); grp="VANQ|Shoulder"},
    @{ids=@(31028,31043,31057); grp="VANQ|Chest"},
    @{ids=@(31026,31035,30982); grp="VANQ|Hands"},
    @{ids=@(31029,31046,30984); grp="VANQ|Legs"},
    # PROTECTOR: Hunter (Gronnstalker) / Shaman-Ele (Skyshatter) / Shaman-Enh (Skyshatter) / Warrior (Onslaught)
    @{ids=@(31001,31014,31015,30961); grp="PROT|Head"},
    @{ids=@(31006,31023,31024,30979); grp="PROT|Shoulder"},
    @{ids=@(31004,31017,31018,30967); grp="PROT|Chest"},
    @{ids=@(31002,31008,31011,30969); grp="PROT|Hands"},
    @{ids=@(31005,31020,31021,30977); grp="PROT|Legs"},
    # CONQUEROR: Paladin (Lightbringer) / Priest (Absolution) / Warlock (Malefic)
    @{ids=@(30990,31064,31051); grp="CONQ|Head"},
    @{ids=@(30992,31070,31053); grp="CONQ|Shoulder"},
    @{ids=@(30989,31065,31052); grp="CONQ|Chest"},
    @{ids=@(30991,31063,31054); grp="CONQ|Hands"},
    @{ids=@(30993,31066,31055); grp="CONQ|Legs"}
) | ForEach-Object { $grp=$_.grp; $_.ids | ForEach-Object { $tokenGroupMap[[string]$_] = $grp } }
# Gronnstalker's Gloves (31001) sind Hands, nicht Head — korrigieren
$tokenGroupMap["31001"] = "PROT|Hands"

# Schritt 0: Spec -> Spieler-Map aus Roster aufbauen
$specToPlayers = @{}
foreach ($r in $roster) {
    $sk = $r.spec
    if (-not $specToPlayers.ContainsKey($sk)) { $specToPlayers[$sk] = @() }
    $specToPlayers[$sk] += $r.name
}

# Schritt 1: BiS-Items zaehlen — alle Spieler des gleichen Specs werden als Kandidaten gewertet.
# D.h.: Steht ein Item (Rank 0 bzw. Rank 0+1 bei 2-Slot) in der BiS-Liste von Spec X,
# dann zaehlen ALLE Spieler von Spec X als Interessenten — unabhaengig davon ob sie das Item
# gerade als Upgrade benoetigen oder es schon besitzen.
$itemBisPlayers = @{}

# Zuerst: Spec-basierte Zählung aus der BiS-Liste direkt (Roster-Spieler × BiS-Items)
foreach ($specKey in $specToPlayers.Keys) {
    $players = $specToPlayers[$specKey]
    if (-not $bis.ContainsKey($specKey)) { continue }
    foreach ($bisEntry in $bis[$specKey]) {
        $isBis1 = if (Is-2Slot $bisEntry.Slot) { ($bisEntry.Rank -eq 0 -or $bisEntry.Rank -eq 1) } else { ($bisEntry.Rank -eq 0) }
        if ($isBis1) {
            $idStr = [string]$bisEntry.Id
            if (-not $itemBisPlayers.ContainsKey($idStr)) { $itemBisPlayers[$idStr] = @{} }
            foreach ($pl in $players) { $itemBisPlayers[$idStr][$pl] = $true }
        }
    }
}

# Ergaenzend: Upgrade-basierte Zählung (fuer Items die nicht in der BiS-Liste stehen
# aber trotzdem als BiS aus upgrades.json erkannt werden — z.B. durch Berechnung)
foreach ($u in $upg) {
    $key = $u.SpecKey + "|" + $u.ItemId
    if ($bisRank.ContainsKey($key)) {
        $r = $bisRank[$key]
        $isBis1 = if (Is-2Slot $u.Slot) { ($r -eq 0 -or $r -eq 1) } else { ($r -eq 0) }
        if ($isBis1) {
            $idStr = [string]$u.ItemId
            if (-not $itemBisPlayers.ContainsKey($idStr)) { $itemBisPlayers[$idStr] = @{} }
            $itemBisPlayers[$idStr][$u.Spieler] = $true
        }
    }
}

# Schritt 2: Token-Gruppen-Aggregation
# Fuer jede Token-Gruppe: alle BiS-Spieler aller Items in der Gruppe zusammenfassen
$tokenGroupPlayers = @{}
foreach ($idStr in $itemBisPlayers.Keys) {
    if ($tokenGroupMap.ContainsKey($idStr)) {
        $grp = $tokenGroupMap[$idStr]
        if (-not $tokenGroupPlayers.ContainsKey($grp)) { $tokenGroupPlayers[$grp] = @{} }
        foreach ($pl in $itemBisPlayers[$idStr].Keys) { $tokenGroupPlayers[$grp][$pl] = $true }
    }
}

$rows = @()
foreach ($u in $upg) {
    $br = -1
    $key = $u.SpecKey + "|" + $u.ItemId
    if ($bisRank.ContainsKey($key)) {
        $r = $bisRank[$key]
        if (Is-2Slot $u.Slot) {
            if ($r -eq 0 -or $r -eq 1) { $br = 1 }
            elseif ($r -eq 2 -or $r -eq 3) { $br = 2 }
            else { $br = $r + 1 }
        } else {
            $br = $r + 1
        }
    }
    $bc = 0
    $idStr = [string]$u.ItemId
    if ($tokenGroupMap.ContainsKey($idStr)) {
        # T6 Token-Item: bc = alle Spieler die auf denselben Token (egal welches Item) BiS haben
        $grp = $tokenGroupMap[$idStr]
        if ($tokenGroupPlayers.ContainsKey($grp)) { $bc = $tokenGroupPlayers[$grp].Count }
    } elseif ($itemBisPlayers.ContainsKey($idStr)) {
        $bc = $itemBisPlayers[$idStr].Count
    }
    $bb = ($bc -gt 0 -and $br -ne 1)
    $hClean = if ($u.Hinweis) { ($u.Hinweis -replace "[\r\n]+", " ").Trim() } else { "" }
    $rows += [pscustomobject]@{
        id  = $u.ItemId
        n   = ($u.Item -replace "[\r\n]+", " ").Trim()
        b   = ($u.Boss -replace "[\r\n]+", " ").Trim()
        s   = ($u.Slot -replace "[\r\n]+", " ").Trim()
        q   = ($u.Quelle -replace "[\r\n]+", " ").Trim()
        il  = $u.Ilvl
        sp  = ($u.Spec -replace "[\r\n]+", " ").Trim()
        sk  = ($u.SpecKey -replace "[\r\n]+", " ").Trim()
        pl  = ($u.Spieler -replace "[\r\n]+", " ").Trim()
        d   = $u.Delta
        p   = $u.Pct
        e   = ($u.Ersetzt -replace "[\r\n]+", " ").Trim()
        h   = $hClean
        nb  = [bool]$u.NichtBewertbar
        un  = [bool]$u.Unsicher
        spd = $u.Speed
        ps  = $u.ProSchlag
        bis = $br
        bc  = $bc
        bb  = $bb
        ro  = $u.Rolle
    }
}

$roster = Get-Content "$base\roster.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# Aktuell getragenes Gear der Spieler einbetten (ItemId je Slot je Spieler)
$gearMap = @{}
$plFile = "$base\daten\players.json"
if (Test-Path $plFile) {
    $players = Get-Content $plFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $players) {
        $slots = @{}
        foreach ($s in $p.Slots.PSObject.Properties) { $slots[$s.Name] = [int]$s.Value }
        $gearMap[$p.Name] = $slots
    }
}

$payload = [pscustomobject]@{
    stand     = (Get-Date -Format "yyyy-MM-dd")
    rows      = $rows
    roster    = @($roster | ForEach-Object { [pscustomobject]@{ name=$_.name; spec=$_.spec } })
    gear      = $gearMap
    itemNames = $itemNames
}
$json = $payload | ConvertTo-Json -Depth 6 -Compress
[System.IO.File]::WriteAllText("$base\daten\payload.json", $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("payload.json geschrieben: " + $rows.Count + " Zeilen, " + [math]::Round($json.Length/1024,1) + " KB")

# Zusammenbau der Seite aus Vorlage + Daten (für ausgabe/ und root index.html für Netlify)
$tpl = "$base\vorlage.html"
if (Test-Path $tpl) {
    $html = [System.IO.File]::ReadAllText($tpl, [System.Text.Encoding]::UTF8)
    $html = $html.Replace('"__DATEN__"', $json)
    [System.IO.File]::WriteAllText("$base\ausgabe\loot-prio-p3.html", $html, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText("$base\index.html", $html, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ("loot-prio-p3.html & index.html gebaut: " + [math]::Round((Get-Item "$base\index.html").Length/1024,1) + " KB")
} else {
    Write-Output "Vorlage fehlt noch - nur payload.json erzeugt."
}
