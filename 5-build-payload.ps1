# Schritt 5: kompakte Datennutzlast fuer die HTML-Seite erzeugen
#
# Phase 3 ist immer dabei. Phase 4 und 5 kommen NUR dazu, wenn ihre
# upgrades-p<N>.json existiert - fehlen sie, entsteht exakt die Seite von vorher.
# Dadurch kann ein unfertiger oder kaputter Phasen-Pfad die Gildenseite nicht treffen.
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

$phasen = @(3)
foreach ($p in 4, 5) {
    if ((Test-Path "$base\daten\upgrades-p$p.json") -and (Test-Path "$base\daten\items-p$p.json")) {
        $phasen += $p
    }
}
Write-Output ("Phasen in der Nutzlast: " + ($phasen -join ", "))

$roster = Get-Content "$base\roster.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# Item-Namen sammeln sich ueber alle Phasen (id -> name), damit das Frontend auch
# getragene und phasenfremde Teile benennen kann.
$itemNames = @{}
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
# BiS-Liste einer Phase holen - fuer alle Phasen aus derselben Wowhead-Datei.
# Die frueher fuer Phase 3 genutzte bis-listen.json kam bei den DPS-Specs von
# warcrafttavern.com und ist entfallen; BiS-Quelle ist ausschliesslich Wowhead.
function Hole-BisListe($phase) {
    $alle = Get-Content "$base\daten\bis-listen-phasen.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $rawB = $alle."$phase"
    if (-not $rawB) { throw "bis-listen-phasen.json hat keinen Block fuer Phase $phase." }
    $h = @{}
    foreach ($p in $rawB.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
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
# ★ Sunwell (Phase 5) bringt eine ZWEITE Token-Familie: Armschienen/Guertel/Stiefel
# "of the Forgotten ...". Aufbau identisch zu Tier 6, deshalb dieselbe abgeleitete
# Logik - nur Slots und Namensworte kommen dazu. Wer sie vergisst, bekommt fuer
# Sunwell-Token eine falsche Anwaerterzahl (bc), nicht etwa eine Fehlermeldung.
$tokenSlots      = @('Head','Shoulder','Chest','Hands','Legs','Wrist','Waist','Feet')
$tokenNameToSlot = @{
    'Helm'='Head'; 'Pauldrons'='Shoulder'; 'Chestguard'='Chest'; 'Gloves'='Hands'; 'Leggings'='Legs'
    'Bracers'='Wrist'; 'Belt'='Waist'; 'Boots'='Feet'
}
$tokenTypeWord = @{ 'Conqueror'='CONQ'; 'Protector'='PROT'; 'Vanquisher'='VANQ' }

function Baue-TokenZuordnung($items) {
    $map = @{}
    foreach ($it in $items) {
        if ($it.Boss -notlike 'Tier 6*') { continue }
        if ($tokenSlots -notcontains $it.Slot) { continue }   # Relikte/Waffen tragen kein Token
        $type = $null
        # Der Setname steht bei Tier 6 im Boss-Feld ("Tier 6 (LightbringerRet)"), bei den
        # Sunwell-Teilen aber nur im Item-Namen ("Lightbringer Bands"), weil sie alle vom
        # selben Haendler kommen. Deshalb beide Felder durchsuchen.
        $suchtext = "$($it.Boss) $($it.Name)"
        foreach ($setName in $setToTokenType.Keys) {
            if ($suchtext -like ("*" + $setName + "*")) { $type = $setToTokenType[$setName]; break }
        }
        if (-not $type) { Write-Warning ("Tier-Item ohne bekanntes Set: " + $it.Id + " " + $it.Name + " [" + $it.Boss + "]"); continue }
        $map[[string]$it.Id] = $type + "|" + $it.Slot
    }
    return $map
}

# Die Token-Gegenstaende selbst ("... of the Forgotten ...") liegen ohne Slot/Werte im Pool und
# erzeugen daher keine Upgrade-Zeilen. Hier werden sie als Metadaten je Gruppe eingesammelt,
# damit die Seite Tokenname und echten Drop-Boss anzeigen kann.
function Baue-TokenMeta($items) {
    $meta = @{}
    foreach ($it in $items) {
        if ($it.Name -notlike '*of the Forgotten *') { continue }
        $m = [regex]::Match($it.Name, '^(\w+) of the Forgotten (\w+)$')
        if (-not $m.Success) { continue }
        $slot = $tokenNameToSlot[$m.Groups[1].Value]
        $type = $tokenTypeWord[$m.Groups[2].Value]
        if (-not $slot -or -not $type) { continue }
        $meta[$type + "|" + $slot] = [pscustomobject]@{
            grp = $type + "|" + $slot; id = $it.Id; n = $it.Name; b = $it.Boss; s = $slot; typ = $type
        }
    }
    return $meta
}

# Schritt 0: Spec -> Spieler-Map aus Roster aufbauen (phasenunabhaengig)
$specToPlayers = @{}
foreach ($r in $roster) {
    $sk = $r.spec
    if (-not $specToPlayers.ContainsKey($sk)) { $specToPlayers[$sk] = @() }
    $specToPlayers[$sk] += $r.name
}

# ---- ab hier je Phase ----
$alleRows   = @()
$alleTokens = @()

foreach ($phase in $phasen) {
$upgDatei   = if ($phase -eq 3) { "upgrades.json" } else { "upgrades-p$phase.json" }
$itemsDatei = if ($phase -eq 3) { "items.json" }    else { "items-p$phase.json" }
$upg   = Get-Content "$base\daten\$upgDatei"   -Raw -Encoding UTF8 | ConvertFrom-Json
$items = Get-Content "$base\daten\$itemsDatei" -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($item in $items) {
    if ($item.Id -and $item.Name -and -not $itemNames.ContainsKey([string]$item.Id)) {
        $itemNames[[string]$item.Id] = $item.Name
    }
}

$bis = Hole-BisListe $phase
$bisRank = @{}
foreach ($k in $bis.Keys) {
    foreach ($e in $bis[$k]) {
        $key = $k + "|" + $e.Id
        if (-not $bisRank.ContainsKey($key) -or $bisRank[$key] -gt $e.Rank) { $bisRank[$key] = $e.Rank }
    }
}

$tokenGroupMap = Baue-TokenZuordnung $items
$tokenMeta     = Baue-TokenMeta $items
Write-Output ("  Phase " + $phase + ": " + $tokenGroupMap.Count + " Tier-Teile in " +
    ($tokenGroupMap.Values | Sort-Object -Unique).Count + " Gruppen, " + $tokenMeta.Count + " Token erkannt")

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
        # pb = Bezugsgroesse der Prozentzahl ('dps' oder 'gear'), bd = Basis-DPS,
        # bsim = ob diese Basis gemessen (simuliert) oder nur ein Spec-Schaetzwert ist.
        pb  = $u.PctBasis
        bd  = $u.BasisDps
        bsim = [bool]$u.BasisSim
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
        ph  = $phase
    }
}

$alleRows += $rows
foreach ($t in $tokenMeta.Values) {
    $alleTokens += [pscustomobject]@{ grp=$t.grp; id=$t.id; n=$t.n; b=$t.b; s=$t.s; typ=$t.typ; ph=$phase }
}
Write-Output ("  Phase " + $phase + ": " + $rows.Count + " Zeilen")
}   # Ende Phasen-Schleife


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
    phasen    = @($phasen)
    rows      = $alleRows
    roster    = @($roster | ForEach-Object { [pscustomobject]@{ name=$_.name; spec=$_.spec } })
    gear      = $gearMap
    itemNames = $itemNames
    tokens    = @($alleTokens | Sort-Object ph, typ, s)
}
$json = $payload | ConvertTo-Json -Depth 6 -Compress
[System.IO.File]::WriteAllText("$base\daten\payload.json", $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("payload.json geschrieben: " + $alleRows.Count + " Zeilen, " + [math]::Round($json.Length/1024,1) + " KB")

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
