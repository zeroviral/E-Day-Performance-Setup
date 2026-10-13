param(
    [ValidateSet('MAXIMUM','ENHANCED')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Find-EdayConfig {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day\Steam'),
        (Join-Path $env:LOCALAPPDATA 'FairlightConcept')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $folders = @((Get-Item -LiteralPath $root)) + @(Get-ChildItem -LiteralPath $root -Directory -Recurse -ErrorAction SilentlyContinue)
        $match = $folders | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'GameUserSettings.ini') } | Select-Object -First 1
        if ($match) { return $match.FullName }
    }
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
    Write-Host '1 - Maximum Performance'
    Write-Host '2 - Enhanced Performance'
    Write-Host '3 - Cancel'
    do { $choice = Read-Host 'Choose 1, 2, or 3' } while ($choice -notin @('1','2','3'))
    switch ($choice) {
        '1' { return 'MAXIMUM' }
        '2' { return 'ENHANCED' }
        default { return $null }
    }
}

function Wait-ForEdayExit {
    while (Get-Process -Name 'GoWEDay-Steam','GoWEDay','GoWEDay-WinGDK' -ErrorAction SilentlyContinue) {
        Write-Host 'E-Day is running. Close or force-quit it; waiting for the process to exit...' -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Wait-ForEdayExit

$game = Find-EdayConfig
if (-not $game) {
    throw 'E-Day settings were not found. Launch E-Day once, close it, then run this installer again.'
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

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $repo ("backups\before-install-$stamp")
New-Item -ItemType Directory -Path $backup -Force | Out-Null

foreach ($name in @('Engine.ini','GameUserSettings.ini','Scalability.ini')) {
    $source = Join-Path $game $name
    if (Test-Path -LiteralPath $source) {
        attrib -R $source | Out-Null
        Copy-Item -LiteralPath $source -Destination (Join-Path $backup $name) -Force
    } elseif ($name -eq 'Scalability.ini') {
        New-Item -ItemType File -Path (Join-Path $backup 'Scalability.ini.absent') -Force | Out-Null
    }
}

# Keep a clearly named, portable rollback copy alongside the repository.
$rollback = Join-Path $repo 'rollback'
New-Item -ItemType Directory -Path $rollback -Force | Out-Null
foreach ($name in @('Engine.ini','GameUserSettings.ini')) {
    Copy-Item -LiteralPath (Join-Path $backup $name) -Destination (Join-Path $rollback $name) -Force
}
$rollbackScalability = Join-Path $rollback 'Scalability.ini'
if (Test-Path -LiteralPath (Join-Path $backup 'Scalability.ini')) {
    Copy-Item -LiteralPath (Join-Path $backup 'Scalability.ini') -Destination $rollbackScalability -Force
    $absentMarker = Join-Path $rollback 'Scalability.ini.absent'
    if (Test-Path -LiteralPath $absentMarker) { Remove-Item -LiteralPath $absentMarker -Force }
} else {
    if (Test-Path -LiteralPath $rollbackScalability) { Remove-Item -LiteralPath $rollbackScalability -Force }
    New-Item -ItemType File -Path (Join-Path $rollback 'Scalability.ini.absent') -Force | Out-Null
}

Copy-Item -LiteralPath $engineSource -Destination (Join-Path $game 'Engine.ini') -Force
Copy-Item -LiteralPath $scalabilitySource -Destination (Join-Path $game 'Scalability.ini') -Force

Write-Host "Installed $Profile performance profile." -ForegroundColor Green
Write-Host "Config folder: $game"
Write-Host "Backup: $backup"
Write-Host 'GameUserSettings.ini was preserved, including resolution, HDR, audio, and controls.'
