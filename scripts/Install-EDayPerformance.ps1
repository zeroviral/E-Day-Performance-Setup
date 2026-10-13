param(
    [ValidateSet('MAXIMUM','ENHANCED')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Find-PlatformConfigs {
    $base = Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day'
    $definitions = @(
        [pscustomobject]@{ Key = 'STEAM'; Name = 'Steam'; Root = (Join-Path $base 'Steam') },
        [pscustomobject]@{ Key = 'WINGDK'; Name = 'Xbox / WinGDK'; Root = (Join-Path $base 'WinGDK') }
    )
    $found = @()
    foreach ($definition in $definitions) {
        if (-not (Test-Path -LiteralPath $definition.Root)) { continue }
        $folders = @((Get-Item -LiteralPath $definition.Root)) + @(Get-ChildItem -LiteralPath $definition.Root -Directory -Recurse -ErrorAction SilentlyContinue)
        $match = $folders | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'GameUserSettings.ini') } | Select-Object -First 1
        if ($match) {
            $found += [pscustomobject]@{
                Key = $definition.Key
                Name = $definition.Name
                Path = $match.FullName
            }
        }
    }
    return $found
}

function Select-Platform([array]$platforms) {
    if ($platforms.Count -eq 1) { return $platforms[0] }
    Write-Host 'Multiple E-Day installations found:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $platforms.Count; $i++) {
        Write-Host ("{0} - {1}: {2}" -f ($i + 1), $platforms[$i].Name, $platforms[$i].Path)
    }
    Write-Host ("{0} - Cancel" -f ($platforms.Count + 1))
    $valid = 1..($platforms.Count + 1) | ForEach-Object { $_.ToString() }
    do { $choice = Read-Host ("Choose 1-{0}" -f ($platforms.Count + 1)) } while ($choice -notin $valid)
    if ([int]$choice -eq $platforms.Count + 1) { return $null }
    return $platforms[[int]$choice - 1]
}

function Get-RollbackPath([string]$platformKey) {
    $rollbackRoot = Join-Path $repo 'rollback'
    # Preserve the existing repository layout: rollback\ is the legacy Steam snapshot.
    if ($platformKey -eq 'STEAM' -and (Test-Path -LiteralPath (Join-Path $rollbackRoot 'Engine.ini'))) {
        return $rollbackRoot
    }
    return Join-Path $rollbackRoot $platformKey
}

function Get-HashOrMissing([string]$path) {
    if (Test-Path -LiteralPath $path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    return '<missing>'
}

function Get-InstalledProfile([string]$gamePath) {
    $live = Get-HashOrMissing (Join-Path $gamePath 'Scalability.ini')
    $maximum = Get-HashOrMissing (Join-Path $repo 'profiles\Scalability-Maximum.ini')
    $enhanced = Get-HashOrMissing (Join-Path $repo 'profiles\Scalability.ini')
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
    while (Get-Process -Name 'GoWEDay-Steam','GoWEDay','GoWEDay-WinGDK' -ErrorAction SilentlyContinue) {
        Write-Host 'E-Day is running. Close or force-quit it; waiting for the process to exit...' -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

$platforms = @(Find-PlatformConfigs)
if ($platforms.Count -eq 0) {
    throw 'E-Day settings were not found. Launch E-Day once, close it, then run this installer again.'
}
$platform = Select-Platform $platforms
if (-not $platform) {
    Write-Host 'No changes made.'
    exit 0
}
$game = $platform.Path
Write-Host "Selected platform: $($platform.Name)" -ForegroundColor Cyan

Wait-ForEdayExit

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

$profiles = Join-Path $repo 'profiles'
$engineSource = Join-Path $profiles 'Engine.ini'
$scalabilitySource = if ($Profile -eq 'MAXIMUM') {
    Join-Path $profiles 'Scalability-Maximum.ini'
} else {
    Join-Path $profiles 'Scalability.ini'
}
foreach ($source in @($engineSource, $scalabilitySource)) {
    if (-not (Test-Path -LiteralPath $source)) { throw "Repository file missing: $source" }
}

$rollback = Get-RollbackPath $platform.Key
$rollbackEngine = Join-Path $rollback 'Engine.ini'
$rollbackSettings = Join-Path $rollback 'GameUserSettings.ini'
$rollbackScalability = Join-Path $rollback 'Scalability.ini'
$rollbackAbsent = Join-Path $rollback 'Scalability.ini.absent'
$rollbackReady = (Test-Path -LiteralPath $rollbackEngine) -and
    (Test-Path -LiteralPath $rollbackSettings) -and
    ((Test-Path -LiteralPath $rollbackScalability) -or (Test-Path -LiteralPath $rollbackAbsent))

if (-not $rollbackReady) {
    New-Item -ItemType Directory -Path $rollback -Force | Out-Null
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
    Write-Host "Saved the $($platform.Name) default settings once in the rollback folder." -ForegroundColor Yellow
} else {
    Write-Host 'Existing default rollback snapshot preserved; no new backup created.'
}

Copy-Item -LiteralPath $engineSource -Destination (Join-Path $game 'Engine.ini') -Force
Copy-Item -LiteralPath $scalabilitySource -Destination (Join-Path $game 'Scalability.ini') -Force

Write-Host "Installed $Profile performance profile." -ForegroundColor Green
Write-Host "Config folder: $game"
Write-Host "Rollback snapshot: $rollback"
Write-Host 'GameUserSettings.ini was preserved, including resolution, HDR, audio, and controls.'
