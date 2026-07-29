# Scrapes all 17 Wowhead Phase 3 BiS guides directly via PowerShell and writes bis-listen.json
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

# Da das Skript im Ordner 'daten' liegt, ist der Ausgabepfad:
$outputFile = "$base\bis-listen.json"

$specs = [ordered]@{
    "FURY"        = "https://www.wowhead.com/tbc/guide/fury-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "ARMS"        = "https://www.wowhead.com/tbc/guide/arms-warrior-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "RET"         = "https://www.wowhead.com/tbc/guide/retribution-paladin-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "ENH"         = "https://www.wowhead.com/tbc/guide/enhancement-shaman-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "ROGUE"       = "https://www.wowhead.com/tbc/guide/combat-rogue-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "HUNT"        = "https://www.wowhead.com/tbc/guide/beast-mastery-hunter-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "WLCK"        = "https://www.wowhead.com/tbc/guide/destruction-warlock-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "MAGE"        = "https://www.wowhead.com/tbc/guide/arcane-mage-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "SPRI"        = "https://www.wowhead.com/tbc/guide/shadow-priest-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "ELE"         = "https://www.wowhead.com/tbc/guide/elemental-shaman-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "BAL"         = "https://www.wowhead.com/tbc/guide/balance-druid-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    
    # Tanks
    "PROT_PALA"   = "https://www.wowhead.com/tbc/guide/protection-paladin-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "FERAL_TANK"  = "https://www.wowhead.com/tbc/guide/feral-druid-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    
    # Heiler
    "RESTO_SHAM"  = "https://www.wowhead.com/tbc/guide/shaman-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "HOLY_PRIEST" = "https://www.wowhead.com/tbc/guide/priest-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "RESTO_DRUID" = "https://www.wowhead.com/tbc/guide/druid-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    "HOLY_PALA"   = "https://www.wowhead.com/tbc/guide/holy-paladin-healer-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
}

