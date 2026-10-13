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

$platforms = @(Find-PlatformConfigs)
if ($platforms.Count -eq 0) { throw 'E-Day settings were not found.' }
$platform = Select-Platform $platforms
if (-not $platform) {
    Write-Host 'No changes made.'
    exit 0
}
$game = $platform.Path
$rollback = Get-RollbackPath $platform.Key
if (-not (Test-Path -LiteralPath $rollback)) { throw "No rollback configuration exists yet for $($platform.Name). Run the installer first." }
Write-Host "Selected platform: $($platform.Name)" -ForegroundColor Cyan
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
