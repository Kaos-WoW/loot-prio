# wowsims-cli.ps1
# Dieses Skript laedt die WoWSims CLI herunter, generiert eine RaidSimRequest-Datei,
# ermittelt die Stat-Weights fuer einen Spieler und speichert sie in daten\sim-weights.json.
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot
$binDir = "$base\bin"
$plFile = "$base\daten\players.json"
$cacheFile = "$base\daten\cache-tooltips.json"
$weightsFile = "$base\daten\sim-weights.json"

if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir | Out-Null
}

# 1. CLI herunterladen falls nicht vorhanden
$exePath = "$binDir\wowsimcli-windows.exe"
if (-not (Test-Path $exePath)) {
    Write-Output "Lade wowsimcli-windows.exe herunter..."
    $url = "https://github.com/wowsims/tbc-new/releases/latest/download/wowsimcli-windows.exe.zip"
    $zipPath = "$binDir\wowsims.zip"
    Invoke-WebRequest -Uri $url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $binDir -Force
    Remove-Item $zipPath
}

# Lade Daten
$players = Get-Content $plFile -Raw -Encoding UTF8 | ConvertFrom-Json
$cache = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Finde Kaosx (Retri Paladin)
$p = $players | Where-Object { $_.Name -eq "Kaosx" }
if (-not $p) {
    Write-Output "Spieler Kaosx nicht gefunden!"
    exit 1
}

# 2. Übersetze Armory-Ausrüstung
$slotOrder = @("HEAD","NECK","SHOULDER","BACK","CHEST","WRIST","HANDS","WAIST","LEGS","FEET","FINGER_1","FINGER_2","TRINKET_1","TRINKET_2","MAIN_HAND","OFF_HAND","RANGED")
$equippedItems = @()
foreach ($slotName in $slotOrder) {
    $itemId = 0
    if ($p.Slots.PSObject.Properties[$slotName]) {
        $itemId = [int]$p.Slots.$slotName
    }
    $equippedItems += @{ "id" = $itemId }
}

# Hilfsfunktion zur Durchführung einer Simulation
function Run-SingleSim($bonusStats) {
    $simRequest = @{
        "simOptions" = @{
            "iterations" = 4000  # Hoehere Iterationen fuer stabilere Stat-Weights
            "randomSeed" = 101
        }
        "raid" = @{
            "parties" = @(
                @{
                    "players" = @(
                        @{
                            "name" = $p.Name
                            "class" = "ClassPaladin"
                            "retributionPaladin" = @{
                                "talents" = "50000000000000000000-0532010000000000000000-0523005120033125331051"
                                "options" = @{
                                    "classOptions" = @{}
                                }
                            }
                            "equipment" = @{ "items" = $equippedItems }
                            "bonusStats" = @{ "stats" = $bonusStats }
                            "consumables" = @{
                                "flaskId" = 22861
                                "foodId" = 27655
                                "scrollStr" = $true
                                "scrollAgi" = $true
                            }
                            "buffs" = @{
                                "blessingOfKings" = $true
                                "blessingOfMight" = "BlessingOfMightImproved"
                            }
                        }
                    )
                    "buffs" = @{
                        "battleShout" = "TristateEffectImproved"
                        "leaderOfThePack" = "TristateEffectRegular"
                        "windfuryTotem" = "TristateEffectImproved"
                        "strengthOfEarthTotem" = "TristateEffectImproved"
                        "graceOfAirTotem" = "TristateEffectImproved"
                    }
                }
            )
            "buffs" = @{
                "bloodlust" = $true
                "giftOfTheWild" = "TristateEffectImproved"
                "powerWordFortitude" = "TristateEffectImproved"
            }
            "debuffs" = @{
                "sunderArmor" = $true
                "curseOfRecklessness" = $true
                "faerieFire" = "TristateEffectImproved"
                "judgementOfWisdom" = $true
                "judgementOfLight" = $true
                "improvedSealOfTheCrusader" = "TristateEffectImproved"
                "bloodFrenzy" = $true
                "mangle" = $true
                "giftOfArthas" = $true
            }
        }
        "encounter" = @{
            "duration" = 180
            "durationVariation" = 5
            "targets" = @(
                @{
                    "level" = 73
                    "armor" = 6200
                    "mobType" = "MobTypeDemon"
                }
            )
        }
    }
    
    $inputJsonPath = "$binDir\sim_input.json"
    $outputJsonPath = "$binDir\sim_output.json"
    
    # Schreibe Basis-JSON
    $jsonString = $simRequest | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($inputJsonPath, $jsonString)
    
    # Nutze Python, um die APL-Rotation sauber und fehlerfrei einzufügen
    $pyCmd = @"
import json
with open(r'$inputJsonPath', 'r', encoding='utf-8') as f:
    d = json.load(f)
with open(r'$binDir\default.apl.json', 'r', encoding='utf-8') as f:
    r = json.load(f)
d['raid']['parties'][0]['players'][0]['rotation'] = r
with open(r'$inputJsonPath', 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2)
"@
    python -c $pyCmd
    
    Start-Process -FilePath $exePath -ArgumentList "sim", "--infile", $inputJsonPath, "--outfile", $outputJsonPath -Wait -NoNewWindow
    
    if (Test-Path $outputJsonPath) {
        $res = Get-Content $outputJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($res.error) {
            throw $res.error.message
        }
        return [double]$res.raidMetrics.parties[0].players[0].dps.avg
    }
    throw "Simulations-Ergebnis wurde nicht erstellt!"
}