# Fallbacks for specs if their standard URLs 404
$urlFallbacks = @{
    "ROGUE"       = @(
        "https://www.wowhead.com/tbc/guide/rogue-dps-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
    "PROT_PALA"   = @(
        "https://www.wowhead.com/tbc/guide/protection-paladin-tank-phase-3-best-in-slot-gear-burning-crusade"
        "https://www.wowhead.com/tbc/guide/protection-paladin-tank-bt-hyjal-phase-3-best-in-slot-gear"
        "https://www.wowhead.com/tbc/guide/paladin-tank-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
    "RESTO_SHAM"  = @(
        "https://www.wowhead.com/tbc/guide/restoration-shaman-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
    "HOLY_PRIEST" = @(
        "https://www.wowhead.com/tbc/guide/holy-priest-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
    "RESTO_DRUID" = @(
        "https://www.wowhead.com/tbc/guide/restoration-druid-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
    "HOLY_PALA"   = @(
        "https://www.wowhead.com/tbc/guide/holy-paladin-heal-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
}

function Clean-Html($s) {
    $s = [regex]::Replace($s, '<[^>]+>', '')
    $s = [System.Web.HttpUtility]::HtmlDecode($s)
    return $s.Trim()
}

function Normalize-Slot($s) {
    $s = $s.ToLower()
    if ($s -match 'head|helm') { return 'Head' }
    if ($s -match 'neck|amulet') { return 'Neck' }
    if ($s -match 'shoulder') { return 'Shoulders' }
    if ($s -match 'back|cloak') { return 'Back' }
    if ($s -match 'chest|robe') { return 'Chest' }
    if ($s -match 'wrist|bracer') { return 'Wrists' }
    if ($s -match 'hand|glove') { return 'Hands' }
    if ($s -match 'waist|belt') { return 'Waist' }
    if ($s -match 'leg') { return 'Legs' }
    if ($s -match 'feet|boot') { return 'Feet' }
    if ($s -match 'finger|ring') { return 'Fingers' }
    if ($s -match 'trinket') { return 'Trinkets' }
    if ($s -match 'main hand|one-hand') { return 'Main Hand' }
    if ($s -match 'off hand|shield|held') { return 'Off Hand' }
    if ($s -match 'two-hand') { return 'Two-Hand' }
    if ($s -match 'ranged|bow|gun|relic|libram|idol|totem') { return 'Ranged' }
    return $null
}

# We need HttpUtility to decode html entities
Add-Type -AssemblyName System.Web

$results = [ordered]@{}

# Helper function to try fetching URLs
function Fetch-With-Fallbacks($specKey, $primaryUrl) {
    $urlsToTry = @($primaryUrl)
    if ($urlFallbacks.ContainsKey($specKey)) {
        $urlsToTry += $urlFallbacks[$specKey]
    }
    
    foreach ($url in $urlsToTry) {
        try {
            $r = Invoke-WebRequest -Uri $url -TimeoutSec 15 -UseBasicParsing
            if ($r.StatusCode -eq 200) {
                return $r.Content
            }
        } catch {
            # continue to next fallback
        }
    }
    return $null
}

foreach ($specKey in $specs.Keys) {
    $url = $specs[$specKey]
    Write-Output "Fetching $specKey..."
    
    $html = Fetch-With-Fallbacks $specKey $url
    
    if (-not $html) {
        Write-Output "  => ERROR: Could not fetch $specKey (tried fallbacks)"
        $results[$specKey] = @()
        continue
    }

    # Find headers: <h2 ...> or <h3 ...>
    $hMatches = [regex]::Matches($html, '(?is)<h([234])[^>]*>(.*?)</h\1>')
    $specItems = @()
    
    for ($i = 0; $i -lt $hMatches.Count; $i++) {
        $m = $hMatches[$i]
        $headerText = Clean-Html $m.Groups[2].Value
        
        $slot = Normalize-Slot $headerText
        if (-not $slot) { continue }
        
        $startPos = $m.Index + $m.Length
        $endPos = $html.Length
        if ($i + 1 -lt $hMatches.Count) {
            $endPos = $hMatches[$i+1].Index
        }
        
        $sectionHtml = $html.Substring($startPos, $endPos - $startPos)
        
        # Parse rows <tr>...</tr>
        $rows = [regex]::Matches($sectionHtml, '(?is)<tr[^>]*>(.*?)</tr>')
        if ($rows.Count -lt 1) { continue }
        
        $rankCounter = 0
        foreach ($row in $rows) {
            $rowVal = $row.Value
            # Skip header rows
            if ($rowVal.ToLower() -match 'item' -and ($rowVal.ToLower() -match 'source' -or $rowVal.ToLower() -match 'stat')) {
                continue
            }
            
            # Find item link: item=NNNNN or item/NNNNN
            $itemMatch = [regex]::Match($rowVal, '(?is)href="[^"]*(?:item[=/])(\d+)[^"]*">(.*?)</a>')
            if (-not $itemMatch.Success) { continue }
            
            $itemId = [int]$itemMatch.Groups[1].Value
            $itemName = Clean-Html $itemMatch.Groups[2].Value
            
            # Extract first column cell to check for "Best/BiS" or "Optional/Alternative"
            $cells = [regex]::Matches($rowVal, '(?is)<td[^>]*>(.*?)</td>')
            $rank = $rankCounter
            if ($cells.Count -gt 0) {
                $col0 = (Clean-Html $cells[0].Groups[1].Value).ToLower()
                if ($col0 -match 'best|bis') {
                    $rank = 0
                } elseif ($col0 -match 'alt|opt') {
                    $rank = [math]::Max(1, $rankCounter)
                }
            }
            
            $specItems += [pscustomobject]@{
                Slot = $slot
                Rank = $rank
                Id   = $itemId
                Name = $itemName
            }
            $rankCounter++
        }
    }
    
    $results[$specKey] = $specItems
    Write-Output "  => Found $($specItems.Count) items for $specKey"
}

# Convert results to JSON and write to file
$results | ConvertTo-Json -Depth 5 | Out-File $outputFile -Encoding utf8
Write-Output "`nSaved to $outputFile"
