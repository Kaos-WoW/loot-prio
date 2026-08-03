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

# Statarray des Ziels (Laenge 46 wie beim Spieler). Nur die Indizes, die das WoWSims-Preset
# "Raid Target" belegt: 17 = Angriffskraft, 27 = Verteidigung, 31 = RUESTUNG, 33 = Leben.
$targetStats = @(0) * 46
$targetStats[17] = 320
$targetStats[27] = 54
$targetStats[31] = 7685      # Grundruestung eines Stufe-73-Raidbosses
$targetStats[33] = 6070400

# Hilfsfunktion zur Durchführung einer Simulation
function Run-SingleSim($bonusStats) {
    $simRequest = @{
        "simOptions" = @{
            "iterations" = 10000  # Hoehere Iterationen fuer stabilere Stat-Weights (rund 2s je Sim)
            "randomSeed" = 101
        }
        "raid" = @{
            "parties" = @(
                @{
                    "players" = @(
                        @{
                            "name" = $p.Name
                            "class" = "ClassPaladin"
                            # ACHTUNG: Der Talentstring gehoert als "talentsString" DIREKT an den
                            # Spieler. Frueher stand er als "talents" im Spec-Block - dort wird er
                            # von der CLI stillschweigend ignoriert (kein Fehler, kein Hinweis), und
                            # die Sim lief talentlos: 614 statt 1456 DPS. Die daraus abgeleiteten
                            # Stat-Gewichte waren dadurch um Faktor 2,4-3,5 zu klein.
                            # Gegenprobe bei Aenderungen: mit leerem String muss die DPS deutlich
                            # einbrechen. Bleibt sie gleich, greift das Feld nicht.
                            "talentsString" = "50000000000000000000-0532010000000000000000-0523005120033125331051"
                            "retributionPaladin" = @{
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
                    "mobType" = "MobTypeDemon"
                    # ACHTUNG: Ein Feld "armor" gibt es hier NICHT. Es wurde frueher gesetzt und von
                    # der CLI stillschweigend verworfen - die Sim lief dadurch gegen ein Ziel mit
                    # NULL Ruestung (1373 statt 1137 DPS, rund 17 % zu hoch), und
                    # Ruestungsdurchschlag war folgerichtig wertlos (Gewicht immer 0).
                    # Die Ruestung steht im Ziel-Statarray auf Index 31. Werte uebernommen vom
                    # WoWSims-Preset "Raid Target" (per 'wowsimcli decodelink' ausgelesen).
                    # Die Ruestungs-Debuffs (Zerreissen, Feenfeuer, Fluch der Tollkuehnheit) stehen
                    # im debuffs-Block und werden von der Sim selbst abgezogen - hier gehoert
                    # deshalb der UNGEDEBUFFTE Grundwert hinein.
                    # Gegenprobe: mit stats[31]=0 muss die DPS deutlich steigen.
                    "stats" = $targetStats
                    "minBaseDamage" = 15113
                    "damageSpread" = 0.5
                    "swingSpeed" = 2.0
                    "parryHaste" = $true
                    "canCrush" = $true
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

# Probengroesse fuer die Gewichtsmessung.
# ACHTUNG: Frueher standen hier 30 Punkte - das ist zu klein. Tempo wirkt bei TBC nicht linear,
# sondern ueber Angriffstempo-Schwellen (beim Ret durch Seal-Twisting). Gemessen an Kaosx:
#   +30 Tempo  ->  -1,4 DPS  (Gewicht wurde auf 0 geklemmt = "Tempo ist wertlos")
#   +100 Tempo -> +47,6 DPS  (Gewicht 0,476 = so wertvoll wie Krit)
# Die 0 war also ein Artefakt der Probengroesse, kein Ergebnis. Bei linearen Stats aendert die
# groessere Probe nichts (Krit liefert bei +30 und +100 identisch 0,483), sie kostet nur Rechenzeit
# - und die liegt bei rund 2 Sekunden je Sim.
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
$delta = 100.0

foreach ($statKey in $statsToTest.Keys) {
    $st = $statsToTest[$statKey]
    Write-Output "  Simuliere +$delta $($st.Label)..."
    
    $testStats = $baseStats.Clone()
    $testStats[$st.Index] = $delta
    
    $newDps = Run-SingleSim $testStats
    $statWeight = ($newDps - $baseDps) / $delta
    if ($statWeight -lt 0) {
        # Negativ heisst fast immer: der Stat ist am Cap (Treffer/Waffenkunde) oder liegt in einem
        # Schwellen-Totbereich. Wir klemmen auf 0, sagen es aber - stilles Klemmen hat den
        # Tempo-Fehler oben lange verdeckt. In Value-Item faengt der Cap-Schutz die Folgen ab.
        Write-Warning ("Negatives Gewicht fuer " + $st.Label + " (" + [math]::Round($statWeight,3) + ") - auf 0 geklemmt. Cap oder Schwellenwert pruefen.")
        $statWeight = 0.0
    }

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
