param(
    [ValidateSet('MAXIMUM','ENHANCED')]
    [string]$Profile = 'ENHANCED'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path

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