# 3. Führe Stat-Weights Simulation durch
Write-Output "--- Starte Stat-Weights Ermittlung fuer $($p.Name) ---"
$baseStats = @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) # leeres Stat-Array
$baseDps = Run-SingleSim $baseStats
Write-Output "  Basis-DPS: $baseDps"

# Wir erhoehen die Stats um jeweils 30 Punkte
# WoWSims Stat Indices (TBC):
# 0=Strength, 1=Agility, 5=SpellDamage, 17=AttackPower, 20=MeleeHit, 21=MeleeCrit, 22=MeleeHaste
$statsToTest = @{
    "Str"     = @{ Index=0; Label="Staerke" }
    "Agi"     = @{ Index=1; Label="Beweglichkeit" }
    "AP"      = @{ Index=17; Label="Angriffskraft" }
    "SP"      = @{ Index=5;  Label="Zaubermacht" }
    "Treffer" = @{ Index=20; Label="Trefferwertung" }
    "Krit"    = @{ Index=21; Label="Krit-Wertung" }
    "Tempo"   = @{ Index=22; Label="Tempowertung" }
    "ArP"     = @{ Index=23; Label="Ruestungsdurchschlag" }
    "Waffk"   = @{ Index=24; Label="Waffenkunde" }
}

$weights = @{}
$delta = 30.0

foreach ($statKey in $statsToTest.Keys) {
    $st = $statsToTest[$statKey]
    Write-Output "  Simuliere +$delta $($st.Label)..."
    
    $testStats = $baseStats.Clone()
    $testStats[$st.Index] = $delta
    
    $newDps = Run-SingleSim $testStats
    $statWeight = ($newDps - $baseDps) / $delta
    if ($statWeight -lt 0) { $statWeight = 0.0 }
    
    $weights[$statKey] = [math]::Round($statWeight, 3)
    Write-Output "    DPS: $newDps (Gewicht: $($weights[$statKey]))"
}

# 4. Berechne Waffenhand-Wert (MH) aus AP (Verhältnis beim Retri: ~13.05)
if ($weights.ContainsKey("AP")) {
    $weights["MH"] = [math]::Round($weights["AP"] * 13.05, 3)
}

# 4. Speichere Gewichte
$outputWeights = @{}
if (Test-Path $weightsFile) {
    $outputWeights = Get-Content $weightsFile -Raw -Encoding UTF8 | ConvertFrom-Json
}
$outputWeights.$($p.Name) = $weights

$outputWeights | ConvertTo-Json -Depth 5 | Out-File $weightsFile -Encoding utf8
Write-Output ""
Write-Output "Erfolgreich! Stat-Gewichte in $weightsFile gespeichert."
