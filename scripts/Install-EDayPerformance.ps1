param(
    [ValidateSet('MAXIMUM','ENHANCED')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Find-EdayConfig {
    # Xbox app / PC Game Pass (WinGDK) builds keep their config under
    # %LOCALAPPDATA%\Microsoft\Gears of War E-Day\WinGDK\<id>\Saved\Config\WinGDK.
    # Older builds used %LOCALAPPDATA%\FairlightConcept\Saved\Config\WinGDK, so pick
    # the WinGDK folder whose GameUserSettings.ini the game wrote most recently.
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day'),
        (Join-Path $env:LOCALAPPDATA 'FairlightConcept')
    )
    $candidates = foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter 'GameUserSettings.ini' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -eq 'WinGDK' -and $_.FullName -notmatch '\\Steam\\' }
    }
    $match = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($match) { return $match.DirectoryName }
    return $null
}

function Get-HashOrMissing([string]$path) {
    if (Test-Path -LiteralPath $path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    return '<missing>'
}

function Get-InstalledProfile([string]$gamePath) {
    $live = Get-HashOrMissing (Join-Path $gamePath 'Scalability.ini')
    $maximum = Get-HashOrMissing (Join-Path $repo 'Scalability-Maximum.ini')
    $enhanced = Get-HashOrMissing (Join-Path $repo 'Scalability.ini')
    if ($live -eq '<missing>') { return 'Default / no performance profile' }
    if ($live -eq $maximum) { return 'Maximum Performance' }
    if ($live -eq $enhanced) { return 'Enhanced Performance' }
    return 'Custom / unknown profile'
}

function Select-Profile([string]$current) {
    Write-Host 'Gears of War: E-Day performance profiles'
    Write-Host "Currently installed: $current" -ForegroundColor Cyan
    Write-Host ''
    if ($current -eq 'Maximum Performance') {
        Write-Host '  Maximum Performance [ACTIVE]' -ForegroundColor Green
        Write-Host '1 - Switch to Enhanced Performance'
        Write-Host '2 - Cancel'
        do { $choice = Read-Host 'Choose 1 or 2' } while ($choice -notin @('1','2'))
        if ($choice -eq '1') { return 'ENHANCED' }
        return $null
    }
    if ($current -eq 'Enhanced Performance') {
        Write-Host '1 - Switch to Maximum Performance'
        Write-Host '  Enhanced Performance [ACTIVE]' -ForegroundColor Green
        Write-Host '2 - Cancel'
        do { $choice = Read-Host 'Choose 1 or 2' } while ($choice -notin @('1','2'))
        if ($choice -eq '1') { return 'MAXIMUM' }
        return $null
    }
    Write-Host '1 - Install Maximum Performance'
    Write-Host '2 - Install Enhanced Performance'
    Write-Host '3 - Cancel'
    do { $choice = Read-Host 'Choose 1, 2, or 3' } while ($choice -notin @('1','2','3'))
    if ($choice -eq '1') { return 'MAXIMUM' }
    if ($choice -eq '2') { return 'ENHANCED' }
    return $null
}

function Wait-ForEdayExit {
    while (Get-Process -Name 'GoWEDay-WinGDK','GoWEDay' -ErrorAction SilentlyContinue) {
        Write-Host 'E-Day is running. Close or force-quit it; waiting for the process to exit...' -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Wait-ForEdayExit

$game = Find-EdayConfig
if (-not $game) {
    throw 'Xbox app E-Day settings were not found. Launch E-Day from the Xbox app once, close it, then run this installer again.'
}

$current = Get-InstalledProfile $game
if (-not $Profile) { $Profile = Select-Profile $current }
if (-not $Profile) {
    Write-Host 'No changes made.'
    exit 0
}
$selectedName = if ($Profile -eq 'MAXIMUM') { 'Maximum Performance' } else { 'Enhanced Performance' }
if ($current -eq $selectedName) {
    Write-Host "No operation: $selectedName is already installed." -ForegroundColor Green
    exit 0
}

$engineSource = Join-Path $repo 'Engine.ini'
$scalabilitySource = if ($Profile -eq 'MAXIMUM') {
    Join-Path $repo 'Scalability-Maximum.ini'
} else {
    Join-Path $repo 'Scalability.ini'
}
foreach ($source in @($engineSource, $scalabilitySource)) {
    if (-not (Test-Path -LiteralPath $source)) { throw "Repository file missing: $source" }
}

$rollback = Join-Path $repo 'rollback'
$rollbackEngine = Join-Path $rollback 'Engine.ini'
$rollbackSettings = Join-Path $rollback 'GameUserSettings.ini'
$rollbackScalability = Join-Path $rollback 'Scalability.ini'
$rollbackAbsent = Join-Path $rollback 'Scalability.ini.absent'
$rollbackSource = Join-Path $rollback 'config-folder.txt'
$rollbackReady = (Test-Path -LiteralPath $rollbackEngine) -and
    (Test-Path -LiteralPath $rollbackSettings) -and
    ((Test-Path -LiteralPath $rollbackScalability) -or (Test-Path -LiteralPath $rollbackAbsent))

# A snapshot taken from a different (or unrecorded) config folder cannot restore
# this one, so set it aside and capture a fresh one.
if ($rollbackReady) {
    $snapshotFolder = if (Test-Path -LiteralPath $rollbackSource) { (Get-Content -LiteralPath $rollbackSource -Raw).Trim() } else { '' }
    if ($snapshotFolder -ne $game) {
        $archive = Join-Path $repo ('rollback-old-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Move-Item -LiteralPath $rollback -Destination $archive
        Write-Host "Previous rollback snapshot was for a different folder; moved it to $archive" -ForegroundColor Yellow
        $rollbackReady = $false
    }
}

if (-not $rollbackReady) {
    New-Item -ItemType Directory -Path $rollback -Force | Out-Null
    Set-Content -LiteralPath $rollbackSource -Value $game -Encoding UTF8
    foreach ($name in @('Engine.ini','GameUserSettings.ini')) {
        $source = Join-Path $game $name
        if (-not (Test-Path -LiteralPath $source)) { throw "Current settings file missing: $source" }
        attrib -R $source | Out-Null
        Copy-Item -LiteralPath $source -Destination (Join-Path $rollback $name) -Force
    }
    if (Test-Path -LiteralPath (Join-Path $game 'Scalability.ini')) {
        Copy-Item -LiteralPath (Join-Path $game 'Scalability.ini') -Destination $rollbackScalability -Force
        if (Test-Path -LiteralPath $rollbackAbsent) { Remove-Item -LiteralPath $rollbackAbsent -Force }
    } else {
        New-Item -ItemType File -Path $rollbackAbsent -Force | Out-Null
    }
    Write-Host 'Saved the default settings once in the rollback folder.' -ForegroundColor Yellow
} else {
    Write-Host 'Existing default rollback snapshot preserved; no new backup created.'
}

Copy-Item -LiteralPath $engineSource -Destination (Join-Path $game 'Engine.ini') -Force
Copy-Item -LiteralPath $scalabilitySource -Destination (Join-Path $game 'Scalability.ini') -Force

Write-Host "Installed $Profile performance profile." -ForegroundColor Green
Write-Host "Config folder: $game"
Write-Host "Rollback snapshot: $rollback"
Write-Host 'GameUserSettings.ini was preserved, including resolution, HDR, audio, and controls.'
