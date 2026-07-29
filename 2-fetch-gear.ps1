# Schritt 2: Ausruestung der Raider live vom Armory holen, Aenderungen melden, Item-Werte nachladen
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot
$cacheFile = "$base\daten\cache-tooltips.json"
$plFile    = "$base\daten\players.json"

$roster = Get-Content "$base\roster.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# vorherigen Stand fuer den Vergleich merken
$alt = @{}
if (Test-Path $plFile) {
    foreach ($p in (Get-Content $plFile -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        $h = @{}
        foreach ($s in $p.Slots.PSObject.Properties) { $h[$s.Name] = $s.Value }
        $alt[$p.Name] = $h
    }
}

# Der Armory braucht echte UTF-8-Bytes (sonst finden Namen mit Umlaut nichts),
# lehnt aber ein "charset=utf-8" im Content-Type mit HTTP 400 ab. Deshalb
# ByteArrayContent mit explizit gesetztem, nacktem Header statt Invoke-RestMethod.
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
function Get-Equipment($name) {
    $body  = @{ region="eu"; realm="thunderstrike"; name=$name; flavor="tbc-anniversary" } | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $c = New-Object System.Net.Http.ByteArrayContent(,$bytes)
    $c.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/json")
    $resp = $http.PostAsync("https://classic-armory.org/api/v1/character/equipment", $c).Result
    if ([int]$resp.StatusCode -ne 200) { return $null }
    return ($resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json)
}

$players = @()
$fehler  = @()
foreach ($r in $roster) {
    try { $resp = Get-Equipment $r.name }
    catch { $fehler += ($r.name + " (Abruf)"); continue }
    if (-not $resp -or -not $resp.equipment) { $fehler += ($r.name + " (keine Daten)"); continue }
    
    $slots = @{}
    foreach ($e in $resp.equipment) { $slots[$e.slot.type] = [int]$e.item.id }
    
    # --- Offspec-Plausibilitaetscheck ---
    if ($r.spec -eq 'PROT_PALA') {
        $hasShield = $false
        # Prüfen ob ein Schild in OFF_HAND getragen wird
        if ($slots.ContainsKey('OFF_HAND')) {
            $offId = $slots['OFF_HAND']
            # Bulwark, Antonidas, Kazrogal, Felstone, Bastion, Aegis, Illidari etc.
            # Schilde haben im Tooltip-Cache meist das Wort "Shield" oder wir checken bekannte Schild-IDs
            # Einfachste Prüfung: Hat der Spieler überhaupt etwas im OFF_HAND Slot?
            # Wenn er eine 2H-Waffe trägt, hat er normalerweise kein OFF_HAND.
            if ($offId -gt 0) { $hasShield = $true }
        }
        if (-not $hasShield) {
            Write-Output "  [WARNUNG] $($r.name) (PROT_PALA) hat kein Schild angelegt! (Offspec/PvP?). Behalte alten Stand."
            # Alten Stand wiederherstellen
            if ($alt.ContainsKey($r.name)) {
                $slots = $alt[$r.name]
            } else {
                # Falls gar kein alter Stand da ist, müssen wir es nehmen, aber warnen
                Write-Output "  [INFO] Kein alter Stand fuer $($r.name) vorhanden. Verwende geladene Daten."
            }
        }
    }
    
    $players += [pscustomobject]@{ Name = $r.name; Spec = $r.spec; Slots = $slots }
}
Write-Output ("Abgerufen: " + $players.Count + " von " + $roster.Count)
if ($fehler.Count) { Write-Output ("Fehlgeschlagen: " + ($fehler -join ", ")) }

# Tooltips fuer alle getragenen Teile nachladen
$cache = @{}
if (Test-Path $cacheFile) {
    $raw = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $cache[$p.Name] = $p.Value }
}
$neu = 0
foreach ($p in $players) {
    foreach ($s in $p.Slots.Keys) {
        $k = [string]$p.Slots[$s]
        if ($cache.ContainsKey($k)) { continue }
        try {
            $t = Invoke-RestMethod -Uri ("https://nether.wowhead.com/tbc/tooltip/item/$k" + "?locale=0") -TimeoutSec 25
            $cache[$k] = [pscustomobject]@{ name = $t.name; tooltip = $t.tooltip }
            $neu++
        } catch { }
    }
}
$cache | ConvertTo-Json -Depth 4 -Compress | Out-File $cacheFile -Encoding utf8
Write-Output ("Neue Item-Tooltips geladen: $neu")

# Aenderungen gegenueber dem letzten Stand
Write-Output ""
Write-Output "=== AENDERUNGEN SEIT DEM LETZTEN ABRUF ==="
$anzahl = 0
foreach ($p in ($players | Sort-Object Name)) {
    if (-not $alt.ContainsKey($p.Name)) { Write-Output ("  " + $p.Name + ": neu erfasst"); continue }
    $vorher = $alt[$p.Name]
    $zeilen = @()
    foreach ($s in ($p.Slots.Keys | Sort-Object)) {
        $neuId = $p.Slots[$s]
        $altId = $null
        if ($vorher.ContainsKey($s)) { $altId = [int]$vorher[$s] }
        if ($altId -ne $neuId) {
            $nName = if ($cache.ContainsKey([string]$neuId)) { $cache[[string]$neuId].name } else { "Item $neuId" }
            $aName = if ($altId -and $cache.ContainsKey([string]$altId)) { $cache[[string]$altId].name } else { "(leer)" }
            $zeilen += ("      {0,-12} {1}  ->  {2}" -f $s, $aName, $nName)
        }
    }
    if ($zeilen.Count) {
        $anzahl += $zeilen.Count
        Write-Output ("  " + $p.Name + ":")
        $zeilen | ForEach-Object { Write-Output $_ }
    }
}
if ($anzahl -eq 0) { Write-Output "  keine" } else { Write-Output ("`n  insgesamt $anzahl Slotwechsel") }

$players | ConvertTo-Json -Depth 4 | Out-File $plFile -Encoding utf8
Write-Output ""
Write-Output "players.json aktualisiert."
