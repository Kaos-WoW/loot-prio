# Schritt 0: Roster direkt aus Google Sheets importieren und roster.json aktualisieren
$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

# HIER DIE GOOGLE SHEET SPREADSHEET-ID ODER DEN GANZEN LINK EINGEBEN
$spreadsheetUrlOrId = "https://docs.google.com/spreadsheets/d/1re1Dzrs9b-gRO6PciZQ0jp0EgwT5KBv5cqLSM-jV8iE/edit?usp=sharing"

if ($spreadsheetUrlOrId -eq "DEINE_GOOGLE_SHEET_ID_ODER_LINK") {
    Write-Output "[FEHLER] Bitte trage die Google-Sheet-ID oder den Link in dieses Skript ein!"
    Exit 1
}

# Extrahiere die ID falls ein ganzer Link eingegeben wurde
$spreadsheetId = $spreadsheetUrlOrId
if ($spreadsheetUrlOrId -match "/d/([a-zA-Z0-9-_]+)") {
    $spreadsheetId = $Matches[1]
}

Write-Output "Lade Roster aus Google Sheet Übersicht (ID: $spreadsheetId)..."

# Download als CSV (sheet=Übersicht)
# Google Sheets exportiert das Sheet "Übersicht" über diese URL-Struktur:
$url = "https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv&sheet=%C3%9Cbersicht"

try {
    $tempFile = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
} catch {
    Write-Output "[FEHLER] Konnte Google Sheet nicht abrufen. Ist das Dokument wirklich öffentlich ('Jeder mit dem Link kann lesen')?"
    Exit 1
}

# CSV einlesen und parsen
# Da Google Sheets standardmäßig RFC4180 CSV ausgibt, nutzen wir den PowerShell Parser
$csv = Import-Csv -Path $tempFile -Encoding utf8

# Mapping-Tabelle für Spezialisierungen (Klasse + Spec -> SpecKey)
function Map-Spec($klasse, $specName) {
    if (-not $klasse) { return $null }
    $kl = $klasse.ToLower().Trim()
    $sp = if ($specName) { $specName.ToLower().Trim() } else { "" }

    if ($kl -like '*krieger*' -or $kl -eq 'warrior') {
        if ($sp -like '*furor*' -or $sp -like '*fury*') { return 'FURY' }
        if ($sp -like '*waffen*' -or $sp -like '*arms*') { return 'ARMS' }
    }
    if ($kl -like '*paladin*' -or $kl -like '*pala*') {
        if ($sp -like '*vergelter*' -or $sp -like '*ret*') { return 'RET' }
        if ($sp -like '*schutz*' -or $sp -like '*prot*') { return 'PROT_PALA' }
        if ($sp -like '*heil*' -or $sp -like '*holy*') { return 'HOLY_PALA' }
    }
    if ($kl -like '*scham*' -or $kl -eq 'shaman') {
        if ($sp -like '*verst*rker*' -or $sp -like '*enh*') { return 'ENH' }
        if ($sp -like '*ele*') { return 'ELE' }
        if ($sp -like '*wiederher*' -or $sp -like '*resto*' -or $sp -like '*heil*') { return 'RESTO_SHAM' }
    }
    if ($kl -like '*schur*' -or $kl -eq 'rogue') {
        return 'ROGUE'
    }
    if ($kl -like '*j*ger*' -or $kl -eq 'hunter') {
        return 'HUNT'
    }
    if ($kl -like '*hexen*' -or $kl -eq 'warlock' -or $kl -like '*hexe*') {
        return 'WLCK'
    }
    if ($kl -like '*mag*' -or $kl -eq 'mage') {
        return 'MAGE'
    }
    if ($kl -like '*priester*' -or $kl -eq 'priest') {
        if ($sp -like '*schatten*' -or $sp -like '*shadow*' -or $sp -like '*spri*') { return 'SPRI' }
        if ($sp -like '*heil*' -or $sp -like '*holy*') { return 'HOLY_PRIEST' }
    }
    if ($kl -like '*druid*') {
        if ($sp -like '*gleichgew*' -or $sp -like '*balance*' -or $sp -like '*eule*') { return 'BAL' }
        if ($sp -like '*wiederher*' -or $sp -like '*resto*' -or $sp -like '*heil*') { return 'RESTO_DRUID' }
        if ($sp -like '*feral*' -or $sp -like '*b*r*' -or $sp -like '*tank*') { return 'FERAL_TANK' }
    }
    return $null
}

$newRoster = @()
$unmapped = @()

foreach ($row in $csv) {
    # Suche die Spalten 'Spieler', 'Klasse', 'Spec'
    $spieler = $row.Spieler
    $klasse = $row.Klasse
    $specName = $row.Spec
    
    if (-not $spieler -or $spieler.Trim() -eq "") { continue }

    $specKey = Map-Spec $klasse $specName
    if ($specKey) {
        $newRoster += [pscustomobject]@{
            name = $spieler.Trim()
            spec = $specKey
        }
    } else {
        $unmapped += "$spieler ($klasse / $specName)"
    }
}

# Roster speichern
if ($newRoster.Count -gt 0) {
    $json = $newRoster | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText("$base\roster.json", $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "Roster erfolgreich aktualisiert: $($newRoster.Count) Spieler eingetragen."
    if ($unmapped.Count -gt 0) {
        Write-Output "[WARNUNG] Folgende Spieler konnten wegen ungültiger Klasse/Spec nicht gemappt werden: "
        $unmapped | ForEach-Object { Write-Output "  - $_" }
    }
} else {
    Write-Output "[FEHLER] Keine Spieler im Sheet gefunden oder Spaltenüberschriften (Spieler, Klasse, Spec) passen nicht!"
}

# Temp-Datei löschen
Remove-Item -Path $tempFile -Force
