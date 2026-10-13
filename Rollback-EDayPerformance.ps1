$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$rollback = Join-Path $repo 'rollback'

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

if (-not (Test-Path -LiteralPath $rollback)) { throw 'No rollback configuration exists yet. Run the installer first.' }
$game = Find-EdayConfig
if (-not $game) { throw 'E-Day settings were not found.' }
Write-Host "Currently installed: $(Get-InstalledProfile $game)" -ForegroundColor Cyan

$same = $true
foreach ($name in @('Engine.ini','GameUserSettings.ini')) {
    if ((Get-HashOrMissing (Join-Path $game $name)) -ne (Get-HashOrMissing (Join-Path $rollback $name))) { $same = $false }
}
$liveScalability = Join-Path $game 'Scalability.ini'
$savedScalability = Join-Path $rollback 'Scalability.ini'
$savedScalabilityAbsent = Test-Path -LiteralPath (Join-Path $rollback 'Scalability.ini.absent')
if ($savedScalabilityAbsent) {
    if (Test-Path -LiteralPath $liveScalability) { $same = $false }
} elseif ((Get-HashOrMissing $liveScalability) -ne (Get-HashOrMissing $savedScalability)) {
    $same = $false
}

if ($same) {
    Write-Host 'No operation: the current E-Day config already matches the rollback/default config.' -ForegroundColor Green
    exit 0
}

function Wait-ForEdayExit {
    while (Get-Process -Name 'GoWEDay-Steam','GoWEDay','GoWEDay-WinGDK' -ErrorAction SilentlyContinue) {
        Write-Host 'E-Day is running. Close or force-quit it; waiting for the process to exit...' -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

Wait-ForEdayExit

Write-Host 'A different E-Day performance configuration is currently installed.' -ForegroundColor Yellow
Write-Host '1 - Roll back to the saved pre-install configuration'
Write-Host '2 - Do nothing and exit'
$choice = Read-Host 'Choose 1 or 2'
if ($choice -ne '1') {
    Write-Host 'No changes made.'
    exit 0
}

foreach ($name in @('Engine.ini','GameUserSettings.ini')) {
    $source = Join-Path $rollback $name
    if (-not (Test-Path -LiteralPath $source)) { throw "Rollback file missing: $source" }
    $target = Join-Path $game $name
    attrib -R $target 2>$null | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}
if ($savedScalabilityAbsent) {
    if (Test-Path -LiteralPath $liveScalability) { Remove-Item -LiteralPath $liveScalability -Force }
} else {
    attrib -R $liveScalability 2>$null | Out-Null
    Copy-Item -LiteralPath $savedScalability -Destination $liveScalability -Force
}
Write-Host 'Rollback complete.' -ForegroundColor Green
