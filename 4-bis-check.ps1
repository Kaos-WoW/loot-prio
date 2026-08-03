# Schritt 4: Gegenprobe gegen veroeffentlichte Phase-3-BiS-Listen
# DPS gegen warcrafttavern.com (daten/scrape_bis.py), Tank/Heiler gegen die
# offiziellen Wowhead-Guides (daten/scrape_wowhead_final.py) -- beide schreiben
# in dieselbe daten/bis-listen.json.
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

$dpsSpecs = [ordered]@{
 'FURY'  = 'fury-warrior-dps-phase-3-best-in-slot-bis'
 'ARMS'  = 'arms-warrior-dps-phase-3-best-in-slot-bis'
 'RET'   = 'pve-retribution-paladin-phase-3-bis'
 'ENH'   = 'pve-enhancement-shaman-phase-3-bis'
 'ROGUE' = 'combat-rogue-pve-phase-3-best-in-slot-bis'
 'HUNT'  = 'pve-beast-mastery-hunter-phase-3-bis'
 'WLCK'  = 'pve-destruction-warlock-phase-3-bis'
 'MAGE'  = 'arcane-mage-pve-phase-3-best-in-slot-bis'
 'SPRI'  = 'pve-shadow-priest-phase-3-bis'
 'ELE'   = 'pve-elemental-shaman-phase-3-bis'
 'BAL'   = 'pve-balance-druid-phase-3-bis'
}

$tankHealSpecs = [ordered]@{
 'PROT_PALA'   = 'Tank'
 'FERAL_TANK'  = 'Tank'
 'RESTO_SHAM'  = 'Heiler'
 'HOLY_PALA'   = 'Heiler'
 'RESTO_DRUID' = 'Heiler'
 'HOLY_PRIEST' = 'Heiler'
}

$bisFile = "$base\daten\bis-listen.json"
$bis = @{}
if (Test-Path $bisFile) {
    $raw = Get-Content $bisFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $bis[$p.Name] = $p.Value }
}

$upg = Get-Content "$base\daten\upgrades.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$items = Get-Content "$base\daten\items.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$byId = @{}; foreach ($i in $items) { $byId[[string]$i.Id] = $i }

function Show-BisBlock {
    param($specKeys, $sortField, $unitFormat, [ref]$geprueft, [ref]$platz1, [ref]$top3)

    foreach ($k in $specKeys) {
        if (-not $bis.ContainsKey($k)) { Write-Output "$k : keine BiS-Daten"; continue }
        $bl = $bis[$k]
        if ($bl.Count -eq 0) { Write-Output "$k : keine BiS-Daten"; continue }
        $bisAll = @{}      # Id -> bester Rang
        foreach ($e in $bl) {
            $sid = [string]$e.Id
            if (-not $bisAll.ContainsKey($sid) -or $bisAll[$sid] -gt $e.Rank) { $bisAll[$sid] = $e.Rank }
        }
        $mine = $upg | Where-Object { $_.SpecKey -eq $k -and -not $_.Unsicher -and -not $_.NichtBewertbar }
        if (-not $mine) { Write-Output "$k : keine Upgrades berechnet"; continue }
        Write-Output ("--- " + $k + " ---")
        $grp = $mine | Group-Object Slot
        foreach ($g in ($grp | Sort-Object Name)) {
            $best = $g.Group | Sort-Object $sortField -Descending | Select-Object -First 1
            $sid = [string]$best.ItemId
            $rank = if ($bisAll.ContainsKey($sid)) { $bisAll[$sid] } else { -1 }
            $urteil = if ($rank -eq 0) { "BiS Platz 1" }
                      elseif ($rank -gt 0) { "BiS Platz " + ($rank+1) }
                      else { "NICHT in BiS-Liste" }
            $wert = $unitFormat -f $best.$sortField
            Write-Output ("  {0,-12} {1,-38} {2,12}   {3}" -f $g.Name, $best.Item, $wert, $urteil)

            $geprueft.Value++
            if ($rank -eq 0) { $platz1.Value++ }
            if ($rank -ge 0 -and $rank -le 2) { $top3.Value++ }
        }
        Write-Output ""
    }
}

Write-Output "=== GEGENPROBE DPS: mein bester Vorschlag je Slot vs. BiS-Rang (warcrafttavern.com) ==="
Write-Output ""
$dpsGeprueft = 0; $dpsPlatz1 = 0; $dpsTop3 = 0
Show-BisBlock -specKeys $dpsSpecs.Keys -sortField 'Delta' -unitFormat '{0:N1} DPS' -geprueft ([ref]$dpsGeprueft) -platz1 ([ref]$dpsPlatz1) -top3 ([ref]$dpsTop3)

Write-Output "=== GEGENPROBE TANK/HEILER: mein bester Vorschlag je Slot vs. BiS-Rang (Wowhead-Guides) ==="
Write-Output ""
$thGeprueft = 0; $thPlatz1 = 0; $thTop3 = 0
Show-BisBlock -specKeys $tankHealSpecs.Keys -sortField 'Pct' -unitFormat '{0:N2} %' -geprueft ([ref]$thGeprueft) -platz1 ([ref]$thPlatz1) -top3 ([ref]$thTop3)

Write-Output "=== ZUSAMMENFASSUNG ==="
if ($dpsGeprueft -gt 0) {
    $p1 = [math]::Round(100 * $dpsPlatz1 / $dpsGeprueft, 0)
    $t3 = [math]::Round(100 * $dpsTop3 / $dpsGeprueft, 0)
    Write-Output ("DPS         : {0} Empfehlungen - {1}% auf BiS-Platz 1 - {2}% in den BiS-Top-3" -f $dpsGeprueft, $p1, $t3)
}
if ($thGeprueft -gt 0) {
    $p1 = [math]::Round(100 * $thPlatz1 / $thGeprueft, 0)
    $t3 = [math]::Round(100 * $thTop3 / $thGeprueft, 0)
    Write-Output ("Tank/Heiler : {0} Empfehlungen - {1}% auf BiS-Platz 1 - {2}% in den BiS-Top-3" -f $thGeprueft, $p1, $t3)
}
