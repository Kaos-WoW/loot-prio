# Schritt 4: Gegenprobe gegen veroeffentlichte Phase-3-BiS-Listen (warcrafttavern.com)
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

$slugs = [ordered]@{
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

$bisFile = "$base\daten\bis-listen.json"
$bis = @{}
if (Test-Path $bisFile) {
    $raw = Get-Content $bisFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $bis[$p.Name] = $p.Value }
}


# ---------- Vergleich: Ist mein Top-Vorschlag je Slot in der BiS-Liste? ----------
$upg = Get-Content "$base\daten\upgrades.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$items = Get-Content "$base\daten\items.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$byId = @{}; foreach ($i in $items) { $byId[[string]$i.Id] = $i }

Write-Output "=== GEGENPROBE: mein bester Vorschlag je Slot vs. BiS-Rang ==="
Write-Output ""
foreach ($k in $slugs.Keys) {
    if (-not $bis.ContainsKey($k)) { continue }
    $bl = $bis[$k]
    if ($bl.Count -eq 0) { Write-Output "$k : keine BiS-Daten"; continue }
    $bisTop = @{}      # Slotname -> Id mit Rang 0
    $bisAll = @{}      # Id -> bester Rang
    foreach ($e in $bl) {
        if ($e.Rank -eq 0 -and -not $bisTop.ContainsKey($e.Slot)) { $bisTop[$e.Slot] = $e.Id }
        $sid = [string]$e.Id
        if (-not $bisAll.ContainsKey($sid) -or $bisAll[$sid] -gt $e.Rank) { $bisAll[$sid] = $e.Rank }
    }
    $mine = $upg | Where-Object { $_.SpecKey -eq $k -and -not $_.Unsicher -and -not $_.NichtBewertbar }
    if (-not $mine) { Write-Output "$k : keine Upgrades berechnet"; continue }
    Write-Output ("--- " + $k + " ---")
    $grp = $mine | Group-Object Slot
    foreach ($g in ($grp | Sort-Object Name)) {
        $best = $g.Group | Sort-Object Delta -Descending | Select-Object -First 1
        $sid = [string]$best.ItemId
        $rank = if ($bisAll.ContainsKey($sid)) { $bisAll[$sid] } else { -1 }
        $urteil = if ($rank -eq 0) { "BiS Platz 1" }
                  elseif ($rank -gt 0) { "BiS Platz " + ($rank+1) }
                  else { "NICHT in BiS-Liste" }
        Write-Output ("  {0,-12} {1,-38} {2,6:N1} DPS   {3}" -f $g.Name, $best.Item, $best.Delta, $urteil)
    }
    Write-Output ""
}
