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

# T6 Token-Gruppen: Jedes Tier-6-Ruestungsteil gehoert zu genau einem Token (Typ + Slot).
# Token-Typ: Conqueror (Paladin/Priest/Warlock), Protector (Krieger/Jaeger/Schamane),
#            Vanquisher (Schurke/Magier/Druide)
# Items die denselben Token teilen konkurrieren miteinander — bc muss ALLE Token-Konkurrenten zaehlen.
#
# WICHTIG: Die Zuordnung wird aus items.json ABGELEITET (Setname im Boss-Feld + Slot), nicht
# hartcodiert. Eine frueher gepflegte ID-Liste war stark fehlerhaft (nicht existierende IDs,
# falsche Slots, sogar Items im falschen Token) und hat 33 von 78 T6-Teilen gar nicht erfasst.
$setToTokenType = @{
    'Lightbringer' = 'CONQ'   # Paladin
    'Absolution'   = 'CONQ'   # Priester
    'Malefic'      = 'CONQ'   # Hexenmeister
    'Onslaught'    = 'PROT'   # Krieger
    'Gronnstalker' = 'PROT'   # Jaeger
    'Skyshatter'   = 'PROT'   # Schamane
    'Slayer'       = 'VANQ'   # Schurke
    'Tempest'      = 'VANQ'   # Magier
    'Thunderheart' = 'VANQ'   # Druide
}
$tokenSlots = @('Head','Shoulder','Chest','Hands','Legs')

$tokenGroupMap = @{}
foreach ($it in $items) {
    if ($it.Boss -notlike 'Tier 6*') { continue }
    if ($tokenSlots -notcontains $it.Slot) { continue }   # Relikte/Waffen tragen kein Token
    $type = $null
    foreach ($setName in $setToTokenType.Keys) {
        if ($it.Boss -like ("*" + $setName + "*")) { $type = $setToTokenType[$setName]; break }
    }
    if (-not $type) { Write-Warning ("T6-Item ohne bekanntes Set: " + $it.Id + " " + $it.Name + " [" + $it.Boss + "]"); continue }
    $tokenGroupMap[[string]$it.Id] = $type + "|" + $it.Slot
}

# Die Token-Gegenstaende selbst ("... of the Forgotten ...") liegen ohne Slot/Werte im Pool und
# erzeugen daher keine Upgrade-Zeilen. Hier werden sie als Metadaten je Gruppe eingesammelt,
# damit die Seite Tokenname und echten Drop-Boss anzeigen kann.
$tokenNameToSlot = @{ 'Helm'='Head'; 'Pauldrons'='Shoulder'; 'Chestguard'='Chest'; 'Gloves'='Hands'; 'Leggings'='Legs' }
$tokenTypeWord   = @{ 'Conqueror'='CONQ'; 'Protector'='PROT'; 'Vanquisher'='VANQ' }
$tokenMeta = @{}
foreach ($it in $items) {
    if ($it.Name -notlike '*of the Forgotten *') { continue }
    $m = [regex]::Match($it.Name, '^(\w+) of the Forgotten (\w+)$')
    if (-not $m.Success) { continue }
    $slot = $tokenNameToSlot[$m.Groups[1].Value]
    $type = $tokenTypeWord[$m.Groups[2].Value]
    if (-not $slot -or -not $type) { continue }
    $tokenMeta[$type + "|" + $slot] = [pscustomobject]@{
        grp  = $type + "|" + $slot
        id   = $it.Id
        n    = $it.Name
        b    = $it.Boss
        s    = $slot
        typ  = $type
    }
}
Write-Output ("Token-Zuordnung: " + $tokenGroupMap.Count + " T6-Teile in " + ($tokenGroupMap.Values | Sort-Object -Unique).Count + " Gruppen, " + $tokenMeta.Count + " Token-Gegenstaende erkannt")

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
    $tk = ""
    if ($tokenGroupMap.ContainsKey($idStr)) {
        # T6 Token-Item: bc = alle Spieler die auf denselben Token (egal welches Item) BiS haben
        $tk = $tokenGroupMap[$idStr]
        if ($tokenGroupPlayers.ContainsKey($tk)) { $bc = $tokenGroupPlayers[$tk].Count }
    } elseif ($itemBisPlayers.ContainsKey($idStr)) {
        $bc = $itemBisPlayers[$idStr].Count
    }
    $bb = ($bc -gt 0 -and $br -ne 1)
    $hClean = if ($u.Hinweis) { ($u.Hinweis -replace "[\r\n]+", " ").Trim() } else { "" }

    # Knappheit & Alternativen berechnen (statische Klassifizierung)
    $knappheit = "Mittel"
    if ($u.Quelle -eq 'Marken' -or $u.Quelle -eq 'Trash' -or $u.Quelle -eq 'Craft' -or $u.Quelle -eq 'Quest' -or $u.Quelle -eq 'Ruf') {
        $knappheit = "Gering"
    } elseif ($u.Ilvl -lt 128 -and $u.ItemId -ne 28830) {
        $knappheit = "Gering"
    } else {
        # 16 absolute BiS / Key-Items der Phase 3 und davor ohne echte Alternativen
        # Warglaives (32837, 32838), DST (28830), Tsunami (30627), Madness (32505), Skull (32483), Hex (33829),
        # Gurt der 100 Tode (30106), Cursed Vision (32235), Memento (32486), Spire (32247), Tempest (30910),
        # Apostle (30908), Cataclysm's Edge (30902), Zhar'doom (32374), Bow-stitched (32242)
        $veryHighIds = @(32837, 32838, 28830, 30627, 32505, 32483, 33829, 30106, 32235, 32486, 32247, 30910, 30908, 30902, 32374, 32242)
        if ($veryHighIds -contains $u.ItemId) {
            $knappheit = "Sehr hoch"
        }
    }

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
        tk  = $tk
        k   = $knappheit
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
    tokens    = @($tokenMeta.Values | Sort-Object typ, s)
}
$json = $payload | ConvertTo-Json -Depth 6 -Compress
[System.IO.File]::WriteAllText("$base\daten\payload.json", $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("payload.json geschrieben: " + $rows.Count + " Zeilen, " + [math]::Round($json.Length/1024,1) + " KB")

# Zusammenbau der Seite aus Vorlage + Daten.
#
# Frueher entstanden hier zwei Fassungen, unterschieden durch einen __BETA__-Schalter: die
# Produktivseite ohne Schmuckstuecke und eine Beta-Seite mit ihnen. Seit die simulierten
# Schmuckstueck-Werte abgenommen sind, sind sie ein normaler Teil der Liste - Schalter und
# Beta-Seite sind deshalb entfallen.
$tpl = "$base\vorlage.html"
if (Test-Path $tpl) {
    $tplHtml = [System.IO.File]::ReadAllText($tpl, [System.Text.Encoding]::UTF8)
    $enc = New-Object System.Text.UTF8Encoding($false)

    $html = $tplHtml.Replace('"__DATEN__"', $json)
    [System.IO.File]::WriteAllText("$base\ausgabe\loot-prio-p3.html", $html, $enc)
    [System.IO.File]::WriteAllText("$base\index.html", $html, $enc)

    Write-Output ("index.html und ausgabe/loot-prio-p3.html gebaut: " + [math]::Round((Get-Item "$base\index.html").Length/1024,1) + " KB")
} else {
    Write-Output "Vorlage fehlt noch - nur payload.json erzeugt."
}
