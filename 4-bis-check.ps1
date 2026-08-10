# Schritt 4: Gegenprobe der Empfehlungen gegen veroeffentlichte BiS-Listen.
#
# Quelle ist ausschliesslich Wowhead (daten/bis-listen-phasen.json, erzeugt von
# daten/scrape-bis-wowhead.py) - ausdrueckliche Vorgabe des Nutzers. Frueher lief
# der DPS-Teil gegen warcrafttavern.com; die dort gemessenen Werte (58 % / 79 %)
# sind mit den heutigen deshalb NICHT vergleichbar.
#
# Geprueft werden alle Phasen, fuer die eine Upgrade-Datei vorliegt.
# Aufruf:  .\4-bis-check.ps1            (alle vorhandenen Phasen)
#          .\4-bis-check.ps1 -Phasen 5  (nur eine)
param([int[]]$Phasen = @(3, 4, 5))

$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

$dpsSpecs      = @('FURY','ARMS','RET','ENH','ROGUE','HUNT','WLCK','MAGE','SPRI','ELE','BAL')
$tankHealSpecs = @('PROT_PALA','FERAL_TANK','RESTO_SHAM','HOLY_PALA','RESTO_DRUID','HOLY_PRIEST')

$phasenDatei = "$base\daten\bis-listen-phasen.json"
if (-not (Test-Path $phasenDatei)) {
    throw "bis-listen-phasen.json fehlt - erst 'python daten\scrape-bis-wowhead.py' laufen lassen."
}
$alleBis = Get-Content $phasenDatei -Raw -Encoding UTF8 | ConvertFrom-Json

# Prueft je Spec den besten Vorschlag pro Slot gegen die BiS-Liste.
# Die Zaehler laufen ueber [ref]-Parameter, NICHT ueber den Rueckgabewert: eine
# PowerShell-Funktion sammelt alles, was sie in die Pipeline schreibt, in ihren
# Rueckgabewert ein - der Diagnosetext landete sonst in der Variablen statt auf
# der Konsole (siehe AGENTS.md).
function Show-BisBlock {
    param($bis, $upg, $specKeys, $sortField, $unitFormat, [ref]$geprueft, [ref]$platz1, [ref]$top3)

    foreach ($k in $specKeys) {
        if (-not $bis.PSObject.Properties[$k]) { Write-Output "$k : keine BiS-Daten"; continue }
        $bl = $bis.$k
        if ($bl.Count -eq 0) { Write-Output "$k : keine BiS-Daten"; continue }
        $bisAll = @{}      # Id -> bester Rang
        foreach ($e in $bl) {
            $sid = [string]$e.Id
            if (-not $bisAll.ContainsKey($sid) -or $bisAll[$sid] -gt $e.Rank) { $bisAll[$sid] = $e.Rank }
        }
        $mine = $upg | Where-Object { $_.SpecKey -eq $k -and -not $_.Unsicher -and -not $_.NichtBewertbar }
        if (-not $mine) { Write-Output "$k : keine Upgrades berechnet"; continue }
        Write-Output ("--- " + $k + " ---")
        foreach ($g in ($mine | Group-Object Slot | Sort-Object Name)) {
            $best = $g.Group | Sort-Object $sortField -Descending | Select-Object -First 1
            $sid = [string]$best.ItemId
            $rank = if ($bisAll.ContainsKey($sid)) { $bisAll[$sid] } else { -1 }
            $urteil = if ($rank -eq 0) { "BiS Platz 1" }
                      elseif ($rank -gt 0) { "BiS Platz " + ($rank + 1) }
                      else { "NICHT in BiS-Liste" }
            Write-Output ("  {0,-12} {1,-38} {2,12}   {3}" -f $g.Name, $best.Item, ($unitFormat -f $best.$sortField), $urteil)
            $geprueft.Value++
            if ($rank -eq 0) { $platz1.Value++ }
            if ($rank -ge 0 -and $rank -le 2) { $top3.Value++ }
        }
        Write-Output ""
    }
}

$zusammenfassung = @()

foreach ($phase in $Phasen) {
    $upgDatei = if ($phase -eq 3) { "upgrades.json" } else { "upgrades-p$phase.json" }
    if (-not (Test-Path "$base\daten\$upgDatei")) {
        Write-Output "Phase $phase uebersprungen - $upgDatei fehlt."
        continue
    }
    if (-not $alleBis.PSObject.Properties["$phase"]) {
        Write-Output "Phase $phase uebersprungen - kein Block in bis-listen-phasen.json."
        continue
    }
    $bis = $alleBis."$phase"
    $upg = Get-Content "$base\daten\$upgDatei" -Raw -Encoding UTF8 | ConvertFrom-Json

    Write-Output "############ PHASE $phase ############"
    Write-Output ""
    Write-Output "=== DPS: bester Vorschlag je Slot vs. BiS-Rang (Wowhead) ==="
    Write-Output ""
    $dG = 0; $dP = 0; $dT = 0
    Show-BisBlock $bis $upg $dpsSpecs 'Delta' '{0:N1} DPS' ([ref]$dG) ([ref]$dP) ([ref]$dT)

    Write-Output "=== TANK/HEILER: bester Vorschlag je Slot vs. BiS-Rang (Wowhead) ==="
    Write-Output ""
    $tG = 0; $tP = 0; $tT = 0
    Show-BisBlock $bis $upg $tankHealSpecs 'Pct' '{0:N2} %' ([ref]$tG) ([ref]$tP) ([ref]$tT)

    $zusammenfassung += [pscustomobject]@{
        Phase = $phase; Gruppe = 'DPS';         Geprueft = $dG; Platz1 = $dP; Top3 = $dT
    }
    $zusammenfassung += [pscustomobject]@{
        Phase = $phase; Gruppe = 'Tank/Heiler'; Geprueft = $tG; Platz1 = $tP; Top3 = $tT
    }
}

Write-Output "=== ZUSAMMENFASSUNG (Quelle: Wowhead) ==="
foreach ($z in $zusammenfassung) {
    if ($z.Geprueft -le 0) { continue }
    $p1 = [math]::Round(100 * $z.Platz1 / $z.Geprueft, 0)
    $t3 = [math]::Round(100 * $z.Top3   / $z.Geprueft, 0)
    Write-Output ("Phase {0}  {1,-12}: {2,3} Empfehlungen - {3,3}% auf BiS-Platz 1 - {4,3}% in den BiS-Top-3" -f `
        $z.Phase, $z.Gruppe, $z.Geprueft, $p1, $t3)
}
